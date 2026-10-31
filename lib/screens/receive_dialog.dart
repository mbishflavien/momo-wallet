import 'package:flutter/material.dart';

import '../ui.dart';
import '../wallet.dart';

/// Asks for an amount and a description, and saves an IN to Firestore.
/// Returns a success message, or null if cancelled.
Future<String?> showReceiveDialog(BuildContext context) {
  return showDialog<String>(
    context: context,
    builder: (_) => const _ReceiveDialog(),
  );
}

class _ReceiveDialog extends StatefulWidget {
  const _ReceiveDialog();

  @override
  State<_ReceiveDialog> createState() => _ReceiveDialogState();
}

class _ReceiveDialogState extends State<_ReceiveDialog> {
  final _amount = TextEditingController();
  final _description = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _amount.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
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

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await addTransaction(
        type: TxType.incoming,
        amount: amount.value!,
        description: description,
      );
      if (!mounted) return;
      Navigator.of(context).pop('Received ${formatRwf(amount.value!)} RWF');
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Could not save: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Receive money'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const Key('receive-amount'),
              controller: _amount,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Amount (RWF)'),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('receive-description'),
              controller: _description,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'e.g. Received from Aline',
              ),
              onSubmitted: (_) => _submit(),
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
            onPressed: _busy ? null : () => Navigator.of(context).pop(),
            child: const Text('Cancel')),
        FilledButton(
            onPressed: _busy ? null : _submit, child: const Text('Receive')),
      ],
    );
  }
}
