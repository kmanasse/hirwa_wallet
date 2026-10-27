import 'package:flutter/material.dart';

import '../logic/wallet_rules.dart';
import '../theme.dart';

class BalanceBanner extends StatelessWidget {
  const BalanceBanner({super.key, required this.balance});

  final int balance;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: hirwaNavy,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Balance', style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 4),
          Text(
            '${formatNumber(balance)} RWF',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
