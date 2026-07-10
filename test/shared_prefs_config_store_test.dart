import 'package:feature_flag_kit/feature_flag_kit.dart';
import 'package:feature_flag_kit_demo/src/data/shared_prefs_config_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  RemoteConfig sample() => RemoteConfig(
    version: 'v42',
    features: {
      'new_checkout': const FeatureConfig(
        isKillSwitchActive: false,
        rolloutPercentage: 25,
        targeting: TargetingRules(allowedCountries: ['US']),
      ),
    },
  );

  group('SharedPrefsConfigStore', () {
    test('load returns null when no cache exists', () async {
      SharedPreferences.setMockInitialValues({});
      final store = SharedPrefsConfigStore(
        await SharedPreferences.getInstance(),
      );
      expect(await store.load(), isNull);
    });

    test('save then load round-trips the config', () async {
      SharedPreferences.setMockInitialValues({});
      final store = SharedPrefsConfigStore(
        await SharedPreferences.getInstance(),
      );

      await store.save(sample());
      final loaded = await store.load();

      expect(loaded, sample());
      expect(loaded!.features['new_checkout']!.targeting!.allowedCountries, [
        'US',
      ]);
    });

    test(
      'a corrupted cache throws ConfigValidationException on load',
      () async {
        SharedPreferences.setMockInitialValues({
          SharedPrefsConfigStore.cacheKey: '{"version":"v1","features":{"trunc',
        });
        final store = SharedPrefsConfigStore(
          await SharedPreferences.getInstance(),
        );

        expect(store.load, throwsA(isA<ConfigValidationException>()));
      },
    );

    test(
      'a schema-invalid cache throws ConfigValidationException on load',
      () async {
        SharedPreferences.setMockInitialValues({
          SharedPrefsConfigStore.cacheKey:
              '{"version":"v1","features":{"f":{"isKillSwitchActive":"nope",'
              '"rolloutPercentage":50}}}',
        });
        final store = SharedPrefsConfigStore(
          await SharedPreferences.getInstance(),
        );

        expect(store.load, throwsA(isA<ConfigValidationException>()));
      },
    );

    test('save overwrites the previous LKG', () async {
      SharedPreferences.setMockInitialValues({});
      final store = SharedPrefsConfigStore(
        await SharedPreferences.getInstance(),
      );

      await store.save(sample());
      await store.save(RemoteConfig(version: 'v43', features: const {}));

      expect((await store.load())!.version, 'v43');
    });
  });
}
