import 'package:feature_flag_kit_demo/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('app scaffold renders', (tester) async {
    // Placeholder smoke test so CI exercises the test runner from commit 1.
    // Replaced by real suites as features land.
    await tester.pumpWidget(const MainApp());
    expect(find.text('Hello World!'), findsOneWidget);
  });
}
