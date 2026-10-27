import 'package:flutter/material.dart';

import '../logic/wallet_rules.dart';
import '../models/wallet_transaction.dart';
import '../theme.dart';
import '../ui/messages.dart';

class TransactionScreen extends StatelessWidget {
  const TransactionScreen({
    super.key,
    required this.transaction,
    required this.transactions,
  });

  final WalletTransaction transaction;
  final List<WalletTransaction> transactions;

  void _delete(BuildContext context) {
    final problem = deletionProblem(transactions, transaction);
    if (problem != null) {
      showMessage(context, problem);
      return;
    }
    Navigator.pop(context, transaction);
  }

  @override
  Widget build(BuildContext context) {
    final incoming = transaction.isIncoming;
    final color = incoming ? hirwaIn : hirwaOut;

    return Scaffold(
      appBar: AppBar(title: const Text('Transaction')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),
            Icon(
              incoming ? Icons.arrow_downward : Icons.arrow_upward,
              size: 48,
              color: color,
            ),
            const SizedBox(height: 16),
            Text(
              transaction.description,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              '${signedNumber(transaction)} RWF',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: color,
                fontSize: 32,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              incoming ? 'IN' : 'OUT',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Deleting recalculates the balance from the opening 10,000 RWF. If the history would go below 0, the delete is refused.',
              textAlign: TextAlign.center,
            ),
            const Spacer(),
            FilledButton.icon(
              key: const Key('delete-transaction'),
              style: FilledButton.styleFrom(backgroundColor: hirwaOut),
              onPressed: () => _delete(context),
              icon: const Icon(Icons.delete_outline),
              label: const Text('Delete'),
            ),
          ],
        ),
      ),
    );
  }
}
