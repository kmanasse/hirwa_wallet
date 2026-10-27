import 'package:flutter/material.dart';

import '../logic/wallet_rules.dart';
import '../theme.dart';
import '../ui/balance_banner.dart';
import '../ui/messages.dart';

class CashOutScreen extends StatefulWidget {
  const CashOutScreen({super.key, required this.balance});

  final int balance;

  @override
  State<CashOutScreen> createState() => _CashOutScreenState();
}

class _CashOutScreenState extends State<CashOutScreen> {
  final _amount = TextEditingController();

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  void _submit() {
    final problem = cashOutProblem(
      amountText: _amount.text,
      balance: widget.balance,
    );
    if (problem != null) {
      showMessage(context, problem);
      return;
    }

    Navigator.pop(context, int.parse(_amount.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    final text = _amount.text.trim();
    final amountProblem = text.isEmpty ? null : cashOutAmountProblem(text);
    final amount = int.tryParse(text);
    final notes = amountProblem == null && amount != null
        ? notesFor(amount)
        : null;

    return Scaffold(
      appBar: AppBar(title: const Text('Cash out')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BalanceBanner(balance: widget.balance),
            const SizedBox(height: 16),
            const Text(
              'The agent has notes of 5,000, 2,000, 1,000, 500 and 100 RWF. The amount must be a multiple of 100.',
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('cash-amount'),
              controller: _amount,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _submit(),
              decoration: const InputDecoration(
                labelText: 'Amount',
                hintText: '23700',
                suffixText: 'RWF',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.payments_outlined),
              ),
            ),
            const SizedBox(height: 16),
            if (text.isEmpty)
              const Text('Enter an amount to see the notes, biggest first.')
            else if (amountProblem != null)
              Text(
                amountProblem,
                style: const TextStyle(
                  color: hirwaOut,
                  fontWeight: FontWeight.w600,
                ),
              )
            else if (notes != null) ...[
              const Text(
                'Notes you will get',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 24,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    notesSummary(notes),
                    key: const Key('notes-summary'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              for (final note in notes)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.payments_outlined,
                    color: hirwaNavy,
                  ),
                  title: Text('${formatNumber(note.value)} RWF'),
                  trailing: Text(
                    '× ${note.count}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              if (amount! > widget.balance)
                const Text(
                  'Insufficient balance',
                  style: TextStyle(
                    color: hirwaOut,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
            const SizedBox(height: 20),
            FilledButton.icon(
              key: const Key('confirm-cash-out'),
              onPressed: _submit,
              icon: const Icon(Icons.check),
              label: const Text('Confirm'),
            ),
          ],
        ),
      ),
    );
  }
}
