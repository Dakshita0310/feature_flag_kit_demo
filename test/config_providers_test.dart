import 'package:feature_flag_kit/feature_flag_kit.dart';
import 'package:feature_flag_kit_demo/src/data/mock_config_repository.dart';
import 'package:feature_flag_kit_demo/src/data/shared_prefs_config_store.dart';
import 'package:feature_flag_kit_demo/src/features/default_config.dart';
import 'package:feature_flag_kit_demo/src/features/feature_key.dart';
import 'package:feature_flag_kit_demo/src/providers/config_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Fetcher returning a fixed config, for freeze-behavior tests.
class FixedFetcher implements ConfigFetcher {
  FixedFetcher(this.config);
  final RemoteConfig config;

  @override
  Future<RemoteConfig> fetch() async => config;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockConfigRepository repo;
  late ConfigSessionController controller;
  late ProviderContainer container;

  Future<void> setUpWith({
    ConfigFetcher? fetcher,
    String userId = 'user_a',
  }) async {
    SharedPreferences.setMockInitialValues({});
    repo = MockConfigRepository(latency: Duration.zero);
    controller = ConfigSessionController(
      defaults: defaultConfig,
      fetcher: fetcher ?? repo,
      store: SharedPrefsConfigStore(await SharedPreferences.getInstance()),
      user: UserContext(userId: userId),
    );
    await controller.initialize();
    container = ProviderContainer(
      overrides: [sessionControllerProvider.overrideWithValue(controller)],
    );
    addTearDown(container.dispose);
    addTearDown(controller.dispose);
  }

  group('featureFlagProvider', () {
    test('reflects the session evaluation (user_a inside 50%)', () async {
      await setUpWith();
      expect(
        container.read(featureFlagProvider(FeatureKey.newCheckout)),
        isTrue,
      );
      expect(
        container.read(featureFlagProvider(FeatureKey.promoBanner)),
        isTrue,
      );
    });

    test('rebuilds when a live kill-switch arrives', () async {
      await setUpWith();
      final observed = <bool>[];
      container.listen(
        featureFlagProvider(FeatureKey.newCheckout),
        (_, next) => observed.add(next),
        fireImmediately: true,
      );
      expect(observed, [true]);

      repo.environment = MockEnvironment.configB;
      await controller.refresh();
      await pumpEventQueue();

      expect(observed, [true, false]);
    });

    test('does not rebuild for frozen (non-emergency) changes', () async {
      // Fresh config raises the rollout to 100%: persisted, but frozen.
      await setUpWith(
        fetcher: FixedFetcher(
          RemoteConfig(
            version: 'v-frozen',
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
          ),
        ),
        userId: 'user_b', // outside 50%, would be inside 100%
      );

      final observed = <bool>[];
      container.listen(
        featureFlagProvider(FeatureKey.newCheckout),
        (_, next) => observed.add(next),
        fireImmediately: true,
      );

      await controller.refresh();
      await pumpEventQueue();

      // Still evaluating against the frozen session config: no rebuild,
      // no mid-session flip.
      expect(observed, [false]);
      expect(controller.latestFetchedVersion, 'v-frozen');
    });

    test('rebuilds when the user context switches', () async {
      await setUpWith();
      final observed = <bool>[];
      container.listen(
        featureFlagProvider(FeatureKey.newCheckout),
        (_, next) => observed.add(next),
        fireImmediately: true,
      );

      controller.updateUserContext(UserContext(userId: 'user_b'));
      await pumpEventQueue();

      expect(observed, [true, false]);
    });
  });

  group('evaluationResultProvider', () {
    test('exposes the reason for the developer menu', () async {
      await setUpWith();
      repo.environment = MockEnvironment.configB;
      await controller.refresh();
      await pumpEventQueue();

      final result = container.read(
        evaluationResultProvider(FeatureKey.newCheckout),
      );
      expect(result.isEnabled, isFalse);
      expect(result.reason, EvaluationReason.killSwitch);
    });
  });

  group('currentUserProvider', () {
    test('tracks user switches', () async {
      await setUpWith();
      expect(container.read(currentUserProvider).userId, 'user_a');

      controller.updateUserContext(UserContext(userId: 'user_b'));
      await pumpEventQueue();

      expect(container.read(currentUserProvider).userId, 'user_b');
    });
  });
}
