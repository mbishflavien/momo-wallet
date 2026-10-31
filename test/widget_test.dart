import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momo_wallet/login_screen.dart';

void main() {
  testWidgets('login validates before calling Firebase', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

    await tester.tap(find.widgetWithText(FilledButton, 'Log in'));
    await tester.pump();
    expect(find.text('Enter your email'), findsOneWidget);
    expect(find.text('At least 6 characters'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).first, 'not-an-email');
    await tester.enterText(find.byType(TextFormField).last, '123');
    await tester.tap(find.widgetWithText(FilledButton, 'Log in'));
    await tester.pump();
    expect(find.text('Enter a valid email, like aline@gmail.com'), findsOneWidget);
    expect(find.text('At least 6 characters'), findsOneWidget);
  });
}
