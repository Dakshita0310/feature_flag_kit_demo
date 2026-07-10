import 'package:feature_flag_kit/feature_flag_kit.dart';
import 'package:feature_flag_kit_demo/main.dart';
import 'package:feature_flag_kit_demo/src/data/mock_config_repository.dart';
import 'package:feature_flag_kit_demo/src/data/shared_prefs_config_store.dart';
import 'package:feature_flag_kit_demo/src/features/default_config.dart';
import 'package:feature_flag_kit_demo/src/features/demo_users.dart';
import 'package:feature_flag_kit_demo/src/providers/config_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<(ConfigSessionController, MockConfigRepository)> deps() async {
  SharedPreferences.setMockInitialValues({});
  final repo = MockConfigRepository(latency: Duration.zero);
  final controller = ConfigSessionController(
    defaults: defaultConfig,
    fetcher: repo,
    store: SharedPrefsConfigStore(await SharedPreferences.getInstance()),
    user: DemoUsers.userA,
  );
  await controller.initialize();
  return (controller, repo);
}

Future<void> openMenu(
  WidgetTester tester,
  ConfigSessionController controller,
  MockConfigRepository repo,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sessionControllerProvider.overrideWithValue(controller),
        mockRepositoryProvider.overrideWithValue(repo),
      ],
      child: const DemoApp(),
    ),
  );
  await tester.tap(find.byTooltip('Developer menu'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('lists every flag with its evaluation reason', (tester) async {
    final (controller, repo) = await deps();
    await openMenu(tester, controller, repo);

    expect(find.text('new_checkout'), findsOneWidget);
    expect(find.text('promo_banner'), findsOneWidget);
    // user_a is inside both rollouts on defaults.
    expect(find.widgetWithText(Chip, 'ON'), findsNWidgets(2));
    expect(find.textContaining('rolloutHit'), findsNWidgets(2));
  });

  testWidgets('shows the deterministic buckets for the current user', (
    tester,
  ) async {
    final (controller, repo) = await deps();
    await openMenu(tester, controller, repo);

    // Pinned engine buckets for user_a.
    expect(find.textContaining('new_checkout: bucket 10'), findsOneWidget);
    expect(find.textContaining('promo_banner: bucket 1'), findsOneWidget);
  });

  testWidgets(
    'switching to Config B and simulating a push kills the flag live',
    (tester) async {
      final (controller, repo) = await deps();
      await openMenu(tester, controller, repo);

      await tester.scrollUntilVisible(find.text('Config B (killed)'), 100);
      await tester.tap(find.text('Config B (killed)'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Simulate silent push'), 100);
      await tester.tap(find.text('Simulate silent push'));
      await tester.pumpAndSettle();

      expect(controller.activeKillSwitches, {'new_checkout'});
      await tester.scrollUntilVisible(find.textContaining('killSwitch'), -100);
      expect(find.textContaining('killSwitch'), findsOneWidget);
      expect(find.widgetWithText(Chip, 'OFF'), findsOneWidget);
    },
  );

  testWidgets('shows session vs latest-fetched versions (freeze visible)', (
    tester,
  ) async {
    final (controller, repo) = await deps();
    await openMenu(tester, controller, repo);

    await tester.scrollUntilVisible(find.text('none yet'), 100);
    expect(find.text('baked-in-defaults'), findsOneWidget);
    expect(find.text('none yet'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Refresh now (manual pull)'),
      100,
    );
    await tester.tap(find.text('Refresh now (manual pull)'));
    await tester.pumpAndSettle();

    // Session stays frozen on defaults; the fetched config waits for the
    // next launch.
    await tester.scrollUntilVisible(find.text('baked-in-defaults'), -100);
    expect(find.text('baked-in-defaults'), findsOneWidget);
    expect(find.text(MockConfigRepository.configAVersion), findsOneWidget);
  });
}
