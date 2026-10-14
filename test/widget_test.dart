import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momo_wallet/main.dart';
import 'package:momo_wallet/wallet.dart';

void main() {
  Future<Wallet> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    final wallet = Wallet.sample();
    await tester.pumpWidget(MomoApp(wallet: wallet));
    return wallet;
  }

  testWidgets('wallet shows balance and statistics', (tester) async {
    await pumpApp(tester);
    expect(find.text('10,000  RWF', findRichText: true), findsOneWidget);
    expect(find.text('Total IN'), findsOneWidget);
    expect(find.text('8,000'), findsOneWidget); // lowest balance
  });

  testWidgets('send to 0721234567 shows which rule failed', (tester) async {
    final wallet = await pumpApp(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Send'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('send-phone')), '0721234567');
    await tester.enterText(find.byKey(const Key('send-amount')), '1000');
    await tester.tap(find.byKey(const Key('send-button')));
    await tester.pump();
    expect(find.text('Phone number must start with 078 or 079'), findsOneWidget);
    expect(wallet.balance, 10000);
  });

  testWidgets('cash out 23,700 shows notes then confirms', (tester) async {
    final wallet = await pumpApp(tester);
    wallet.receive('20000', 'Top up');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Cash out'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('cashout-amount')), '23700');
    await tester.tap(find.byKey(const Key('cashout-notes')));
    await tester.pump();
    for (final note in ['5,000 × 4', '2,000 × 1', '1,000 × 1', '500 × 1', '100 × 2']) {
      expect(find.text(note), findsOneWidget);
    }
    expect(wallet.balance, 30000);
    await tester.tap(find.byKey(const Key('cashout-confirm')));
    await tester.pumpAndSettle();
    expect(wallet.balance, 6300);
    expect(find.text('6,300  RWF', findRichText: true), findsOneWidget);
  });

  testWidgets('delete from details, then undo', (tester) async {
    final wallet = await pumpApp(tester);
    await tester.tap(find.text('Received from Aline'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('details-delete')));
    await tester.pumpAndSettle();
    expect(wallet.balance, 8500);
    expect(find.text('Received from Aline'), findsNothing);
    await tester.tap(find.text('UNDO'));
    await tester.pumpAndSettle();
    expect(wallet.balance, 10000);
    expect(find.text('Received from Aline'), findsOneWidget);
  });
}
