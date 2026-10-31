import 'package:flutter/material.dart';

import '../ui.dart';
import '../wallet.dart';

/// Shows one transaction. Pops with a message if it was edited or deleted.
class DetailsScreen extends StatefulWidget {
  const DetailsScreen({super.key, required this.data, required this.tx});
  final WalletData data;
  final Transaction tx;

  @override
  State<DetailsScreen> createState() => _DetailsScreenState();
}

class _DetailsScreenState extends State<DetailsScreen> {
  String? _error;
  bool _busy = false;

  Future<void> _edit() async {
    final edited = await showDialog<({String description, int amount})>(
      context: context,
      builder: (_) => _EditDialog(tx: widget.tx),
    );
    if (edited == null || !mounted) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await updateTransaction(widget.tx,
          description: edited.description, amount: edited.amount);
      if (!mounted) return;
      Navigator.of(context).pop('Updated: ${edited.description}');
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Could not update: $e';
        });
      }
    }
  }

  Future<void> _delete() async {
    final tx = widget.tx;
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tx.isFee
            ? 'Delete this fee?'
            : widget.data.feeOf(tx) != null
                ? 'Delete this transaction and its fee?'
                : 'Delete this transaction?'),
        content: Text(tx.description),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (sure != true || !mounted) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await deleteTransaction(tx, fee: widget.data.feeOf(tx));
      if (!mounted) return;
      Navigator.of(context).pop('Deleted: ${tx.description}');
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Could not delete: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final tx = widget.tx;
    final color = colorOf(tx.type);
    final fee = data.feeOf(tx);
    final parent = tx.isFee ? data.byId(tx.feeFor!) : null;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: momoYellow,
        title: const Text('Transaction'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Edit',
            onPressed: _busy ? null : _edit,
          ),
        ],
      ),
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
                    _Row('Date', dateLabel(tx)),
                    _Row('Balance after', '${formatRwf(data.balanceAfter(tx))} RWF'),
                    if (fee != null) _Row('Fee', '${formatRwf(fee.amount)} RWF (separate OUT)'),
                    if (parent != null) _Row('Fee for', parent.description),
                    _Row('Reference', 'TX${tx.id.substring(tx.id.length - 6).toUpperCase()}'),
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
                onPressed: _busy ? null : _delete,
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

class _EditDialog extends StatefulWidget {
  const _EditDialog({required this.tx});
  final Transaction tx;

  @override
  State<_EditDialog> createState() => _EditDialogState();
}

class _EditDialogState extends State<_EditDialog> {
  late final TextEditingController _description;
  late final TextEditingController _amount;
  String? _error;

  @override
  void initState() {
    super.initState();
    _description = TextEditingController(text: widget.tx.description);
    _amount = TextEditingController(text: '${widget.tx.amount}');
  }

  @override
  void dispose() {
    _description.dispose();
    _amount.dispose();
    super.dispose();
  }

  void _save() {
    final amount = parseAmount(_amount.text);
    if (!amount.ok) {
      setState(() => _error = amount.error);
      return;
    }
    final description = _description.text.trim();
    if (description.isEmpty) {
      setState(() => _error = 'Description cannot be empty');
      return;
    }
    Navigator.of(context)
        .pop((description: description, amount: amount.value!));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit transaction'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _description,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amount,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Amount (RWF)'),
              onSubmitted: (_) => _save(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              ErrorBox(_error!),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel')),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
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
