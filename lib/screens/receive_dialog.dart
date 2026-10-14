import 'package:flutter/material.dart';

import '../ui.dart';
import '../wallet.dart';

/// Asks for an amount and a description, and adds an IN.
/// Returns a success message, or null if cancelled.
Future<String?> showReceiveDialog(BuildContext context, Wallet wallet) {
  return showDialog<String>(
    context: context,
    builder: (_) => _ReceiveDialog(wallet: wallet),
  );
}

class _ReceiveDialog extends StatefulWidget {
  const _ReceiveDialog({required this.wallet});
  final Wallet wallet;

  @override
  State<_ReceiveDialog> createState() => _ReceiveDialogState();
}

class _ReceiveDialogState extends State<_ReceiveDialog> {
  final _amount = TextEditingController();
  final _description = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    _description.dispose();
    super.dispose();
  }

  void _submit() {
    final result = widget.wallet.receive(_amount.text, _description.text);
    if (!result.ok) {
      setState(() => _error = result.error);
      return;
    }
    Navigator.of(context).pop('Received ${formatRwf(result.value!.amount)} RWF');
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
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(onPressed: _submit, child: const Text('Receive')),
      ],
    );
  }
}
