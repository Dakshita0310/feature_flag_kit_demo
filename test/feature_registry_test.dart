import 'package:feature_flag_kit/feature_flag_kit.dart';
import 'package:feature_flag_kit_demo/src/features/default_config.dart';
import 'package:feature_flag_kit_demo/src/features/feature_key.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FeatureKey registry', () {
    test('every FeatureKey has a baked-in default entry', () {
      // The frictionless-feature-addition guard: adding an enum value
      // without a default breaks this test, not production behavior.
      for (final key in FeatureKey.values) {
        expect(
          defaultConfig.features.containsKey(key.key),
          isTrue,
          reason: 'FeatureKey.${key.name} is missing from defaultConfig',
        );
      }
    });

    test('config keys are unique', () {
      final keys = FeatureKey.values.map((k) => k.key).toSet();
      expect(keys, hasLength(FeatureKey.values.length));
    });
  });

  group('baked-in defaults', () {
    test('are available synchronously (no I/O, no async)', () {
      // Constructing and evaluating must work without any await:
      // this is what guarantees frame-0 availability.
      final result = evaluateFlag(
        featureKey: FeatureKey.newCheckout.key,
        user: UserContext(userId: 'user_a'),
        config: defaultConfig,
      );
      expect(result, isA<EvaluationResult>());
    });

    test('new_checkout defaults to a 50% rollout, kill-switch off', () {
      final feature = defaultConfig.features[FeatureKey.newCheckout.key]!;
      expect(feature.isKillSwitchActive, isFalse);
      expect(feature.rolloutPercentage, 50);
    });

    test(
      'user_a (bucket 10) gets new_checkout by default; user_b does not',
      () {
        // Pinned engine buckets: user_a=10, user_b=82 for new_checkout.
        bool enabledFor(String userId) => evaluateFlag(
          featureKey: FeatureKey.newCheckout.key,
          user: UserContext(userId: userId),
          config: defaultConfig,
        ).isEnabled;

        expect(enabledFor('user_a'), isTrue);
        expect(enabledFor('user_b'), isFalse);
      },
    );

    test('promo_banner defaults to fully rolled out', () {
      final result = evaluateFlag(
        featureKey: FeatureKey.promoBanner.key,
        user: UserContext(userId: 'user_b'),
        config: defaultConfig,
      );
      expect(result.isEnabled, isTrue);
      expect(result.reason, EvaluationReason.rolloutHit);
    });
  });
}
