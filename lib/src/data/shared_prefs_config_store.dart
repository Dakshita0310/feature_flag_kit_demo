import 'dart:convert';

import 'package:feature_flag_kit/feature_flag_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A [ConfigStore] persisting the Last-Known-Good config to
/// SharedPreferences.
///
/// Payloads are serialized with the engine's round-trip `toJson` and parsed
/// back through [RemoteConfig.parse] on load, so a corrupted cache surfaces
/// as [ConfigValidationException] and the session controller falls back to
/// baked-in defaults instead of applying garbage.
class SharedPrefsConfigStore implements ConfigStore {
  /// Creates a store over an existing [SharedPreferences] instance.
  SharedPrefsConfigStore(this._prefs);

  /// Preference key under which the LKG payload is stored.
  static const cacheKey = 'feature_flag_kit.lkg_config';

  final SharedPreferences _prefs;

  @override
  Future<RemoteConfig?> load() async {
    final raw = _prefs.getString(cacheKey);
    if (raw == null) return null;
    return RemoteConfig.parse(raw);
  }

  @override
  Future<void> save(RemoteConfig config) async {
    await _prefs.setString(cacheKey, jsonEncode(config.toJson()));
  }
}
