import 'package:flutter_test/flutter_test.dart';
import 'package:momo_wallet/wallet.dart';

void main() {
  late Wallet w;
  setUp(() => w = Wallet.sample(clock: () => DateTime(2026, 10, 14, 12)));

  group('starting state', () {
    test('starts at 10,000 with sample transactions, newest first', () {
      expect(w.balance, 10000);
      expect(w.transactions, isNotEmpty);
      final ids = w.newestFirst().map((t) => t.id).toList();
      expect(ids, [5, 4, 3, 2, 1]);
    });

    test('filter shows All, IN or OUT', () {
      expect(w.newestFirst().length, 5);
      expect(w.newestFirst(filter: TxType.incoming).every((t) => t.isIn), isTrue);
      expect(w.newestFirst(filter: TxType.incoming).length, 2);
      expect(w.newestFirst(filter: TxType.outgoing).every((t) => !t.isIn), isTrue);
      expect(w.newestFirst(filter: TxType.outgoing).length, 3);
    });
  });

  group('receive', () {
    test('adds an IN with its description', () {
      final r = w.receive('2500', '  Received from Eric ');
      expect(r.ok, isTrue);
      expect(w.balance, 12500);
      expect(w.newestFirst().first.description, 'Received from Eric');
      expect(w.newestFirst().first.type, TxType.incoming);
    });

    test('refuses bad amounts and empty descriptions', () {
      for (final bad in ['0', '-200', '5k', '1.5', '', 'abc']) {
        expect(w.receive(bad, 'x').ok, isFalse, reason: bad);
      }
      expect(w.receive('100', '   ').error, 'Description cannot be empty');
      expect(w.transactions.length, 5);
    });
  });

  group('send', () {
    test('to 0721234567 is refused: not 078 or 079', () {
      final r = w.send('0721234567', '1000');
      expect(r.error, 'Phone number must start with 078 or 079');
      expect(w.balance, 10000);
    });

    test('50 RWF to 0788123456 is refused: below 100', () {
      expect(w.send('0788123456', '50').error, 'Minimum send amount is 100 RWF');
      expect(w.balance, 10000);
    });

    test('phone must be exactly 10 digits', () {
      expect(w.send('078812345', '1000').error, 'Phone number must be exactly 10 digits');
      expect(w.send('07881234567', '1000').error, 'Phone number must be exactly 10 digits');
      expect(w.send('078812345a', '1000').error, 'Phone number must be exactly 10 digits');
    });

    test('success adds OUT "Sent to ..." plus a separate 100 RWF fee OUT', () {
      final r = w.send('0788123456', '1000');
      expect(r.ok, isTrue);
      final [fee, sent, ...] = w.newestFirst();
      expect(sent.description, 'Sent to 0788123456');
      expect(sent.amount, 1000);
      expect(fee.amount, 100);
      expect(fee.feeFor, sent.id);
      expect(w.balance, 8900);
    });

    test('the fee counts toward insufficient balance', () {
      expect(w.send('0788123456', '10000').error, 'Insufficient balance');
      expect(w.send('0788123456', '9900').ok, isTrue);
      expect(w.balance, 0);
    });
  });

  group('cash out', () {
    test('23,700 gives 5,000×4 · 2,000×1 · 1,000×1 · 500×1 · 100×2', () {
      w.receive('20000', 'Top up'); // balance 30,000
      final q = w.quoteCashOut('23700');
      expect(q.ok, isTrue);
      expect(q.value!.notes, {5000: 4, 2000: 1, 1000: 1, 500: 1, 100: 2});
      expect(q.value!.notes.keys.toList(), [5000, 2000, 1000, 500, 100]);
      expect(q.value.toString(),
          '5,000 × 4 · 2,000 × 1 · 1,000 × 1 · 500 × 1 · 100 × 2');
      expect(w.balance, 30000, reason: 'quoting moves no money');

      expect(w.confirmCashOut(q.value!).ok, isTrue);
      expect(w.newestFirst().first.description, 'Cash out');
      expect(w.balance, 6300);
    });

    test('250 is refused', () {
      expect(w.quoteCashOut('250').ok, isFalse);
      expect(w.quoteCashOut('250').error, contains('multiple of 100'));
    });

    test('confirm re-checks the balance', () {
      final q = w.quoteCashOut('10000').value!;
      w.send('0788123456', '100'); // balance now 9,800
      expect(w.confirmCashOut(q).error, 'Insufficient balance');
      expect(w.balance, 9800);
    });
  });

  group('refused OUTs', () {
    test('1,000,000 is refused: insufficient balance', () {
      expect(w.send('0788123456', '1000000').error, 'Insufficient balance');
      expect(w.send('0788123456', '1,000,000').error, 'Insufficient balance');
      expect(w.quoteCashOut('1000000').error, 'Insufficient balance');
    });

    test('5k, 0 and -200 are refused', () {
      for (final bad in ['5k', '0', '-200']) {
        expect(w.send('0788123456', bad).ok, isFalse, reason: bad);
        expect(w.quoteCashOut(bad).ok, isFalse, reason: bad);
      }
      expect(w.balance, 10000);
      expect(w.transactions.length, 5);
    });
  });

  group('statistics', () {
    test('sample totals and lowest balance', () {
      expect(w.totalIn, 6500);
      expect(w.totalOut, 6500);
      expect(w.lowestBalance, 8000);
    });

    test('right after several transactions', () {
      w.receive('3000', 'Gift'); // 13,000
      w.send('0791112233', '9000'); // 4,000 then fee 3,900
      w.confirmCashOut(w.quoteCashOut('3000').value!); // 900
      expect(w.balance, 900);
      expect(w.totalIn, 6500 + 3000);
      expect(w.totalOut, 6500 + 9000 + 100 + 3000);
      expect(w.lowestBalance, 900);
      expect(w.balance, 10000 + w.totalIn - w.totalOut);
    });

    test('right after a delete, and after undo', () {
      w.receive('3000', 'Gift');
      w.send('0791112233', '9000'); // lowest 3,900
      final sendId = w.newestFirst()[1].id;

      final d = w.delete(sendId); // removes send + fee
      expect(d.ok, isTrue);
      expect(d.value!.removed.length, 2);
      expect(w.balance, 13000);
      expect(w.totalOut, 6500);
      expect(w.lowestBalance, 8000);

      expect(w.undo(d.value!).ok, isTrue);
      expect(w.balance, 3900);
      expect(w.lowestBalance, 3900);
      expect(w.newestFirst()[1].id, sendId, reason: 'restored in place');
    });

    test('lowest balance with no history is the opening balance', () {
      expect(Wallet().lowestBalance, 10000);
    });
  });

  group('delete', () {
    test('refused if the history would go below 0', () {
      w.receive('50000', 'Big deposit'); // 60,000
      w.send('0788123456', '55000'); // 4,900
      final depositId = w.newestFirst()[2].id;
      final r = w.delete(depositId);
      expect(r.ok, isFalse);
      expect(r.error, contains('below 0'));
      expect(w.balance, 4900);
    });

    test('undo is refused if the restored OUT would go below 0', () {
      final d = w.delete(5).value!; // the 1,500 send, balance 11,500
      w.send('0788123456', '11400'); // balance 0
      expect(w.undo(d).ok, isFalse);
      expect(w.balance, 0);
    });
  });

  group('parseAmount', () {
    test('accepts plain and grouped digits', () {
      expect(parseAmount('23700').value, 23700);
      expect(parseAmount('23,700').value, 23700);
      expect(parseAmount(' 100 ').value, 100);
    });
    test('refuses non-whole and non-positive', () {
      for (final bad in ['5k', '0', '-200', '1.5', '2,37', '', '1e3', '99999999999999']) {
        expect(parseAmount(bad).ok, isFalse, reason: bad);
      }
    });
  });
}
