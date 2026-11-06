import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/wallet_transaction.dart';
import '../state/wallet_state.dart';
import '../utils/theme.dart';
import '../utils/wallet_rules.dart';
import '../widgets/messages.dart';
import 'cash_out_screen.dart';
import 'rate_screen.dart';
import 'receive_screen.dart';
import 'send_screen.dart';
import 'transaction_screen.dart';

class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key, this.showCloudBanner = false});

  final bool showCloudBanner;

  Future<T?> _open<T>(BuildContext context, Widget screen) {
    final wallet = context.read<WalletState>();
    return Navigator.push<T>(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider<WalletState>.value(
          value: wallet,
          child: screen,
        ),
      ),
    );
  }

  Future<void> _openReceive(BuildContext context) async {
    final result = await _open<ReceiveRequest>(context, const ReceiveScreen());
    if (!context.mounted || result == null) return;
    await context.read<WalletState>().addReceive(
      result.description,
      result.amount,
    );
    if (!context.mounted) return;
    showMessage(context, 'Added ${formatNumber(result.amount)} RWF');
  }

  Future<void> _openSend(BuildContext context) async {
    final result = await _open<SendRequest>(context, const SendScreen());
    if (!context.mounted || result == null) return;
    await context.read<WalletState>().addSend(result.phone, result.amount);
    if (!context.mounted) return;
    showMessage(
      context,
      'Sent ${formatNumber(result.amount)} RWF to ${result.phone}',
    );
  }

  Future<void> _openCashOut(BuildContext context) async {
    final result = await _open<int>(context, const CashOutScreen());
    if (!context.mounted || result == null) return;
    await context.read<WalletState>().addCashOut(result);
    if (!context.mounted) return;
    showMessage(context, 'Cash out of ${formatNumber(result)} RWF');
  }

  Future<void> _openTransaction(
    BuildContext context,
    WalletTransaction transaction,
  ) async {
    final wallet = context.read<WalletState>();
    final removed = await _open<WalletTransaction>(
      context,
      TransactionScreen(
        transaction: transaction,
        transactions: wallet.transactions,
        onUpdate: wallet.isCloud
            ? (description, amount) =>
                  wallet.saveEdit(transaction, description, amount)
            : null,
      ),
    );
    if (!context.mounted || removed == null) return;
    await _deleteTransaction(context, removed);
  }

  Future<void> _deleteTransaction(
    BuildContext context,
    WalletTransaction transaction,
  ) async {
    final wallet = context.read<WalletState>();
    final problem = deletionProblem(wallet.transactions, transaction);
    if (problem != null) {
      showMessage(context, problem);
      return;
    }
    if (wallet.isCloud) {
      final sure = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete this transaction?'),
          content: Text(transaction.description),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
      if (sure == true) await wallet.remove(transaction);
      return;
    }

    final position = wallet.transactions.indexOf(transaction);
    await wallet.remove(transaction);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('${transaction.description} deleted'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => wallet.restore(position, transaction),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final wallet = context.watch<WalletState>();
    if (wallet.error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Hirwa'), actions: [_logoutButton()]),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(wallet.error!, textAlign: TextAlign.center),
          ),
        ),
      );
    }
    if (wallet.loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final stats = wallet.stats;
    final shown = wallet.visible;

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.account_balance_wallet_outlined, color: hirwaGold),
            SizedBox(width: 8),
            Text('Hirwa'),
          ],
        ),
        actions: [
          if (wallet.isCloud) _logoutButton(),
          IconButton(
            tooltip: 'Dollar rate',
            icon: const Icon(Icons.currency_exchange),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const RateScreen()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          if (showCloudBanner)
            const Material(
              color: Color(0xFFFFF4D6),
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  'Firebase is not connected yet, so this copy stays on this phone. Add google-services.json, then run on your phone to use accounts.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          _balanceCard(stats),
          _statsRow(stats),
          _actions(context),
          _filters(context, wallet),
          Expanded(
            child: shown.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.receipt_long_outlined,
                          size: 48,
                          color: hirwaNavy.withValues(alpha: 0.4),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _emptyMessage(wallet),
                          style: const TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 16),
                    itemCount: shown.length,
                    itemBuilder: (context, index) {
                      final transaction = shown[index];
                      return _transactionTile(context, transaction);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _logoutButton() {
    return IconButton(
      tooltip: 'Log out',
      icon: const Icon(Icons.logout),
      onPressed: () => FirebaseAuth.instance.signOut(),
    );
  }

  String _emptyMessage(WalletState wallet) {
    if (wallet.transactions.isEmpty) return 'No transactions yet';
    switch (wallet.filter) {
      case TxFilter.all:
        return 'No transactions yet';
      case TxFilter.incoming:
        return 'No money in yet';
      case TxFilter.outgoing:
        return 'No money out yet';
    }
  }

  Widget _balanceCard(WalletStats stats) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: hirwaNavy,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Balance', style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 4),
          Text(
            formatNumber(stats.balance),
            key: const Key('balance'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Text(
            'Opened at 10,000 RWF',
            style: TextStyle(color: hirwaGold),
          ),
        ],
      ),
    );
  }

  Widget _statsRow(WalletStats stats) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          _StatTile(
            label: 'Total in',
            value: formatNumber(stats.totalIn),
            color: hirwaIn,
          ),
          const SizedBox(width: 8),
          _StatTile(
            label: 'Total out',
            value: formatNumber(stats.totalOut),
            color: hirwaOut,
          ),
          const SizedBox(width: 8),
          _StatTile(
            label: 'Lowest ever',
            value: formatNumber(stats.lowest),
            color: hirwaNavy,
          ),
        ],
      ),
    );
  }

  Widget _actions(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        children: [
          _ActionButton(
            buttonKey: const Key('open-receive'),
            icon: Icons.call_received,
            label: 'Receive',
            onTap: () => _openReceive(context),
          ),
          _ActionButton(
            buttonKey: const Key('open-send'),
            icon: Icons.send,
            label: 'Send',
            onTap: () => _openSend(context),
          ),
          _ActionButton(
            buttonKey: const Key('open-cash-out'),
            icon: Icons.payments_outlined,
            label: 'Cash out',
            onTap: () => _openCashOut(context),
          ),
        ],
      ),
    );
  }

  Widget _filters(BuildContext context, WalletState wallet) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ChoiceChip(
                label: const Text('All'),
                selected: wallet.filter == TxFilter.all,
                selectedColor: hirwaGold,
                onSelected: (_) =>
                    context.read<WalletState>().setFilter(TxFilter.all),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('IN'),
                selected: wallet.filter == TxFilter.incoming,
                selectedColor: hirwaGold,
                onSelected: (_) =>
                    context.read<WalletState>().setFilter(TxFilter.incoming),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('OUT'),
                selected: wallet.filter == TxFilter.outgoing,
                selectedColor: hirwaGold,
                onSelected: (_) =>
                    context.read<WalletState>().setFilter(TxFilter.outgoing),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Tap for details. Hold to delete.',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _transactionTile(BuildContext context, WalletTransaction transaction) {
    final color = transaction.isIncoming ? hirwaIn : hirwaOut;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        onTap: () => _openTransaction(context, transaction),
        onLongPress: () => _deleteTransaction(context, transaction),
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.12),
          child: Icon(
            transaction.isIncoming ? Icons.arrow_downward : Icons.arrow_upward,
            color: color,
          ),
        ),
        title: Text(transaction.description),
        subtitle: Text(
          transaction.isIncoming ? 'IN' : 'OUT',
          style: TextStyle(color: color, fontWeight: FontWeight.w700),
        ),
        trailing: Text(
          signedNumber(transaction),
          style: TextStyle(color: color, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.buttonKey,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final Key buttonKey;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            key: buttonKey,
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                children: [
                  Icon(icon, color: hirwaNavy),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
