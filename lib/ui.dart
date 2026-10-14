import 'package:flutter/material.dart';

import 'wallet.dart';

const momoYellow = Color(0xFFFFCC00);
const momoBlue = Color(0xFF004F71);
const inGreen = Color(0xFF1B8A3A);
const outRed = Color(0xFFC62828);

Color colorOf(TxType type) => type == TxType.incoming ? inGreen : outRed;

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String formatDate(DateTime d) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${d.day} ${_months[d.month - 1]} ${d.year}, ${two(d.hour)}:${two(d.minute)}';
}

/// "+ 5,000 RWF" in green or "− 2,000 RWF" in red.
String signedRwf(Transaction t) =>
    '${t.isIn ? '+' : '−'} ${formatRwf(t.amount)} RWF';

class TypeBadge extends StatelessWidget {
  const TypeBadge(this.type, {super.key});
  final TxType type;

  @override
  Widget build(BuildContext context) {
    final color = colorOf(type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        type.label,
        style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12),
      ),
    );
  }
}

/// A red box saying which rule refused the operation.
class ErrorBox extends StatelessWidget {
  const ErrorBox(this.message, {super.key});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('error-box'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: outRed.withValues(alpha: 0.08),
        border: Border.all(color: outRed.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.block, color: outRed, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message,
                style: const TextStyle(color: outRed, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

/// Shows the available balance at the top of the money-moving screens.
class AvailableBalance extends StatelessWidget {
  const AvailableBalance(this.wallet, {super.key});
  final Wallet wallet;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: wallet,
      builder: (context, _) => Text(
        'Available: ${formatRwf(wallet.balance)} RWF',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.black54),
      ),
    );
  }
}
