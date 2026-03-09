import 'package:flutter_test/flutter_test.dart';
import 'package:voidmail/main.dart';

void main() {
  testWidgets('VoidMail app starts', (WidgetTester tester) async {
    await tester.pumpWidget(const VoidMailApp());
    await tester.pump();
    // App should show onboarding since not signed in
    expect(find.text('VOID'), findsOneWidget);
  });
}
