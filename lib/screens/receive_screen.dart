import 'package:flutter/material.dart';

import '../logic/wallet_rules.dart';
import '../theme.dart';
import '../ui/balance_banner.dart';
import '../ui/messages.dart';

class ReceiveRequest {
  const ReceiveRequest({required this.description, required this.amount});

  final String description;
  final int amount;
}

class ReceiveScreen extends StatefulWidget {
  const ReceiveScreen({super.key, required this.balance});

  final int balance;

  @override
  State<ReceiveScreen> createState() => _ReceiveScreenState();
}

class _ReceiveScreenState extends State<ReceiveScreen> {
  final _description = TextEditingController();
  final _amount = TextEditingController();

  @override
  void dispose() {
    _description.dispose();
    _amount.dispose();
    super.dispose();
  }

  String? _liveProblem() {
    final description = _description.text.trim();
    final amountText = _amount.text.trim();
    if (description.isEmpty && amountText.isEmpty) return null;
    if (description.isEmpty) return 'Description cannot be empty.';
    if (amountText.isEmpty) return null;
    return receiveProblem(description: description, amountText: amountText);
  }

  void _submit() {
    final problem = receiveProblem(
      description: _description.text,
      amountText: _amount.text,
    );
    if (problem != null) {
      showMessage(context, problem);
      return;
    }

    Navigator.pop(
      context,
      ReceiveRequest(
        description: _description.text.trim(),
        amount: int.parse(_amount.text.trim()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final problem = _liveProblem();

    return Scaffold(
      appBar: AppBar(title: const Text('Receive money')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BalanceBanner(balance: widget.balance),
            const SizedBox(height: 16),
            const Text(
              'This adds an IN. The amount must be a whole number above 0, and the description cannot be empty.',
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('receive-description'),
              controller: _description,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.next,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'Payment from Keza',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.notes_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('receive-amount'),
              controller: _amount,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _submit(),
              decoration: const InputDecoration(
                labelText: 'Amount',
                hintText: '2000',
                suffixText: 'RWF',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.payments_outlined),
              ),
            ),
            const SizedBox(height: 12),
            if (problem != null)
              Text(
                problem,
                style: const TextStyle(
                  color: hirwaOut,
                  fontWeight: FontWeight.w600,
                ),
              ),
            const SizedBox(height: 20),
            FilledButton.icon(
              key: const Key('submit-receive'),
              onPressed: _submit,
              icon: const Icon(Icons.call_received),
              label: const Text('Add money'),
            ),
          ],
        ),
      ),
    );
  }
}
