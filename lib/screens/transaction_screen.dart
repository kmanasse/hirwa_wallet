import 'package:flutter/material.dart';

import '../logic/wallet_rules.dart';
import '../models/wallet_transaction.dart';
import '../theme.dart';
import '../ui/messages.dart';

class TransactionScreen extends StatefulWidget {
  const TransactionScreen({
    super.key,
    required this.transaction,
    required this.transactions,
    this.onUpdate,
  });

  final WalletTransaction transaction;
  final List<WalletTransaction> transactions;

  /// When set, Save writes the new description and amount to Firestore.
  final Future<String?> Function(String description, int amount)? onUpdate;

  @override
  State<TransactionScreen> createState() => _TransactionScreenState();
}

class _TransactionScreenState extends State<TransactionScreen> {
  late final TextEditingController _description;
  late final TextEditingController _amount;

  @override
  void initState() {
    super.initState();
    _description = TextEditingController(text: widget.transaction.description);
    _amount = TextEditingController(text: '${widget.transaction.amount}');
  }

  @override
  void dispose() {
    _description.dispose();
    _amount.dispose();
    super.dispose();
  }

  void _delete() {
    final problem = deletionProblem(widget.transactions, widget.transaction);
    if (problem != null) {
      showMessage(context, problem);
      return;
    }
    Navigator.pop(context, widget.transaction);
  }

  Future<void> _save() async {
    final amount = int.tryParse(_amount.text.trim());
    if (_description.text.trim().isEmpty) {
      showMessage(context, 'Description cannot be empty.');
      return;
    }
    if (amount == null || amount <= 0) {
      showMessage(context, 'Amount must be a whole number above 0.');
      return;
    }
    final problem = await widget.onUpdate!(_description.text, amount);
    if (!mounted) return;
    if (problem != null) {
      showMessage(context, problem);
      return;
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final transaction = widget.transaction;
    final incoming = transaction.isIncoming;
    final color = incoming ? hirwaIn : hirwaOut;
    final canEdit = widget.onUpdate != null;

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
            if (!canEdit)
              Text(
                transaction.description,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              )
            else ...[
              TextField(
                controller: _description,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _amount,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  suffixText: 'RWF',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
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
            if (canEdit) ...[
              FilledButton(onPressed: _save, child: const Text('Save')),
              const SizedBox(height: 8),
            ],
            FilledButton.icon(
              key: const Key('delete-transaction'),
              style: FilledButton.styleFrom(backgroundColor: hirwaOut),
              onPressed: _delete,
              icon: const Icon(Icons.delete_outline),
              label: const Text('Delete'),
            ),
          ],
        ),
      ),
    );
  }
}
