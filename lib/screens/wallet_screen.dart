import 'package:cloud_firestore/cloud_firestore.dart' show QuerySnapshot;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../ui.dart';
import '../wallet.dart';
import 'cash_out_screen.dart';
import 'details_screen.dart';
import 'receive_dialog.dart';
import 'send_screen.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  TxType? _filter; // null = All

  void _toast(String message, {bool error = false, SnackBarAction? action}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: error ? outRed : null,
        action: action,
      ));
  }

  Future<void> _open(Widget screen) async {
    final message = await Navigator.of(context)
        .push<String>(MaterialPageRoute(builder: (_) => screen));
    if (message != null && mounted) _toast(message);
  }

  Future<void> _receive() async {
    final message = await showReceiveDialog(context);
    if (message != null && mounted) _toast(message);
  }

  Future<void> _openDetails(WalletData data, Transaction tx) async {
    final message = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => DetailsScreen(data: data, tx: tx)),
    );
    if (message != null && mounted) _toast(message);
  }

  /// Asks, then deletes. Always returns false: the Firestore stream removes
  /// the tile, so the Dismissible is never left dismissed inside the tree.
  Future<bool> _deleteWithConfirm(
      BuildContext context, WalletData data, Transaction tx) async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this transaction?'),
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
    if (sure != true) return false;
    try {
      await deleteTransaction(tx, fee: data.feeOf(tx));
      if (mounted) _toast('Deleted: ${tx.description}');
    } catch (e) {
      if (mounted) _toast('Could not delete: $e', error: true);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: momoYellow,
        title: const Text('MoMo Wallet', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Log out',
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream:
            myTransactions().orderBy('createdAt', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Could not load your transactions.\n${snapshot.error}',
                    textAlign: TextAlign.center),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = WalletData(
              snapshot.data!.docs.map(Transaction.fromDoc).toList());
          final txs = data.newestFirst(filter: _filter);
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    sliver: SliverList.list(children: [
                      _BalanceCard(
                        balance: data.balance,
                        onReceive: _receive,
                        onSend: () => _open(SendScreen(data: data)),
                        onCashOut: () => _open(CashOutScreen(data: data)),
                      ),
                      const SizedBox(height: 12),
                      _StatsRow(data: data),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Text('Transactions',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700)),
                          const Spacer(),
                          SegmentedButton<TxType?>(
                            showSelectedIcon: false,
                            segments: const [
                              ButtonSegment(value: null, label: Text('All')),
                              ButtonSegment(value: TxType.incoming, label: Text('IN')),
                              ButtonSegment(value: TxType.outgoing, label: Text('OUT')),
                            ],
                            selected: {_filter},
                            onSelectionChanged: (s) => setState(() => _filter = s.first),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text('Tap for details · swipe left to delete',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: Colors.black45)),
                      const SizedBox(height: 8),
                    ]),
                  ),
                  if (txs.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(child: Text('No transactions')),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      sliver: SliverList.builder(
                        itemCount: txs.length,
                        itemBuilder: (context, i) => _TxTile(
                          key: ValueKey(txs[i].id),
                          tx: txs[i],
                          onTap: () => _openDetails(data, txs[i]),
                          onDelete: () => _deleteWithConfirm(context, data, txs[i]),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({
    required this.balance,
    required this.onReceive,
    required this.onSend,
    required this.onCashOut,
  });

  final int balance;
  final VoidCallback onReceive, onSend, onCashOut;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [momoBlue, Color(0xFF00334A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Balance', style: TextStyle(color: Colors.white70, fontSize: 15)),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text.rich(
              key: const Key('balance'),
              TextSpan(children: [
                TextSpan(
                  text: formatRwf(balance),
                  style: const TextStyle(
                      color: Colors.white, fontSize: 42, fontWeight: FontWeight.w800),
                ),
                const TextSpan(
                  text: '  RWF',
                  style: TextStyle(color: momoYellow, fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _CardAction(icon: Icons.south_west, label: 'Receive', onTap: onReceive),
              const SizedBox(width: 8),
              _CardAction(icon: Icons.north_east, label: 'Send', onTap: onSend),
              const SizedBox(width: 8),
              _CardAction(icon: Icons.payments_outlined, label: 'Cash out', onTap: onCashOut),
            ],
          ),
        ],
      ),
    );
  }
}

class _CardAction extends StatelessWidget {
  const _CardAction({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: FilledButton.tonal(
        style: FilledButton.styleFrom(
          backgroundColor: momoYellow,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.data});
  final WalletData data;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _Stat(key: const Key('stat-in'), label: 'Total IN', value: data.totalIn, color: inGreen),
        const SizedBox(width: 8),
        _Stat(key: const Key('stat-out'), label: 'Total OUT', value: data.totalOut, color: outRed),
        const SizedBox(width: 8),
        _Stat(key: const Key('stat-low'), label: 'Lowest balance', value: data.lowestBalance, color: momoBlue),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({super.key, required this.label, required this.value, required this.color});
  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        margin: EdgeInsets.zero,
        color: Colors.white,
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: Colors.black54)),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(formatRwf(value),
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TxTile extends StatelessWidget {
  const _TxTile({
    super.key,
    required this.tx,
    required this.onTap,
    required this.onDelete,
  });

  final Transaction tx;
  final VoidCallback onTap;
  final Future<bool> Function() onDelete;

  @override
  Widget build(BuildContext context) {
    final color = colorOf(tx.type);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Dismissible(
        key: ValueKey('dismiss-${tx.id}'),
        direction: DismissDirection.endToStart,
        confirmDismiss: (_) => onDelete(),
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(color: outRed, borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.delete_outline, color: Colors.white),
        ),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          child: ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onTap: onTap,
            leading: CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.12),
              child: Icon(tx.isIn ? Icons.south_west : Icons.north_east, color: color, size: 20),
            ),
            title: Text(tx.description, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(dateLabel(tx)),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(signedRwf(tx),
                    style: TextStyle(color: color, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                TypeBadge(tx.type),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
