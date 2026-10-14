import 'package:flutter/foundation.dart';

/// Direction of a transaction: money coming IN or going OUT.
enum TxType {
  incoming('IN'),
  outgoing('OUT');

  const TxType(this.label);
  final String label;
}

class Transaction {
  const Transaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.description,
    required this.date,
    this.feeFor,
  });

  /// Ids grow with time, so they also give the chronological order.
  final int id;
  final TxType type;
  final int amount;
  final String description;
  final DateTime date;

  /// If this is a send fee, the id of the send it belongs to.
  final int? feeFor;

  bool get isIn => type == TxType.incoming;
  bool get isFee => feeFor != null;
  int get signedAmount => isIn ? amount : -amount;
}

/// What was removed by a delete, so it can be put back with Undo.
class Deletion {
  const Deletion(this.removed);
  final List<Transaction> removed;
}

/// The notes an agent hands over for a cash out, biggest first.
class CashOutQuote {
  const CashOutQuote(this.amount, this.notes);
  final int amount;

  /// note value -> count, ordered biggest note first, zero counts omitted.
  final Map<int, int> notes;

  /// e.g. "5,000 × 4 · 2,000 × 1 · 100 × 2"
  @override
  String toString() =>
      notes.entries.map((e) => '${formatRwf(e.key)} × ${e.value}').join(' · ');
}

/// Result of an operation: either a value or the rule that refused it.
class Outcome<T> {
  const Outcome.ok(T this.value) : error = null;
  const Outcome.refused(String this.error) : value = null;
  final T? value;
  final String? error;
  bool get ok => error == null;
}

const int sendFee = 100;
const int minSend = 100;
const List<int> agentNotes = [5000, 2000, 1000, 500, 100];

/// Formats 23700 as "23,700".
String formatRwf(int amount) {
  final digits = amount.abs().toString();
  final buf = StringBuffer(amount < 0 ? '-' : '');
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write(',');
    buf.write(digits[i]);
  }
  return buf.toString();
}

final _plainDigits = RegExp(r'^\d+$');
final _groupedDigits = RegExp(r'^\d{1,3}(,\d{3})+$');

/// Parses an amount typed by the user. Accepts "23700" or "23,700".
/// Refuses anything that is not a whole number above 0 ("5k", "0", "-200", "1.5").
Outcome<int> parseAmount(String input) {
  final text = input.trim();
  if (text.isEmpty) return const Outcome.refused('Enter an amount');
  if (text.startsWith('-') &&
      (_plainDigits.hasMatch(text.substring(1)) ||
          _groupedDigits.hasMatch(text.substring(1)))) {
    return const Outcome.refused('Amount must be greater than 0');
  }
  if (!_plainDigits.hasMatch(text) && !_groupedDigits.hasMatch(text)) {
    return const Outcome.refused('Amount must be a whole number (digits only)');
  }
  final digits = text.replaceAll(',', '');
  // 12 digits is far beyond any wallet and keeps us safe from int overflow
  // (on the web, ints are doubles and lose precision past 2^53).
  if (digits.replaceFirst(RegExp(r'^0+'), '').length > 12) {
    return const Outcome.refused('Amount is too large');
  }
  final value = int.parse(digits);
  if (value <= 0) return const Outcome.refused('Amount must be greater than 0');
  return Outcome.ok(value);
}

/// Checks a Rwandan MTN number: exactly 10 digits, starting 078 or 079.
String? validatePhone(String input) {
  final phone = input.trim();
  if (phone.isEmpty) return 'Enter a phone number';
  if (!RegExp(r'^\d{10}$').hasMatch(phone)) {
    return 'Phone number must be exactly 10 digits';
  }
  if (!phone.startsWith('078') && !phone.startsWith('079')) {
    return 'Phone number must start with 078 or 079';
  }
  return null;
}

/// Greedy split into agent notes. Exact for this note set because every
/// note is a multiple of 100 and greedy is optimal for 5000/2000/1000/500/100.
Map<int, int> splitIntoNotes(int amount) {
  final notes = <int, int>{};
  var rest = amount;
  for (final note in agentNotes) {
    final count = rest ~/ note;
    if (count > 0) notes[note] = count;
    rest -= count * note;
  }
  assert(rest == 0, 'amount must be a multiple of 100');
  return notes;
}

