enum MoneyDirection { incoming, outgoing }

class WalletTransaction {
  const WalletTransaction({
    this.id = '',
    required this.description,
    required this.amount,
    required this.direction,
  });

  final String id;
  final String description;
  final int amount;
  final MoneyDirection direction;

  Map<String, dynamic> toMap() => {
    'description': description,
    'amount': amount,
    'direction': direction.name,
  };

  bool get isIncoming => direction == MoneyDirection.incoming;

  Map<String, dynamic> toJson() => {
    'description': description,
    'amount': amount,
    'direction': direction.name,
  };

  factory WalletTransaction.fromJson(Map<String, dynamic> json) {
    return WalletTransaction(
      description: json['description'] as String,
      amount: (json['amount'] as num).toInt(),
      direction: MoneyDirection.values.byName(json['direction'] as String),
    );
  }
}

/// Newest first. The wallet opened at 10,000 RWF, then these happened:
/// cash out 3,000 → payment from Keza 8,000 → send 4,000 → fee 100 →
/// cash out 5,900 → allowance 5,000.
/// The balance is back at 10,000. The lowest along the way is 5,000.
List<WalletTransaction> sampleTransactions() {
  return [
    WalletTransaction(
      description: 'Allowance from home',
      amount: 5000,
      direction: MoneyDirection.incoming,
    ),
    WalletTransaction(
      description: 'Cash out',
      amount: 5900,
      direction: MoneyDirection.outgoing,
    ),
    WalletTransaction(
      description: 'Send fee',
      amount: 100,
      direction: MoneyDirection.outgoing,
    ),
    WalletTransaction(
      description: 'Sent to 0788123456',
      amount: 4000,
      direction: MoneyDirection.outgoing,
    ),
    WalletTransaction(
      description: 'Payment from Keza',
      amount: 8000,
      direction: MoneyDirection.incoming,
    ),
    WalletTransaction(
      description: 'Cash out',
      amount: 3000,
      direction: MoneyDirection.outgoing,
    ),
  ];
}
