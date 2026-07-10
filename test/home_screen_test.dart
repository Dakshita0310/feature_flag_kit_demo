import 'package:feature_flag_kit/feature_flag_kit.dart';
import 'package:feature_flag_kit_demo/main.dart';
import 'package:feature_flag_kit_demo/src/data/mock_config_repository.dart';
import 'package:feature_flag_kit_demo/src/data/shared_prefs_config_store.dart';
import 'package:feature_flag_kit_demo/src/features/default_config.dart';
import 'package:feature_flag_kit_demo/src/features/demo_users.dart';
import 'package:feature_flag_kit_demo/src/providers/config_providers.dart';
import 'package:feature_flag_kit_demo/src/ui/checkout_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<(ConfigSessionController, MockConfigRepository)> deps() async {
  SharedPreferences.setMockInitialValues({});
  final repo = MockConfigRepository(latency: Duration.zero);
  final controller = ConfigSessionController(
    defaults: defaultConfig,
    fetcher: repo,
    store: SharedPrefsConfigStore(await SharedPreferences.getInstance()),
    user: DemoUsers.userA,
  );
  await controller.initialize();
  return (controller, repo);
}

Widget app(ConfigSessionController controller, MockConfigRepository repo) =>
    ProviderScope(
      overrides: [
        sessionControllerProvider.overrideWithValue(controller),
        mockRepositoryProvider.overrideWithValue(repo),
      ],
      child: const DemoApp(),
    );

void main() {
  testWidgets('User A sees the new checkout (bucket 10, inside 50%)', (
    tester,
  ) async {
    final (controller, repo) = await deps();
    await tester.pumpWidget(app(controller, repo));

    expect(find.byType(NewCheckoutWidget), findsOneWidget);
    expect(find.byType(LegacyCheckoutWidget), findsNothing);
  });

  testWidgets('switching to User B swaps in the legacy checkout', (
    tester,
  ) async {
    final (controller, repo) = await deps();
    await tester.pumpWidget(app(controller, repo));

    await tester.tap(find.text('User B'));
    await tester.pumpAndSettle();

    expect(find.byType(LegacyCheckoutWidget), findsOneWidget);
    expect(find.byType(NewCheckoutWidget), findsNothing);
  });

  testWidgets('switching back to User A restores the new checkout', (
    tester,
  ) async {
    final (controller, repo) = await deps();
    await tester.pumpWidget(app(controller, repo));

    await tester.tap(find.text('User B'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('User A'));
    await tester.pumpAndSettle();

    expect(find.byType(NewCheckoutWidget), findsOneWidget);
  });

  testWidgets('promo banner shows for everyone (100% rollout)', (tester) async {
    final (controller, repo) = await deps();
    await tester.pumpWidget(app(controller, repo));

    expect(find.text('Summer sale: 20% off everything!'), findsOneWidget);

    await tester.tap(find.text('User B'));
    await tester.pumpAndSettle();
    expect(find.text('Summer sale: 20% off everything!'), findsOneWidget);
  });
}
