import 'dart:async';

import 'package:flutter/widgets.dart';

/// Pull-on-foreground trigger: refreshes the config whenever the app
/// returns to the foreground.
///
/// This is the standard mobile propagation model: batched pulls on OS
/// lifecycle hooks instead of battery-hostile persistent connections.
/// Register with `WidgetsBinding.instance.addObserver`.
class ForegroundRefreshObserver with WidgetsBindingObserver {
  /// Creates the observer; [onForeground] is the controller's `refresh`.
  ForegroundRefreshObserver(this.onForeground);

  /// Invoked (fire-and-forget) each time the app is resumed.
  final Future<void> Function() onForeground;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(onForeground());
    }
  }
}
