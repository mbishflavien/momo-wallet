import 'package:flutter/material.dart';

import '../ui.dart';
import '../wallet.dart';

/// Shows one transaction. Pops with a [Deletion] if it was deleted.
class DetailsScreen extends StatefulWidget {
  const DetailsScreen({super.key, required this.wallet, required this.tx});
  final Wallet wallet;
  final Transaction tx;

  @override
  State<DetailsScreen> createState() => _DetailsScreenState();
}

class _DetailsScreenState extends State<DetailsScreen> {
  String? _error;

  void _delete() {
    final result = widget.wallet.delete(widget.tx.id);
    if (!result.ok) {
      setState(() => _error = result.error);
      return;
    }
    Navigator.of(context).pop(result.value);
  }

  @override
  Widget build(BuildContext context) {
    final wallet = widget.wallet;
    final tx = widget.tx;
    final color = colorOf(tx.type);
    final fee = wallet.feeOf(tx);
    final parent = tx.isFee ? wallet.byId(tx.feeFor!) : null;

    return Scaffold(
      appBar: AppBar(backgroundColor: momoYellow, title: const Text('Transaction')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const SizedBox(height: 8),
              Center(
                child: CircleAvatar(
                  radius: 32,
                  backgroundColor: color.withValues(alpha: 0.12),
                  child: Icon(tx.isIn ? Icons.south_west : Icons.north_east,
                      color: color, size: 32),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(signedRwf(tx),
                    style: TextStyle(color: color, fontSize: 30, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(height: 6),
              Center(child: TypeBadge(tx.type)),
              const SizedBox(height: 20),
              Card(
                color: Colors.white,
                elevation: 0,
                margin: EdgeInsets.zero,
                child: Column(
                  children: [
                    _Row('Description', tx.description),
                    _Row('Date', formatDate(tx.date)),
                    _Row('Balance after', '${formatRwf(wallet.balanceAfter(tx))} RWF'),
                    if (fee != null) _Row('Fee', '${formatRwf(fee.amount)} RWF (separate OUT)'),
                    if (parent != null) _Row('Fee for', parent.description),
                    _Row('Reference', 'TX${tx.id.toString().padLeft(6, '0')}'),
                  ],
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                ErrorBox(_error!),
              ],
              const SizedBox(height: 24),
              OutlinedButton.icon(
                key: const Key('details-delete'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: outRed,
                  side: const BorderSide(color: outRed),
                ),
                onPressed: _delete,
                icon: const Icon(Icons.delete_outline),
                label: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(fee != null ? 'Delete (with its fee)' : 'Delete'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);
  final String label, value;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      title: Text(label, style: const TextStyle(color: Colors.black54)),
      trailing: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 240),
        child: Text(value,
            textAlign: TextAlign.right,
            style: const TextStyle(fontWeight: FontWeight.w600)),
      ),
    );
  }
}
