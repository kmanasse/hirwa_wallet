import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../logic/wallet_rules.dart';
import '../models/wallet_transaction.dart';
import '../theme.dart';
import '../ui/messages.dart';
import '../wallet_store.dart';
import 'cash_out_screen.dart';
import 'rate_screen.dart';
import 'receive_screen.dart';
import 'send_screen.dart';
import 'transaction_screen.dart';

enum TxFilter { all, incoming, outgoing }

class WalletScreen extends StatefulWidget {
  const WalletScreen({
    super.key,
    this.initialTransactions,
    this.showCloudBanner = false,
  });

  /// When set, the screen keeps this list on the phone. Tests use it.
  /// When null, the list comes live from Firestore.
  final List<WalletTransaction>? initialTransactions;
  final bool showCloudBanner;

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  List<WalletTransaction> _transactions = [];
  List<WalletTransaction> _view = [];
  TxFilter _filter = TxFilter.all;

  bool get _live => widget.initialTransactions == null;

  @override
  void initState() {
    super.initState();
    if (!_live) {
      _transactions = List<WalletTransaction>.of(widget.initialTransactions!);
    }
  }

  void _change(void Function() update) {
    setState(update);
  }

  List<WalletTransaction> _shown() {
    switch (_filter) {
      case TxFilter.all:
        return _view;
      case TxFilter.incoming:
        return _view.where((transaction) => transaction.isIncoming).toList();
      case TxFilter.outgoing:
        return _view.where((transaction) => !transaction.isIncoming).toList();
    }
  }

  String _emptyMessage() {
    switch (_filter) {
      case TxFilter.all:
        return 'No transactions yet';
      case TxFilter.incoming:
        return 'No money in yet';
      case TxFilter.outgoing:
        return 'No money out yet';
    }
  }

  Future<void> _openReceive(int balance) async {
    final result = await Navigator.push<ReceiveRequest>(
      context,
      MaterialPageRoute(builder: (context) => ReceiveScreen(balance: balance)),
    );
    if (!mounted || result == null) return;
    if (_live) {
      await addWalletTransaction(
        WalletTransaction(
          description: result.description,
          amount: result.amount,
          direction: MoneyDirection.incoming,
        ),
      );
    } else {
      _change(
        () => addReceive(_transactions, result.description, result.amount),
      );
    }
    if (!mounted) return;
    showMessage(context, 'Added ${formatNumber(result.amount)} RWF');
  }

  Future<void> _openSend(int balance) async {
    final result = await Navigator.push<SendRequest>(
      context,
      MaterialPageRoute(builder: (context) => SendScreen(balance: balance)),
    );
    if (!mounted || result == null) return;
    if (_live) {
      await addSendToCloud(result.phone, result.amount);
    } else {
      _change(() => addSend(_transactions, result.phone, result.amount));
    }
    if (!mounted) return;
    showMessage(
      context,
      'Sent ${formatNumber(result.amount)} RWF to ${result.phone}',
    );
  }

  Future<void> _openCashOut(int balance) async {
    final result = await Navigator.push<int>(
      context,
      MaterialPageRoute(builder: (context) => CashOutScreen(balance: balance)),
    );
    if (!mounted || result == null) return;
    if (_live) {
      await addWalletTransaction(
        WalletTransaction(
          description: 'Cash out',
          amount: result,
          direction: MoneyDirection.outgoing,
        ),
      );
    } else {
      _change(() => addCashOut(_transactions, result));
    }
    if (!mounted) return;
    showMessage(context, 'Cash out of ${formatNumber(result)} RWF');
  }

  Future<void> _openTransaction(WalletTransaction transaction) async {
    final removed = await Navigator.push<WalletTransaction>(
      context,
      MaterialPageRoute(
        builder: (context) => TransactionScreen(
          transaction: transaction,
          transactions: _view,
          onUpdate: _live
              ? (description, amount) =>
                    _saveEdit(transaction, description, amount)
              : null,
        ),
      ),
    );
    if (!mounted || removed == null) return;
    _deleteTransaction(removed);
  }

  Future<String?> _saveEdit(
    WalletTransaction transaction,
    String description,
    int amount,
  ) async {
    if (description.trim().isEmpty) {
      return 'Description cannot be empty.';
    }
    final amountProblem = positiveAmountProblem('$amount');
    if (amountProblem != null) return amountProblem;
    final replacement = WalletTransaction(
      id: transaction.id,
      description: description.trim(),
      amount: amount,
      direction: transaction.direction,
    );
    final problem = replacementProblem(_view, transaction, replacement);
    if (problem != null) return problem;
    await updateWalletTransaction(replacement);
    return null;
  }

  void _deleteTransaction(WalletTransaction transaction) {
    final problem = deletionProblem(_view, transaction);
    if (problem != null) {
      showMessage(context, problem);
      return;
    }
    if (_live) {
      _deleteLive(transaction);
      return;
    }

    final position = _transactions.indexOf(transaction);
    _change(() => _transactions.remove(transaction));

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('${transaction.description} deleted'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () {
              _change(() => _transactions.insert(position, transaction));
            },
          ),
        ),
      );
  }

  Future<void> _deleteLive(WalletTransaction transaction) async {
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
    if (sure == true) {
      await myTransactions().doc(transaction.id).delete();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_live) {
      return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: myTransactions()
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _messagePage(
              'Could not load your transactions.\n${snapshot.error}',
            );
          }
          if (!snapshot.hasData) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          _view = snapshot.data!.docs.map(transactionFromDoc).toList();
          return _page();
        },
      );
    }
    _view = _transactions;
    return _page();
  }

  Widget _messagePage(String message) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hirwa'), actions: [_logoutButton()]),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(message, textAlign: TextAlign.center),
        ),
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

  Widget _page() {
    final stats = calculateStats(_view);
    final shown = _shown();

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
          if (_live) _logoutButton(),
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
          if (widget.showCloudBanner)
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
          _actions(stats.balance),
          _filters(),
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
                          _emptyMessage(),
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
                      return _transactionTile(transaction);
                    },
                  ),
          ),
        ],
      ),
    );
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

  Widget _actions(int balance) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        children: [
          _ActionButton(
            buttonKey: const Key('open-receive'),
            icon: Icons.call_received,
            label: 'Receive',
            onTap: () => _openReceive(balance),
          ),
          _ActionButton(
            buttonKey: const Key('open-send'),
            icon: Icons.send,
            label: 'Send',
            onTap: () => _openSend(balance),
          ),
          _ActionButton(
            buttonKey: const Key('open-cash-out'),
            icon: Icons.payments_outlined,
            label: 'Cash out',
            onTap: () => _openCashOut(balance),
          ),
        ],
      ),
    );
  }

  Widget _filters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ChoiceChip(
                label: const Text('All'),
                selected: _filter == TxFilter.all,
                selectedColor: hirwaGold,
                onSelected: (_) => setState(() => _filter = TxFilter.all),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('IN'),
                selected: _filter == TxFilter.incoming,
                selectedColor: hirwaGold,
                onSelected: (_) => setState(() => _filter = TxFilter.incoming),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('OUT'),
                selected: _filter == TxFilter.outgoing,
                selectedColor: hirwaGold,
                onSelected: (_) => setState(() => _filter = TxFilter.outgoing),
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

  Widget _transactionTile(WalletTransaction transaction) {
    final color = transaction.isIncoming ? hirwaIn : hirwaOut;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        onTap: () => _openTransaction(transaction),
        onLongPress: () => _deleteTransaction(transaction),
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border(left: BorderSide(color: color, width: 4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
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
