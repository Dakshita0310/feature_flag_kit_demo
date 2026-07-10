import 'package:feature_flag_kit/feature_flag_kit.dart';

/// The two simulated backend environments.
enum MockEnvironment {
  /// Normal operations: `new_checkout` mid-rollout at 50%.
  configA,

  /// Emergency rollback: `new_checkout` kill-switch active.
  configB,
}

/// A [ConfigFetcher] simulating a remote config backend, so the demo runs
/// without real infrastructure.
///
/// The developer menu switches [environment] between Config A (50% rollout)
/// and Config B (kill-switch on) to demonstrate staged rollouts and the
/// mid-session emergency teardown. Payloads are stored as raw JSON and
/// round-tripped through [RemoteConfig.fromJson] on every fetch, exercising
/// the same strict validation path a real HTTP fetcher would.
class MockConfigRepository implements ConfigFetcher {
  /// Creates the repository; [latency] simulates network round-trip time.
  MockConfigRepository({this.latency = const Duration(milliseconds: 800)});

  /// Version marker served by Config A.
  static const configAVersion = 'config-a-v1';

  /// Version marker served by Config B.
  static const configBVersion = 'config-b-v2';

  /// Simulated network round-trip time.
  final Duration latency;

  /// Which simulated backend the next [fetch] hits.
  MockEnvironment environment = MockEnvironment.configA;

  /// Number of fetches served, displayed in the developer menu.
  int fetchCount = 0;

  static const Map<String, Object?> _configA = {
    'version': configAVersion,
    'features': {
      'new_checkout': {'isKillSwitchActive': false, 'rolloutPercentage': 50},
      'promo_banner': {'isKillSwitchActive': false, 'rolloutPercentage': 100},
    },
  };

  static const Map<String, Object?> _configB = {
    'version': configBVersion,
    'features': {
      'new_checkout': {'isKillSwitchActive': true, 'rolloutPercentage': 50},
      'promo_banner': {'isKillSwitchActive': false, 'rolloutPercentage': 100},
    },
  };

  @override
  Future<RemoteConfig> fetch() async {
    fetchCount++;
    await Future<void>.delayed(latency);
    final raw = switch (environment) {
      MockEnvironment.configA => _configA,
      MockEnvironment.configB => _configB,
    };
    return RemoteConfig.fromJson(raw);
  }
}
