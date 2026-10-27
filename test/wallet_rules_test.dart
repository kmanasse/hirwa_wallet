import 'package:flutter_test/flutter_test.dart';
import 'package:hirwa_wallet/logic/wallet_rules.dart';
import 'package:hirwa_wallet/models/wallet_transaction.dart';

void main() {
  group('numbers and notes', () {
    test('formats thousands and keeps 100 plain', () {
      expect(formatNumber(10000), '10,000');
      expect(formatNumber(1000000), '1,000,000');
      expect(formatNumber(100), '100');
    });

    test(
      '23,700 RWF is 5,000 × 4 · 2,000 × 1 · 1,000 × 1 · 500 × 1 · 100 × 2',
      () {
        expect(
          notesSummary(notesFor(23700)),
          '5,000 × 4 · 2,000 × 1 · 1,000 × 1 · 500 × 1 · 100 × 2',
        );
      },
    );

    test('100 RWF is a single 100 note', () {
      final notes = notesFor(100);
      expect(notes, hasLength(1));
      expect(notes.single.value, 100);
      expect(notes.single.count, 1);
    });
  });

  group('send', () {
    test('0721234567 is refused because it does not start with 078 or 079', () {
      expect(
        sendProblem(phone: '0721234567', amountText: '500', balance: 10000),
        'Phone number must start with 078 or 079.',
      );
    });

    test('50 RWF to 0788123456 is below the 100 RWF minimum', () {
      expect(
        sendProblem(phone: '0788123456', amountText: '50', balance: 10000),
        'Amount must be at least 100 RWF.',
      );
    });

    test('5k, 0 and -200 are refused before any money moves', () {
      expect(
        sendProblem(phone: '0788123456', amountText: '5k', balance: 10000),
        'Enter a whole number. 5k is not allowed.',
      );
      expect(
        sendProblem(phone: '0788123456', amountText: '0', balance: 10000),
        'Amount must be a whole number above 0.',
      );
      expect(
        sendProblem(phone: '0788123456', amountText: '-200', balance: 10000),
        'Amount must be a whole number above 0.',
      );
    });

    test('1,000,000 RWF is refused for insufficient balance', () {
      expect(
        sendProblem(phone: '0791234567', amountText: '1000000', balance: 10000),
        contains('Insufficient balance'),
      );
    });

    test('a send that cannot also pay the 100 RWF fee is refused', () {
      expect(
        sendProblem(phone: '0788123456', amountText: '10000', balance: 10000),
        contains('Insufficient balance'),
      );
      expect(
        sendProblem(phone: '0788123456', amountText: '9900', balance: 10000),
        isNull,
      );
    });

    test('a successful send records the payment and its own fee', () {
      final transactions = <WalletTransaction>[];
      addSend(transactions, '0788123456', 1000);

      expect(transactions.first.description, 'Send fee');
      expect(transactions.first.amount, 100);
      expect(transactions[1].description, 'Sent to 0788123456');
      expect(transactions[1].amount, 1000);

      final stats = calculateStats(transactions);
      expect(stats.balance, 8900);
      expect(stats.totalOut, 1100);
      expect(stats.lowest, 8900);
    });
  });

  group('cash out', () {
    test('250 RWF is refused because it is not a multiple of 100', () {
      expect(cashOutAmountProblem('250'), 'Amount must be a multiple of 100.');
      expect(
        cashOutProblem(amountText: '250', balance: 100000),
        'Amount must be a multiple of 100.',
      );
    });

    test('5k, 0 and -200 are refused', () {
      expect(
        cashOutProblem(amountText: '5k', balance: 100000),
        'Enter a whole number. 5k is not allowed.',
      );
      expect(
        cashOutProblem(amountText: '0', balance: 100000),
        'Amount must be a whole number above 0.',
      );
      expect(
        cashOutProblem(amountText: '-200', balance: 100000),
        'Amount must be a whole number above 0.',
      );
    });

    test('23,700 can be broken into notes, then refused when the balance is too small', () {
      expect(cashOutAmountProblem('23700'), isNull);
      expect(
        cashOutProblem(amountText: '23700', balance: 10000),
        'Insufficient balance',
      );
    });

    test('an OUT of the exact balance is allowed and ends at 0', () {
      expect(cashOutProblem(amountText: '10000', balance: 10000), isNull);
      final transactions = <WalletTransaction>[];
      addCashOut(transactions, 10000);
      final stats = calculateStats(transactions);
      expect(stats.balance, 0);
      expect(stats.lowest, 0);
    });
  });

  group('receive', () {
    test('an empty description or a bad amount changes nothing', () {
      expect(
        receiveProblem(description: '   ', amountText: '500'),
        'Description cannot be empty.',
      );
      expect(
        receiveProblem(description: 'Gift', amountText: '5k'),
        'Enter a whole number. 5k is not allowed.',
      );
      expect(
        receiveProblem(description: 'Gift', amountText: '0'),
        'Amount must be a whole number above 0.',
      );
      expect(
        receiveProblem(description: 'Gift', amountText: '-200'),
        'Amount must be a whole number above 0.',
      );
    });

    test('a valid receive is an IN and raises the balance', () {
      final transactions = <WalletTransaction>[];
      addReceive(transactions, '  Gift  ', 50);
      expect(transactions.single.description, 'Gift');
      expect(transactions.single.isIncoming, isTrue);
      expect(calculateStats(transactions).balance, 10050);
    });
  });

  group('statistics and delete', () {
    test(
      'an empty wallet is still the opening 10,000, and the lowest is not 0',
      () {
        final stats = calculateStats(const []);
        expect(stats.balance, openingBalance);
        expect(stats.lowest, openingBalance);
        expect(stats.totalIn, 0);
        expect(stats.totalOut, 0);
      },
    );

    test('money that only comes in does not pull the lowest down to 0', () {
      final transactions = [
        const WalletTransaction(
          description: 'Gift',
          amount: 2000,
          direction: MoneyDirection.incoming,
        ),
      ];
      final stats = calculateStats(transactions);
      expect(stats.balance, 12000);
      expect(stats.lowest, 10000);
    });

    test('the sample day is back at 10,000, with 13,000 in, 13,000 out, lowest 5,000', () {
      final stats = calculateStats(sampleTransactions());
      expect(stats.balance, 10000);
      expect(stats.totalIn, 13000);
      expect(stats.totalOut, 13000);
      expect(stats.lowest, 5000);
    });

    test('deleting the allowance recalculates every figure', () {
      final transactions = sampleTransactions();
      final allowance = transactions.firstWhere(
        (transaction) => transaction.description == 'Allowance from home',
      );

      expect(deletionProblem(transactions, allowance), isNull);
      transactions.remove(allowance);

      final stats = calculateStats(transactions);
      expect(stats.balance, 5000);
      expect(stats.totalIn, 8000);
      expect(stats.totalOut, 13000);
      expect(stats.lowest, 5000);
    });

    test('deleting Payment from Keza would go below 0, so it is refused', () {
      final transactions = sampleTransactions();
      final payment = transactions.firstWhere(
        (transaction) => transaction.description == 'Payment from Keza',
      );

      expect(
        deletionProblem(transactions, payment),
        'Cannot delete this. The balance would go below 0.',
      );
      expect(transactions, hasLength(6));
      expect(calculateStats(transactions).balance, 10000);
    });
  });
}
