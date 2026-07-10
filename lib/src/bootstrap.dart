import 'dart:async';

import 'package:feature_flag_kit/feature_flag_kit.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/mock_config_repository.dart';
import 'data/shared_prefs_config_store.dart';
import 'features/default_config.dart';
import 'features/demo_users.dart';
import 'lifecycle/foreground_refresh_observer.dart';

/// Everything the widget tree needs, produced by [bootstrap].
class AppDependencies {
  /// Bundles the session controller with the mock backend handle.
  AppDependencies({required this.controller, required this.repository});

  /// The engine session controller (evaluation, freeze, kill-switches).
  final ConfigSessionController controller;

  /// The mock backend; the developer menu switches its environment.
  final MockConfigRepository repository;
}

/// Boot sequence, mirroring the production pattern:
///
/// 1. Construct the controller on `const` baked-in defaults: evaluation is
///    available synchronously, no splash screen required.
/// 2. Hydrate from the SharedPreferences Last-Known-Good cache.
/// 3. Fire the cold-start refresh in the background (never awaited: the
///    first frame must not block on the network).
/// 4. Register the foregrounding trigger.
Future<AppDependencies> bootstrap({
  MockConfigRepository? repository,
  ConfigStore? store,
  UserContext? initialUser,
}) async {
  WidgetsFlutterBinding.ensureInitialized();

  final repo = repository ?? MockConfigRepository();
  final controller = ConfigSessionController(
    defaults: defaultConfig,
    fetcher: repo,
    store:
        store ?? SharedPrefsConfigStore(await SharedPreferences.getInstance()),
    user: initialUser ?? DemoUsers.userA,
  );

  await controller.initialize();
  unawaited(controller.refresh());

  WidgetsBinding.instance.addObserver(
    ForegroundRefreshObserver(controller.refresh),
  );

  return AppDependencies(controller: controller, repository: repo);
}
