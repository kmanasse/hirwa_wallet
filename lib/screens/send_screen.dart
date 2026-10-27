import 'package:flutter/material.dart';

import '../logic/wallet_rules.dart';
import '../theme.dart';
import '../ui/balance_banner.dart';
import '../ui/messages.dart';

class SendRequest {
  const SendRequest({required this.phone, required this.amount});

  final String phone;
  final int amount;
}

class SendScreen extends StatefulWidget {
  const SendScreen({super.key, required this.balance});

  final int balance;

  @override
  State<SendScreen> createState() => _SendScreenState();
}

class _SendScreenState extends State<SendScreen> {
  final _phone = TextEditingController();
  final _amount = TextEditingController();

  @override
  void dispose() {
    _phone.dispose();
    _amount.dispose();
    super.dispose();
  }

  String? _liveProblem() {
    final phone = _phone.text.trim();
    final amountText = _amount.text.trim();
    if (phone.isEmpty && amountText.isEmpty) return null;
    if (phone.isEmpty) return 'Phone number must be exactly 10 digits.';
    final phoneError = phoneProblem(phone);
    if (phoneError != null) return phoneError;
    if (amountText.isEmpty) return null;
    return sendProblem(
      phone: phone,
      amountText: amountText,
      balance: widget.balance,
    );
  }

  void _submit() {
    final problem = sendProblem(
      phone: _phone.text,
      amountText: _amount.text,
      balance: widget.balance,
    );
    if (problem != null) {
      showMessage(context, problem);
      return;
    }

    Navigator.pop(
      context,
      SendRequest(
        phone: _phone.text.trim(),
        amount: int.parse(_amount.text.trim()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final problem = _liveProblem();

    return Scaffold(
      appBar: AppBar(title: const Text('Send money')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BalanceBanner(balance: widget.balance),
            const SizedBox(height: 16),
            const Text(
              'A phone number is 10 digits and starts with 078 or 079. The smallest send is 100 RWF. Hirwa adds a 100 RWF fee as its own OUT.',
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('send-phone'),
              controller: _phone,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Phone number',
                hintText: '0788123456',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.phone_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('send-amount'),
              controller: _amount,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _submit(),
              decoration: const InputDecoration(
                labelText: 'Amount',
                hintText: '1000',
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
              )
            else if (_phone.text.trim().isNotEmpty &&
                _amount.text.trim().isNotEmpty)
              const Text(
                'Ready. The fee will be saved as a separate OUT.',
                style: TextStyle(color: hirwaIn, fontWeight: FontWeight.w600),
              ),
            const SizedBox(height: 20),
            FilledButton.icon(
              key: const Key('submit-send'),
              onPressed: _submit,
              icon: const Icon(Icons.send),
              label: const Text('Send'),
            ),
          ],
        ),
      ),
    );
  }
}