class Wallet extends ChangeNotifier {
  Wallet({
    this.openingBalance = 10000,
    List<Transaction>? history,
    DateTime Function()? clock,
  })  : _txs = [...?history],
        _clock = clock ?? DateTime.now {
    _nextId = _txs.fold(0, (m, t) => t.id > m ? t.id : m) + 1;
    if (_runningBalances(_txs) == null) {
      throw ArgumentError('history makes the balance go below 0');
    }
  }

  /// A wallet that starts at 10,000 RWF with sample history. The samples
  /// cancel out, so the balance is still 10,000 but the statistics have
  /// something to show (the lowest point was 8,000).
  factory Wallet.sample({DateTime Function()? clock}) {
    final now = (clock ?? DateTime.now)();
    DateTime ago(int hours) => now.subtract(Duration(hours: hours));
    return Wallet(clock: clock, history: [
      Transaction(id: 1, type: TxType.outgoing, amount: 2000,
          description: 'Sent to 0788123456', date: ago(72)),
      Transaction(id: 2, type: TxType.incoming, amount: 5000,
          description: 'Salary advance from Kigali Coffee', date: ago(50)),
      Transaction(id: 3, type: TxType.incoming, amount: 1500,
          description: 'Received from Aline', date: ago(26)),
      Transaction(id: 4, type: TxType.outgoing, amount: 3000,
          description: 'Cash out', date: ago(20)),
      Transaction(id: 5, type: TxType.outgoing, amount: 1500,
          description: 'Sent to 0791234567', date: ago(3)),
    ]);
  }

  /// Balance before the first transaction in the history.
  final int openingBalance;
  final List<Transaction> _txs; // chronological, oldest first
  final DateTime Function() _clock;
  late int _nextId;

  // ---------------------------------------------------------------- reading

  List<Transaction> get transactions => List.unmodifiable(_txs);

  List<Transaction> newestFirst({TxType? filter}) => _txs.reversed
      .where((t) => filter == null || t.type == filter)
      .toList(growable: false);

  Transaction? byId(int id) {
    for (final t in _txs) {
      if (t.id == id) return t;
    }
    return null;
  }

  int get balance => _txs.fold(openingBalance, (b, t) => b + t.signedAmount);

  int get totalIn =>
      _txs.where((t) => t.isIn).fold(0, (sum, t) => sum + t.amount);

  int get totalOut =>
      _txs.where((t) => !t.isIn).fold(0, (sum, t) => sum + t.amount);

  /// Lowest balance ever reached. Starts at the opening balance, not 0:
  /// the balance can never go below 0, so starting at 0 would always report 0.
  int get lowestBalance {
    var lowest = openingBalance;
    var b = openingBalance;
    for (final t in _txs) {
      b += t.signedAmount;
      if (b < lowest) lowest = b;
    }
    return lowest;
  }

  /// The balance right after [tx] was applied.
  int balanceAfter(Transaction tx) {
    var b = openingBalance;
    for (final t in _txs) {
      b += t.signedAmount;
      if (t.id == tx.id) return b;
    }
    throw StateError('transaction ${tx.id} is not in this wallet');
  }

  /// The fee attached to a send, if any.
  Transaction? feeOf(Transaction send) {
    for (final t in _txs) {
      if (t.feeFor == send.id) return t;
    }
    return null;
  }

  // ------------------------------------------------------------ moving money
  //
  // Every method validates everything first and only then touches _txs.
  // A refusal leaves the wallet exactly as it was.

  /// Receive money: whole number above 0, non-empty description.
  Outcome<Transaction> receive(String amountText, String description) {
    final amount = parseAmount(amountText);
    if (!amount.ok) return Outcome.refused(amount.error!);
    final desc = description.trim();
    if (desc.isEmpty) return const Outcome.refused('Description cannot be empty');

    final tx = _add(TxType.incoming, amount.value!, desc);
    notifyListeners();
    return Outcome.ok(tx);
  }

