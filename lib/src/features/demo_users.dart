import 'package:feature_flag_kit/feature_flag_kit.dart';

/// The two simulated user profiles for the demo.
///
/// Their userIds are chosen deliberately: the engine's pinned buckets put
/// `user_a` in bucket 10 and `user_b` in bucket 82 for `new_checkout`, so a
/// 50% rollout splits them - User A sees the new checkout, User B does not.
abstract final class DemoUsers {
  /// User A: bucket 10 for new_checkout (inside a 50% rollout).
  static final userA = UserContext(
    userId: 'user_a',
    country: 'US',
    appVersion: '2.1.0',
  );

  /// User B: bucket 82 for new_checkout (outside a 50% rollout).
  static final userB = UserContext(
    userId: 'user_b',
    country: 'IN',
    appVersion: '2.0.0',
  );

  /// Both profiles, for the profile switcher UI.
  static final all = [userA, userB];
}
