import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hirwa_wallet/main.dart';
import 'package:hirwa_wallet/models/wallet_transaction.dart';
import 'package:hirwa_wallet/screens/wallet_screen.dart';

void main() {
  Future<void> pumpHirwa(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const HirwaApp());
  }

  Future<void> dismissSnackBar(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 4));
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('opens at 10,000 RWF with the sample transactions', (
    tester,
  ) async {
    await pumpHirwa(tester);

    expect(find.text('Hirwa'), findsOneWidget);
    expect(find.text('10,000'), findsOneWidget);
    expect(find.text('13,000'), findsNWidgets(2));
    expect(find.text('5,000'), findsOneWidget);
    expect(find.text('Allowance from home'), findsOneWidget);
    expect(find.text('Sent to 0788123456'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Payment from Keza'), 200);
    expect(find.text('Payment from Keza'), findsOneWidget);
  });

  testWidgets('the OUT filter hides incoming money and All brings it back', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: WalletScreen(
          initialTransactions: [
            WalletTransaction(
              description: 'Payment from Keza',
              amount: 8000,
              direction: MoneyDirection.incoming,
            ),
            WalletTransaction(
              description: 'Cash out',
              amount: 3000,
              direction: MoneyDirection.outgoing,
            ),
          ],
        ),
      ),
    );

    await tester.tap(find.widgetWithText(ChoiceChip, 'OUT'));
    await tester.pump();

    expect(find.text('Payment from Keza'), findsNothing);
    expect(find.text('Cash out'), findsNWidgets(2));

    await tester.tap(find.widgetWithText(ChoiceChip, 'All'));
    await tester.pump();

    expect(find.text('Payment from Keza'), findsOneWidget);
    expect(find.text('Cash out'), findsNWidgets(2));
  });

  testWidgets('a filter with nothing to show says so', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: WalletScreen(
          initialTransactions: [
            WalletTransaction(
              description: 'Cash out',
              amount: 100,
              direction: MoneyDirection.outgoing,
            ),
          ],
        ),
      ),
    );

    await tester.tap(find.widgetWithText(ChoiceChip, 'IN'));
    await tester.pump();
    expect(find.text('No money in yet'), findsOneWidget);
  });

  testWidgets('an empty wallet says there are no transactions', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: WalletScreen(initialTransactions: <WalletTransaction>[]),
      ),
    );
    expect(find.text('No transactions yet'), findsOneWidget);
    expect(find.text('10,000'), findsNWidgets(2));
  });

  testWidgets('sending to 072 is refused and the balance stays', (
    tester,
  ) async {
    await pumpHirwa(tester);

    await tester.tap(find.byKey(const Key('open-send')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('send-phone')), '0721234567');
    await tester.enterText(find.byKey(const Key('send-amount')), '500');
    await tester.pump();

    expect(
      find.text('Phone number must start with 078 or 079.'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('submit-send')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Send money'), findsOneWidget);
    expect(find.text('Phone number must start with 078 or 079.'), findsWidgets);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('balance')), findsOneWidget);
    expect(find.text('10,000'), findsOneWidget);
    await dismissSnackBar(tester);
  });

  testWidgets('a real send adds the payment and a 100 RWF fee', (tester) async {
    await pumpHirwa(tester);

    await tester.tap(find.byKey(const Key('open-send')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('send-phone')), '0791111111');
    await tester.enterText(find.byKey(const Key('send-amount')), '1000');
    await tester.tap(find.byKey(const Key('submit-send')));
    await tester.pumpAndSettle();

    expect(find.text('8,900'), findsOneWidget);
    expect(find.text('Sent to 0791111111'), findsOneWidget);
    expect(find.text('Send fee'), findsAtLeastNWidgets(1));
    await dismissSnackBar(tester);
  });

  testWidgets('cash out of 23,700 shows the notes, then refuses on confirm', (
    tester,
  ) async {
    await pumpHirwa(tester);

    await tester.tap(find.byKey(const Key('open-cash-out')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('cash-amount')), '23700');
    await tester.pump();

    expect(
      find.text('5,000 × 4 · 2,000 × 1 · 1,000 × 1 · 500 × 1 · 100 × 2'),
      findsOneWidget,
    );
    expect(find.text('Insufficient balance'), findsOneWidget);

    await tester.tap(find.byKey(const Key('confirm-cash-out')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Cash out'), findsWidgets);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('10,000'), findsOneWidget);
    await dismissSnackBar(tester);
  });

  testWidgets('cash out of 250 is refused and shows no notes', (tester) async {
    await pumpHirwa(tester);

    await tester.tap(find.byKey(const Key('open-cash-out')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('cash-amount')), '250');
    await tester.pump();

    expect(find.text('Amount must be a multiple of 100.'), findsOneWidget);
    expect(find.byKey(const Key('notes-summary')), findsNothing);

    await tester.enterText(find.byKey(const Key('cash-amount')), '5k');
    await tester.pump();
    expect(
      find.text('Enter a whole number. 5k is not allowed.'),
      findsOneWidget,
    );

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('10,000'), findsOneWidget);
  });

  testWidgets(
    'a confirmed cash out of 1,000 lowers the balance straight away',
    (tester) async {
      await pumpHirwa(tester);

      await tester.tap(find.byKey(const Key('open-cash-out')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('cash-amount')), '1000');
      await tester.pump();
      expect(find.text('1,000 × 1'), findsOneWidget);

      await tester.tap(find.byKey(const Key('confirm-cash-out')));
      await tester.pumpAndSettle();

      expect(find.text('9,000'), findsOneWidget);
      await dismissSnackBar(tester);
    },
  );

  testWidgets('holding Payment from Keza is refused', (tester) async {
    await pumpHirwa(tester);

    await tester.scrollUntilVisible(find.text('Payment from Keza'), 200);
    await tester.longPress(find.text('Payment from Keza'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Payment from Keza'), findsOneWidget);
    expect(find.textContaining('below 0'), findsOneWidget);
    expect(find.text('10,000'), findsOneWidget);
    await dismissSnackBar(tester);
  });

  testWidgets('holding the allowance deletes it, and Undo puts it back', (
    tester,
  ) async {
    await pumpHirwa(tester);

    await tester.longPress(find.text('Allowance from home'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Allowance from home'), findsNothing);
    expect(find.text('5,000'), findsWidgets);
    expect(find.text('Allowance from home deleted'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pump();

    expect(find.text('Allowance from home'), findsOneWidget);
    expect(find.text('10,000'), findsOneWidget);
    await dismissSnackBar(tester);
  });
}
