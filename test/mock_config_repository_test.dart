import 'package:feature_flag_kit_demo/src/data/mock_config_repository.dart';
import 'package:feature_flag_kit_demo/src/features/feature_key.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MockConfigRepository', () {
    test('serves Config A by default: 50% rollout, kill-switch off', () async {
      final repo = MockConfigRepository(latency: Duration.zero);
      final config = await repo.fetch();

      expect(config.version, MockConfigRepository.configAVersion);
      final checkout = config.features[FeatureKey.newCheckout.key]!;
      expect(checkout.isKillSwitchActive, isFalse);
      expect(checkout.rolloutPercentage, 50);
    });

    test('serves Config B after switching: kill-switch on', () async {
      final repo = MockConfigRepository(latency: Duration.zero)
        ..environment = MockEnvironment.configB;
      final config = await repo.fetch();

      expect(config.version, MockConfigRepository.configBVersion);
      final checkout = config.features[FeatureKey.newCheckout.key]!;
      expect(checkout.isKillSwitchActive, isTrue);
    });

    test('every registered FeatureKey exists in both configs', () async {
      final repo = MockConfigRepository(latency: Duration.zero);
      for (final env in MockEnvironment.values) {
        repo.environment = env;
        final config = await repo.fetch();
        for (final key in FeatureKey.values) {
          expect(
            config.features.containsKey(key.key),
            isTrue,
            reason: '${key.name} missing from $env',
          );
        }
      }
    });

    test('simulates network latency', () async {
      final repo = MockConfigRepository(
        latency: const Duration(milliseconds: 50),
      );
      final stopwatch = Stopwatch()..start();
      await repo.fetch();
      stopwatch.stop();
      expect(stopwatch.elapsedMilliseconds, greaterThanOrEqualTo(45));
    });

    test(
      'payloads pass the engine strict validation (parsed, not built)',
      () async {
        // fetch() round-trips through RemoteConfig.fromJson, so a malformed
        // mock payload would throw ConfigValidationException here.
        final repo = MockConfigRepository(latency: Duration.zero);
        for (final env in MockEnvironment.values) {
          repo.environment = env;
          await expectLater(repo.fetch(), completes);
        }
      },
    );
  });
}