  /// Send money to an 078/079 number. Adds the send and a separate 100 RWF fee.
  Outcome<Transaction> send(String phoneText, String amountText) {
    final phoneError = validatePhone(phoneText);
    if (phoneError != null) return Outcome.refused(phoneError);
    final amount = parseAmount(amountText);
    if (!amount.ok) return Outcome.refused(amount.error!);
    if (amount.value! < minSend) {
      return Outcome.refused('Minimum send amount is ${formatRwf(minSend)} RWF');
    }
    if (amount.value! + sendFee > balance) {
      return const Outcome.refused('Insufficient balance');
    }

    final phone = phoneText.trim();
    final tx = _add(TxType.outgoing, amount.value!, 'Sent to $phone');
    _add(TxType.outgoing, sendFee, 'Send fee ($phone)', feeFor: tx.id);
    notifyListeners();
    return Outcome.ok(tx);
  }

  /// Works out the notes for a cash out without moving any money.
  Outcome<CashOutQuote> quoteCashOut(String amountText) {
    final amount = parseAmount(amountText);
    if (!amount.ok) return Outcome.refused(amount.error!);
    final value = amount.value!;
    if (value % 100 != 0) {
      return const Outcome.refused(
          'Amount must be a multiple of 100 RWF (the smallest note is 100)');
    }
    if (value > balance) return const Outcome.refused('Insufficient balance');
    return Outcome.ok(CashOutQuote(value, splitIntoNotes(value)));
  }

  /// Confirms a cash out. Re-checks everything: the balance may have changed
  /// between the quote and the confirm.
  Outcome<Transaction> confirmCashOut(CashOutQuote quote) {
    final fresh = quoteCashOut('${quote.amount}');
    if (!fresh.ok) return Outcome.refused(fresh.error!);

    final tx = _add(TxType.outgoing, quote.amount, 'Cash out');
    notifyListeners();
    return Outcome.ok(tx);
  }

  // --------------------------------------------------------- delete & undo

  /// Null if [id] can be deleted, otherwise the reason it cannot.
  String? whyCannotDelete(int id) {
    final target = byId(id);
    if (target == null) return 'Transaction not found';
    final ids = _idsRemovedWith(target);
    final rest = _txs.where((t) => !ids.contains(t.id)).toList();
    if (_runningBalances(rest) == null) {
      return 'Cannot delete: the balance would go below 0 in the history';
    }
    return null;
  }

  /// Deletes a transaction (and, for a send, its fee). Refused if the
  /// history without it would dip below 0 at any point.
  Outcome<Deletion> delete(int id) {
    final reason = whyCannotDelete(id);
    if (reason != null) return Outcome.refused(reason);

    final ids = _idsRemovedWith(byId(id)!);
    final removed = _txs.where((t) => ids.contains(t.id)).toList();
    _txs.removeWhere((t) => ids.contains(t.id));
    notifyListeners();
    return Outcome.ok(Deletion(removed));
  }

  /// Puts deleted transactions back in their original place. Also checked:
  /// restoring an old OUT after the money was spent could go below 0.
  Outcome<void> undo(Deletion deletion) {
    final missing =
        deletion.removed.where((t) => byId(t.id) == null).toList();
    if (missing.isEmpty) return const Outcome.ok(null);

    final restored = [..._txs, ...missing]..sort((a, b) => a.id.compareTo(b.id));
    if (_runningBalances(restored) == null) {
      return const Outcome.refused(
          'Cannot undo: the balance would go below 0 in the history');
    }
    _txs
      ..clear()
      ..addAll(restored);
    notifyListeners();
    return const Outcome.ok(null);
  }

  // ---------------------------------------------------------------- helpers

  Transaction _add(TxType type, int amount, String description, {int? feeFor}) {
    final tx = Transaction(
      id: _nextId++,
      type: type,
      amount: amount,
      description: description,
      date: _clock(),
      feeFor: feeFor,
    );
    _txs.add(tx);
    return tx;
  }

  Set<int> _idsRemovedWith(Transaction target) =>
      {target.id, ..._txs.where((t) => t.feeFor == target.id).map((t) => t.id)};

  /// Running balances for [txs], or null if any of them is below 0.
  List<int>? _runningBalances(List<Transaction> txs) {
    var b = openingBalance;
    final out = <int>[];
    for (final t in txs) {
      b += t.signedAmount;
      if (b < 0) return null;
      out.add(b);
    }
    return out;
  }
}
