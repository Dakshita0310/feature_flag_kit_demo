import 'package:feature_flag_kit/feature_flag_kit.dart';
import 'package:feature_flag_kit_demo/src/bootstrap.dart';
import 'package:feature_flag_kit_demo/src/data/mock_config_repository.dart';
import 'package:feature_flag_kit_demo/src/data/shared_prefs_config_store.dart';
import 'package:feature_flag_kit_demo/src/features/default_config.dart';
import 'package:feature_flag_kit_demo/src/lifecycle/foreground_refresh_observer.dart';
import 'package:feature_flag_kit_demo/src/lifecycle/silent_push_simulator.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<AppDependencies> boot() async {
    SharedPreferences.setMockInitialValues({});
    return bootstrap(
      repository: MockConfigRepository(latency: Duration.zero),
      store: SharedPrefsConfigStore(await SharedPreferences.getInstance()),
    );
  }

  group('bootstrap (cold-start trigger)', () {
    test(
      'boots on defaults and fires exactly one background refresh',
      () async {
        final deps = await boot();

        // Evaluation available immediately, against baked-in defaults.
        expect(deps.controller.sessionConfigVersion, 'baked-in-defaults');

        // The cold-start refresh was fired without being awaited.
        await pumpEventQueue();
        expect(deps.repository.fetchCount, 1);
        expect(
          deps.controller.latestFetchedVersion,
          MockConfigRepository.configAVersion,
        );
      },
    );

    test('second launch hydrates from the LKG saved by the first', () async {
      SharedPreferences.setMockInitialValues({});
      final store = SharedPrefsConfigStore(
        await SharedPreferences.getInstance(),
      );

      final first = await bootstrap(
        repository: MockConfigRepository(latency: Duration.zero),
        store: store,
      );
      await pumpEventQueue(); // let the cold-start refresh persist the LKG
      expect(
        first.controller.latestFetchedVersion,
        MockConfigRepository.configAVersion,
      );

      final second = await bootstrap(
        repository: MockConfigRepository(latency: Duration.zero),
        store: store,
      );
      expect(
        second.controller.sessionConfigVersion,
        MockConfigRepository.configAVersion,
      );
    });
  });

  group('ForegroundRefreshObserver', () {
    test('refreshes on resume, ignores other lifecycle states', () {
      var refreshes = 0;
      final observer = ForegroundRefreshObserver(() async => refreshes++);

      observer.didChangeAppLifecycleState(AppLifecycleState.paused);
      observer.didChangeAppLifecycleState(AppLifecycleState.inactive);
      expect(refreshes, 0);

      observer.didChangeAppLifecycleState(AppLifecycleState.resumed);
      expect(refreshes, 1);
    });

    test('receives lifecycle events through the WidgetsBinding', () async {
      var refreshes = 0;
      final observer = ForegroundRefreshObserver(() async => refreshes++);
      WidgetsBinding.instance.addObserver(observer);
      addTearDown(() => WidgetsBinding.instance.removeObserver(observer));

      WidgetsBinding.instance.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      );
      await pumpEventQueue();

      expect(refreshes, 1);
    });
  });

  group('SilentPushSimulator', () {
    test('a push executes one pull through the shared refresh path', () async {
      SharedPreferences.setMockInitialValues({});
      final repo = MockConfigRepository(latency: Duration.zero);
      final controller = ConfigSessionController(
        defaults: defaultConfig,
        fetcher: repo,
        store: SharedPrefsConfigStore(await SharedPreferences.getInstance()),
        user: UserContext(userId: 'user_a'),
      );
      await controller.initialize();

      await SilentPushSimulator(controller).simulatePush();

      expect(repo.fetchCount, 1);
      expect(
        controller.latestFetchedVersion,
        MockConfigRepository.configAVersion,
      );
    });
  });
}
