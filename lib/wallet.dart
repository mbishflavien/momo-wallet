import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
    this.createdAt,
    this.feeFor,
  });

  /// The Firestore document id.
  final String id;
  final TxType type;
  final int amount;
  final String description;

  /// Written by the server with [FieldValue.serverTimestamp].
  final DateTime? createdAt;

  /// If this is a send fee, the id of the send document it belongs to.
  final String? feeFor;

  bool get isIn => type == TxType.incoming;
  bool get isFee => feeFor != null;
  int get signedAmount => isIn ? amount : -amount;

  /// Only the facts the user typed or chose are saved.
  Map<String, dynamic> toMap() => {
        'description': description,
        'amount': amount,
        'type': type.name,
        if (feeFor != null) 'feeFor': feeFor,
      };

  factory Transaction.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    final rawType = data['type'] as String?;
    final legacyIsIn = data['isIn'] as bool?;
    final type = rawType == 'incoming' || (rawType == null && legacyIsIn == true)
        ? TxType.incoming
        : TxType.outgoing;
    return Transaction(
      id: doc.id,
      type: type,
      amount: (data['amount'] as num).toInt(),
      description: data['description'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      feeFor: data['feeFor'] as String?,
    );
  }
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

/// Everything computed from a user's saved transactions.
///
/// Balance, totals and the lowest balance are never saved: they are worked
/// out from the list every time it arrives, so they can never be wrong.
class WalletData {
  WalletData(List<Transaction> newestFirst) : transactions = newestFirst;

  /// Newest first, as Firestore returns them.
  final List<Transaction> transactions;

  /// Oldest first, so running balances make sense.
  Iterable<Transaction> get chronological => transactions.reversed;

  int get balance => transactions.fold(0, (b, t) => b + t.signedAmount);

  int get totalIn =>
      transactions.where((t) => t.isIn).fold(0, (total, t) => total + t.amount);

  int get totalOut =>
      transactions.where((t) => !t.isIn).fold(0, (total, t) => total + t.amount);

  /// Lowest balance ever reached. The balance before the first saved
  /// transaction is not counted: the opening balance is itself a document.
  int get lowestBalance {
    var b = 0;
    int? lowest;
    for (final t in chronological) {
      b += t.signedAmount;
      if (lowest == null || b < lowest) lowest = b;
    }
    return lowest ?? 0;
  }

  List<Transaction> newestFirst({TxType? filter}) => filter == null
      ? transactions
      : transactions.where((t) => t.type == filter).toList(growable: false);

  Transaction? byId(String id) {
    for (final t in transactions) {
      if (t.id == id) return t;
    }
    return null;
  }

  /// The balance right after [tx] was applied.
  int balanceAfter(Transaction tx) {
    var b = 0;
    for (final t in chronological) {
      b += t.signedAmount;
      if (t.id == tx.id) return b;
    }
    return b;
  }

  /// The fee attached to a send, if any.
  Transaction? feeOf(Transaction send) {
    for (final t in transactions) {
      if (t.feeFor == send.id) return t;
    }
    return null;
  }
}

// ---------------------------------------------------------------- Firestore

/// The signed-in user's transactions: users/{uid}/transactions
CollectionReference<Map<String, dynamic>> myTransactions() {
  final uid = FirebaseAuth.instance.currentUser!.uid;
  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('transactions');
}

/// Sample data, written once when a new account is created.
Future<void> addSampleTransactions() async {
  final samples = [
    Transaction(
        id: '',
        type: TxType.incoming,
        amount: 10000,
        description: 'Opening balance'),
    Transaction(
        id: '',
        type: TxType.outgoing,
        amount: 2500,
        description: 'Sent to 0788123456'),
    Transaction(
        id: '',
        type: TxType.incoming,
        amount: 4000,
        description: 'Received from Keza'),
  ];
  final batch = FirebaseFirestore.instance.batch();
  for (final t in samples) {
    batch.set(myTransactions().doc(), {
      ...t.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
  await batch.commit();
}

/// Saves one new transaction (receive or cash out).
Future<void> addTransaction({
  required TxType type,
  required int amount,
  required String description,
}) async {
  await myTransactions().add({
    'type': type.name,
    'amount': amount,
    'description': description,
    'createdAt': FieldValue.serverTimestamp(),
  });
}

/// Saves a send plus its separate fee in one batch: both or none.
Future<void> addSend({required String phone, required int amount}) async {
  final batch = FirebaseFirestore.instance.batch();
  final sendRef = myTransactions().doc();
  batch.set(sendRef, {
    'type': TxType.outgoing.name,
    'amount': amount,
    'description': 'Sent to $phone',
    'createdAt': FieldValue.serverTimestamp(),
  });
  batch.set(myTransactions().doc(), {
    'type': TxType.outgoing.name,
    'amount': sendFee,
    'description': 'Send fee ($phone)',
    'feeFor': sendRef.id,
    'createdAt': FieldValue.serverTimestamp(),
  });
  await batch.commit();
}

/// Edits the facts the user typed on an existing document.
Future<void> updateTransaction(
  Transaction tx, {
  required String description,
  required int amount,
}) async {
  await myTransactions().doc(tx.id).update({
    'description': description,
    'amount': amount,
  });
}

/// Deletes [tx], and its fee document when [fee] is given.
Future<void> deleteTransaction(Transaction tx, {Transaction? fee}) async {
  final batch = FirebaseFirestore.instance.batch();
  batch.delete(myTransactions().doc(tx.id));
  if (fee != null) batch.delete(myTransactions().doc(fee.id));
  await batch.commit();
}
