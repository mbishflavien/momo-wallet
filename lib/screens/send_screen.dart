import 'package:flutter/material.dart';

import '../ui.dart';
import '../wallet.dart';

class SendScreen extends StatefulWidget {
  const SendScreen({super.key, required this.wallet});
  final Wallet wallet;

  @override
  State<SendScreen> createState() => _SendScreenState();
}

class _SendScreenState extends State<SendScreen> {
  final _phone = TextEditingController();
  final _amount = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _phone.dispose();
    _amount.dispose();
    super.dispose();
  }

  void _send() {
    final result = widget.wallet.send(_phone.text, _amount.text);
    if (!result.ok) {
      setState(() => _error = result.error);
      return;
    }
    final tx = result.value!;
    Navigator.of(context).pop(
        '${tx.description}: ${formatRwf(tx.amount)} RWF (+ ${formatRwf(sendFee)} RWF fee)');
  }

  @override
  Widget build(BuildContext context) {
    final amount = parseAmount(_amount.text);
    return Scaffold(
      appBar: AppBar(backgroundColor: momoYellow, title: const Text('Send money')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              AvailableBalance(widget.wallet),
              const SizedBox(height: 16),
              TextField(
                key: const Key('send-phone'),
                controller: _phone,
                autofocus: true,
                keyboardType: TextInputType.phone,
                maxLength: 10,
                decoration: const InputDecoration(
                  labelText: 'Phone number',
                  hintText: '0788123456',
                  helperText: '10 digits, starting with 078 or 079',
                ),
                onChanged: (_) => setState(() => _error = null),
              ),
              const SizedBox(height: 8),
              TextField(
                key: const Key('send-amount'),
                controller: _amount,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Amount (RWF)',
                  helperText: 'At least $minSend RWF',
                ),
                onChanged: (_) => setState(() => _error = null),
                onSubmitted: (_) => _send(),
              ),
              const SizedBox(height: 12),
              Text(
                amount.ok
                    ? 'Fee ${formatRwf(sendFee)} RWF · total ${formatRwf(amount.value! + sendFee)} RWF'
                    : 'A ${formatRwf(sendFee)} RWF fee is added to every send',
                style: const TextStyle(color: Colors.black54),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                ErrorBox(_error!),
              ],
            ],
          ),
        ),
      ),
      // Action pinned to the bottom: always visible, never scrolled away.
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
              16, 8, 16, 12 + MediaQuery.viewInsetsOf(context).bottom),
          child: FilledButton.icon(
            key: const Key('send-button'),
            onPressed: _send,
            icon: const Icon(Icons.send),
            label: const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('Send'),
            ),
          ),
        ),
      ),
    );
  }
}
