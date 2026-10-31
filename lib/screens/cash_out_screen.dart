import 'package:flutter/material.dart';

import '../ui.dart';
import '../wallet.dart';

class CashOutScreen extends StatefulWidget {
  const CashOutScreen({super.key, required this.data});
  final WalletData data;

  @override
  State<CashOutScreen> createState() => _CashOutScreenState();
}

class _CashOutScreenState extends State<CashOutScreen> {
  final _amount = TextEditingController();
  CashOutQuote? _quote;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Outcome<CashOutQuote> _quoteCashOut(String amountText) {
    final amount = parseAmount(amountText);
    if (!amount.ok) return Outcome.refused(amount.error!);
    final value = amount.value!;
    if (value % 100 != 0) {
      return const Outcome.refused(
          'Amount must be a multiple of 100 RWF (the smallest note is 100)');
    }
    if (value > widget.data.balance) {
      return const Outcome.refused('Insufficient balance');
    }
    return Outcome.ok(CashOutQuote(value, splitIntoNotes(value)));
  }

  void _showNotes() {
    FocusScope.of(context).unfocus(); // close the keyboard so the notes are visible
    final result = _quoteCashOut(_amount.text);
    setState(() {
      _quote = result.value;
      _error = result.error;
    });
  }

  Future<void> _confirm() async {
    final quote = _quote!;
    // Re-check: the balance may have changed since the quote was shown.
    final fresh = _quoteCashOut('${quote.amount}');
    if (!fresh.ok) {
      setState(() {
        _quote = null;
        _error = fresh.error;
      });
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await addTransaction(
        type: TxType.outgoing,
        amount: quote.amount,
        description: 'Cash out',
      );
      if (!mounted) return;
      Navigator.of(context).pop('Cash out: ${formatRwf(quote.amount)} RWF');
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Could not cash out: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final quote = _quote;
    return Scaffold(
      appBar: AppBar(backgroundColor: momoYellow, title: const Text('Cash out')),
      body: GestureDetector(
        // Tapping outside the field closes the keyboard.
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.translucent,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AvailableBalance(widget.data.balance),
                  const SizedBox(height: 12),
                  TextField(
                    key: const Key('cashout-amount'),
                    controller: _amount,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      labelText: 'Amount (RWF)',
                      helperText: 'Multiple of 100',
                    ),
                    // Any edit invalidates the shown notes: you must look again.
                    onChanged: (_) => setState(() {
                      _quote = null;
                      _error = null;
                    }),
                    onSubmitted: (_) => _showNotes(),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    ErrorBox(_error!),
                  ],
                  if (quote != null) ...[
                    const SizedBox(height: 12),
                    _NotesCard(quote: quote),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
      // Action pinned to the bottom: always visible, never scrolled away.
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
              16, 8, 16, 12 + MediaQuery.viewInsetsOf(context).bottom),
          child: quote == null
              ? OutlinedButton.icon(
                  key: const Key('cashout-notes'),
                  onPressed: _showNotes,
                  icon: const Icon(Icons.payments_outlined),
                  label: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('Show notes'),
                  ),
                )
              : FilledButton.icon(
                  key: const Key('cashout-confirm'),
                  onPressed: _busy ? null : _confirm,
                  icon: const Icon(Icons.check),
                  label: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text('Confirm ${formatRwf(quote.amount)} RWF'),
                  ),
                ),
        ),
      ),
    );
  }
}

/// The notes as compact "banknotes" that wrap: fits on screen without scrolling.
class _NotesCard extends StatelessWidget {
  const _NotesCard({required this.quote});
  final CashOutQuote quote;

  @override
  Widget build(BuildContext context) {
    final noteCount = quote.notes.values.fold(0, (a, b) => a + b);
    return Card(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('The agent will hand you',
                style: TextStyle(color: Colors.black54)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final e in quote.notes.entries)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: momoYellow.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: momoYellow),
                    ),
                    child: Text('${formatRwf(e.key)} × ${e.value}',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
              ],
            ),
            const Divider(height: 20),
            Row(
              children: [
                Text('$noteCount note${noteCount == 1 ? '' : 's'}',
                    style: const TextStyle(color: Colors.black54)),
                const Spacer(),
                Text('${formatRwf(quote.amount)} RWF',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
