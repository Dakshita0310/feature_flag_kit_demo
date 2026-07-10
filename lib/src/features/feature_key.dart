/// The registry of gated features.
///
/// Using an enum (rather than raw strings) makes flag checks typo-proof and
/// gives the compiler a complete list of live experiments. Adding a feature:
///
/// 1. Add a value here with its config key.
/// 2. Add its baked-in default in `default_config.dart` (a test enforces
///    this).
/// 3. Gate the UI with `ref.watch(featureFlagProvider(FeatureKey.yourKey))`.
///
/// Removing a concluded experiment is the reverse; the compiler surfaces
/// every usage that needs cleanup.
enum FeatureKey {
  /// The redesigned checkout flow (staged rollout experiment).
  newCheckout('new_checkout'),

  /// The seasonal promotional banner on the home screen.
  promoBanner('promo_banner');

  const FeatureKey(this.key);

  /// The key used in remote config payloads and bucketing.
  final String key;
}
