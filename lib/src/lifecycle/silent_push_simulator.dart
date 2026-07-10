import 'package:feature_flag_kit/feature_flag_kit.dart';

/// Stand-in for the OS silent-push pipeline (APNs/FCM).
///
/// In production, flipping a critical kill-switch sends a silent push; the
/// OS wakes the app in the background, which executes a normal config pull.
/// The engine is transport-agnostic, so this simulator does exactly what a
/// real `firebase_messaging` background handler would: invoke the one
/// shared `refresh()` path. A real integration replaces this class and
/// nothing else.
class SilentPushSimulator {
  /// Creates the simulator over the app's session controller.
  SilentPushSimulator(this._controller);

  final ConfigSessionController _controller;

  /// Simulates receiving a critical-config silent push.
  Future<void> simulatePush() => _controller.refresh();
}
