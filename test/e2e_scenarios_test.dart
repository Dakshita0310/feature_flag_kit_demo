import 'package:feature_flag_kit/feature_flag_kit.dart';
import 'package:feature_flag_kit_demo/main.dart';
import 'package:feature_flag_kit_demo/src/data/mock_config_repository.dart';
import 'package:feature_flag_kit_demo/src/data/shared_prefs_config_store.dart';
import 'package:feature_flag_kit_demo/src/features/default_config.dart';
import 'package:feature_flag_kit_demo/src/features/demo_users.dart';
import 'package:feature_flag_kit_demo/src/features/feature_key.dart';
import 'package:feature_flag_kit_demo/src/providers/config_providers.dart';
import 'package:feature_flag_kit_demo/src/ui/checkout_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget app(ConfigSessionController controller, MockConfigRepository repo) =>
    ProviderScope(
      overrides: [
        sessionControllerProvider.overrideWithValue(controller),
        mockRepositoryProvider.overrideWithValue(repo),
      ],
      child: const DemoApp(),
    );

Future<ConfigSessionController> makeController(
  ConfigFetcher fetcher,
  SharedPrefsConfigStore store, {
  UserContext? user,
}) async {
  final controller = ConfigSessionController(
    defaults: defaultConfig,
    fetcher: fetcher,
    store: store,
    user: user ?? DemoUsers.userA,
  );
  await controller.initialize();
  return controller;
}

void main() {
  group('scenario: instant boot with background fetch', () {
    testWidgets(
      'first frame renders from defaults while the fetch is in flight',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final repo = MockConfigRepository(
          latency: const Duration(milliseconds: 800),
        );
        final store = SharedPrefsConfigStore(
          await SharedPreferences.getInstance(),
        );
        final controller = await makeController(repo, store);

        // Fire the cold-start refresh; do NOT await it (production behavior).
        final refresh = controller.refresh();
        await tester.pumpWidget(app(controller, repo));

        // Frame 1: gated UI already correct, fetch still in flight.
        expect(find.byType(NewCheckoutWidget), findsOneWidget);
        expect(controller.latestFetchedVersion, isNull);

        // Let the simulated network round-trip complete.
        await tester.pump(const Duration(seconds: 1));
        await refresh;
        expect(
          controller.latestFetchedVersion,
          MockConfigRepository.configAVersion,
        );
      },
    );
  });

  group('scenario: emergency kill-switch', () {
    testWidgets('tears down the running feature with zero user interaction', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final repo = MockConfigRepository(latency: Duration.zero);
      final store = SharedPrefsConfigStore(
        await SharedPreferences.getInstance(),
      );
      final controller = await makeController(repo, store);

      await tester.pumpWidget(app(controller, repo));
      expect(find.byType(NewCheckoutWidget), findsOneWidget);

      // The PM flips the switch on the backend...
      repo.environment = MockEnvironment.configB;
      // ...a silent push wakes the app, which pulls. Start the pull, then
      // pump so the fake-async clock can run the simulated network timer.
      final refresh = controller.refresh();
      await tester.pumpAndSettle();
      await refresh;
      await tester.pumpAndSettle();

      // The feature is gone mid-session, replaced by the stable fallback.
      expect(find.byType(NewCheckoutWidget), findsNothing);
      expect(find.byType(LegacyCheckoutWidget), findsOneWidget);
      expect(
        controller.evaluate(FeatureKey.newCheckout.key).reason,
        EvaluationReason.killSwitch,
      );
    });
  });

  group('scenario: selective freeze across a restart', () {
    testWidgets(
      'a rollout change never flips the live UI, then applies on relaunch',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final store = SharedPrefsConfigStore(
          await SharedPreferences.getInstance(),
        );
        final fullRollout = RemoteConfig(
          version: 'v-100pct',
          features: {
            FeatureKey.newCheckout.key: const FeatureConfig(
              isKillSwitchActive: false,
              rolloutPercentage: 100,
            ),
            FeatureKey.promoBanner.key: const FeatureConfig(
              isKillSwitchActive: false,
              rolloutPercentage: 100,
            ),
          },
        );
        final repo = MockConfigRepository(latency: Duration.zero);

        // Session 1: user_b (bucket 82) is outside the default 50%.
        final session1 = await makeController(
          _FixedFetcherRepo(fullRollout),
          store,
          user: DemoUsers.userB,
        );
        await tester.pumpWidget(app(session1, repo));
        expect(find.byType(LegacyCheckoutWidget), findsOneWidget);

        // The backend raises the rollout to 100% mid-session.
        await session1.refresh();
        await tester.pumpAndSettle();

        // Frozen: the UI must NOT flip under the user's feet.
        expect(find.byType(LegacyCheckoutWidget), findsOneWidget);
        expect(session1.latestFetchedVersion, 'v-100pct');

        // Session 2 (relaunch): hydrates the LKG, the change now applies.
        final session2 = await makeController(
          _FixedFetcherRepo(fullRollout),
          store,
          user: DemoUsers.userB,
        );
        await tester.pumpWidget(app(session2, repo));
        expect(session2.sessionConfigVersion, 'v-100pct');
        expect(find.byType(NewCheckoutWidget), findsOneWidget);
      },
    );
  });

  group('scenario: determinism across restarts', () {
    testWidgets('the same user sees the same features on every launch', (
      tester,
    ) async {
      for (var launch = 0; launch < 3; launch++) {
        SharedPreferences.setMockInitialValues({});
        final repo = MockConfigRepository(latency: Duration.zero);
        final store = SharedPrefsConfigStore(
          await SharedPreferences.getInstance(),
        );
        final controller = await makeController(repo, store);

        await tester.pumpWidget(app(controller, repo));
        expect(
          find.byType(NewCheckoutWidget),
          findsOneWidget,
          reason: 'user_a must be in the rollout on launch $launch',
        );
        await tester.pumpWidget(Container()); // tear down between launches
      }
    });
  });

  group('scenario: corrupted cache', () {
    testWidgets('boots on defaults when the LKG cache is garbage', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        SharedPrefsConfigStore.cacheKey: '{"version": "v1", "featur',
      });
      final repo = MockConfigRepository(latency: Duration.zero);
      final store = SharedPrefsConfigStore(
        await SharedPreferences.getInstance(),
      );
      final controller = await makeController(repo, store);

      await tester.pumpWidget(app(controller, repo));

      expect(controller.sessionConfigVersion, 'baked-in-defaults');
      expect(find.byType(NewCheckoutWidget), findsOneWidget);
    });
  });
}

/// Adapter: a MockConfigRepository-shaped fetcher serving a fixed config,
/// for the freeze scenario.
class _FixedFetcherRepo implements ConfigFetcher {
  _FixedFetcherRepo(this.config);
  final RemoteConfig config;

  @override
  Future<RemoteConfig> fetch() async => config;
}
