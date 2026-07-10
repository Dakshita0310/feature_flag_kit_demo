import 'package:feature_flag_kit/feature_flag_kit.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/feature_key.dart';

/// The app-wide [ConfigSessionController].
///
/// Constructed during bootstrap (SharedPreferences + hydration are async)
/// and injected with `overrideWithValue` on the root `ProviderScope`.
final sessionControllerProvider = Provider<ConfigSessionController>((ref) {
  throw UnimplementedError(
    'sessionControllerProvider must be overridden in bootstrap()',
  );
});

/// Monotonic counter bumped on every live config change (kill-switch
/// teardown or user-context switch).
///
/// Flag providers watch this, so they re-evaluate exactly when the engine
/// says an outcome may have changed - and never for frozen changes, which
/// by design only apply on the next launch.
class ConfigRevision extends Notifier<int> {
  @override
  int build() {
    final controller = ref.watch(sessionControllerProvider);
    final subscription = controller.changes.listen((_) => state++);
    ref.onDispose(subscription.cancel);
    return 0;
  }
}

/// See [ConfigRevision].
final configRevisionProvider = NotifierProvider<ConfigRevision, int>(
  ConfigRevision.new,
);

/// One-line reactive UI gating:
///
/// ```dart
/// final enabled = ref.watch(featureFlagProvider(FeatureKey.newCheckout));
/// ```
final featureFlagProvider = Provider.family<bool, FeatureKey>((ref, key) {
  ref.watch(configRevisionProvider);
  return ref.watch(sessionControllerProvider).isEnabled(key.key);
});

/// The rich evaluation for the developer menu and exposure logging.
final evaluationResultProvider = Provider.family<EvaluationResult, FeatureKey>((
  ref,
  key,
) {
  ref.watch(configRevisionProvider);
  return ref.watch(sessionControllerProvider).evaluate(key.key);
});

/// The user the session currently evaluates for.
final currentUserProvider = Provider<UserContext>((ref) {
  ref.watch(configRevisionProvider);
  return ref.watch(sessionControllerProvider).currentUser;
});
