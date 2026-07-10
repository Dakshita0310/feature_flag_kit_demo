import 'package:feature_flag_kit/feature_flag_kit.dart';

import 'feature_key.dart';

/// Baked-in defaults: the config the app boots on when no Last-Known-Good
/// cache exists (first launch, cleared storage, corrupted cache).
///
/// Defined in code rather than as a JSON asset so it is available
/// synchronously at frame 0; loading an asset would be an async I/O
/// operation and force a splash screen.
final RemoteConfig defaultConfig = RemoteConfig(
  version: 'baked-in-defaults',
  features: {
    FeatureKey.newCheckout.key: const FeatureConfig(
      isKillSwitchActive: false,
      rolloutPercentage: 50,
    ),
    FeatureKey.promoBanner.key: const FeatureConfig(
      isKillSwitchActive: false,
      rolloutPercentage: 100,
    ),
  },
);
