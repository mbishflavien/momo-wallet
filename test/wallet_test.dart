import 'package:flutter_test/flutter_test.dart';
import 'package:momo_wallet/wallet.dart';

Transaction tx(
  String id,
  TxType type,
  int amount, {
  String description = 'x',
  String? feeFor,
}) =>
    Transaction(
      id: id,
      type: type,
      amount: amount,
      description: description,
      feeFor: feeFor,
    );

void main() {
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

  group('validatePhone', () {
    test('accepts 078 and 079, exactly 10 digits', () {
      expect(validatePhone('0788123456'), isNull);
      expect(validatePhone('0791234567'), isNull);
    });

    test('refuses other networks, wrong length and letters', () {
      expect(validatePhone('0721234567'), 'Phone number must start with 078 or 079');
      expect(validatePhone('078812345'), 'Phone number must be exactly 10 digits');
      expect(validatePhone('07881234567'), 'Phone number must be exactly 10 digits');
      expect(validatePhone('078812345a'), 'Phone number must be exactly 10 digits');
    });
  });

  group('splitIntoNotes', () {
    test('23,700 gives 5,000 x4, 2,000 x1, 1,000 x1, 500 x1, 100 x2', () {
      final quote = CashOutQuote(23700, splitIntoNotes(23700));
      expect(quote.notes, {5000: 4, 2000: 1, 1000: 1, 500: 1, 100: 2});
      expect(quote.notes.keys.toList(), [5000, 2000, 1000, 500, 100]);
      expect(quote.toString(),
          '5,000 × 4 · 2,000 × 1 · 1,000 × 1 · 500 × 1 · 100 × 2');
    });
  });

  group('WalletData', () {
    // Newest first, exactly as Firestore returns them.
    final data = WalletData([
      tx('fee', TxType.outgoing, 100, feeFor: 'send', description: 'Send fee'),
      tx('send', TxType.outgoing, 1000, description: 'Sent to 0788123456'),
      tx('in', TxType.incoming, 4000, description: 'Received from Keza'),
      tx('open', TxType.incoming, 10000, description: 'Opening balance'),
    ]);

    test('computes balance and totals from the saved facts', () {
      expect(data.balance, 12900);
      expect(data.totalIn, 14000);
      expect(data.totalOut, 1100);
    });

    test('computes the lowest balance chronologically', () {
      expect(data.lowestBalance, 10000);
    });

    test('computes the balance after a document', () {
      expect(data.balanceAfter(data.byId('send')!), 13000);
      expect(data.balanceAfter(data.byId('fee')!), 12900);
    });

    test('finds the fee that belongs to a send', () {
      expect(data.feeOf(data.byId('send')!)!.id, 'fee');
      expect(data.feeOf(data.byId('open')!), isNull);
    });

    test('filters IN and OUT', () {
      expect(data.newestFirst(filter: TxType.incoming).length, 2);
      expect(data.newestFirst(filter: TxType.outgoing).length, 2);
      expect(data.newestFirst(filter: TxType.outgoing).first.id, 'fee');
    });
  });

  group('Transaction.toMap', () {
    test('saves only the facts, plus the fee link when present', () {
      final t = tx('1', TxType.outgoing, 1000, description: 'Sent to 0788123456');
      expect(t.toMap(), {
        'description': 'Sent to 0788123456',
        'amount': 1000,
        'type': 'outgoing',
      });
      final fee = tx('2', TxType.outgoing, 100, description: 'Send fee', feeFor: '1');
      expect(fee.toMap()['feeFor'], '1');
    });
  });
}
