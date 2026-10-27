import '../models/wallet_transaction.dart';

const int openingBalance = 10000;
const int sendFee = 100;
const int minimumSend = 100;
const List<int> agentNotes = [5000, 2000, 1000, 500, 100];

class NoteCount {
  const NoteCount(this.value, this.count);

  final int value;
  final int count;
}

class WalletStats {
  const WalletStats({
    required this.balance,
    required this.totalIn,
    required this.totalOut,
    required this.lowest,
  });

  final int balance;
  final int totalIn;
  final int totalOut;
  final int lowest;
}

String formatNumber(int amount) {
  final negative = amount < 0;
  final digits = amount.abs().toString();
  final out = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    final fromRight = digits.length - i;
    if (i > 0 && fromRight % 3 == 0) out.write(',');
    out.write(digits[i]);
  }
  return negative ? '-$out' : out.toString();
}

String signedNumber(WalletTransaction transaction) {
  final sign = transaction.isIncoming ? '+' : '-';
  return '$sign${formatNumber(transaction.amount)}';
}

String notesSummary(List<NoteCount> notes) {
  return notes
      .map((note) => '${formatNumber(note.value)} × ${note.count}')
      .join(' · ');
}

/// Walk the history from the opening balance. Newest-first lists are reversed
/// so the oldest transaction is applied first.
WalletStats calculateStats(List<WalletTransaction> newestFirst) {
  var balance = openingBalance;
  // Start at the opening balance, not 0. Zero would look like the lowest
  // even when the wallet never reached it.
  var lowest = openingBalance;
  var totalIn = 0;
  var totalOut = 0;

  for (final transaction in newestFirst.reversed) {
    if (transaction.isIncoming) {
      balance += transaction.amount;
      totalIn += transaction.amount;
    } else {
      balance -= transaction.amount;
      totalOut += transaction.amount;
    }
    if (balance < lowest) lowest = balance;
  }

  return WalletStats(
    balance: balance,
    totalIn: totalIn,
    totalOut: totalOut,
    lowest: lowest,
  );
}

String? phoneProblem(String text) {
  final phone = text.trim();
  if (!RegExp(r'^\d{10}$').hasMatch(phone)) {
    return 'Phone number must be exactly 10 digits.';
  }
  if (!phone.startsWith('078') && !phone.startsWith('079')) {
    return 'Phone number must start with 078 or 079.';
  }
  return null;
}

String? positiveAmountProblem(String text) {
  final amount = int.tryParse(text.trim());
  if (amount == null) {
    return 'Enter a whole number. 5k is not allowed.';
  }
  if (amount <= 0) {
    return 'Amount must be a whole number above 0.';
  }
  return null;
}

String? receiveProblem({
  required String description,
  required String amountText,
}) {
  if (description.trim().isEmpty) {
    return 'Description cannot be empty.';
  }
  return positiveAmountProblem(amountText);
}

String? sendProblem({
  required String phone,
  required String amountText,
  required int balance,
}) {
  final phoneError = phoneProblem(phone);
  if (phoneError != null) return phoneError;

  final amountError = positiveAmountProblem(amountText);
  if (amountError != null) return amountError;

  final amount = int.parse(amountText.trim());
  if (amount < minimumSend) {
    return 'Amount must be at least 100 RWF.';
  }
  if (amount + sendFee > balance) {
    return 'Insufficient balance. A send also takes a 100 RWF fee.';
  }
  return null;
}

/// Notes can be shown once the amount itself is legal, even if the balance
/// cannot cover it yet. Confirm still refuses an unaffordable cash out.
String? cashOutAmountProblem(String amountText) {
  final amountError = positiveAmountProblem(amountText);
  if (amountError != null) return amountError;

  final amount = int.parse(amountText.trim());
  if (amount % 100 != 0) {
    return 'Amount must be a multiple of 100.';
  }
  return null;
}

String? cashOutProblem({required String amountText, required int balance}) {
  final amountError = cashOutAmountProblem(amountText);
  if (amountError != null) return amountError;

  final amount = int.parse(amountText.trim());
  if (amount > balance) return 'Insufficient balance';
  return null;
}

List<NoteCount> notesFor(int amount) {
  var left = amount;
  final lines = <NoteCount>[];
  for (final note in agentNotes) {
    final count = left ~/ note;
    if (count > 0) {
      lines.add(NoteCount(note, count));
      left -= count * note;
    }
  }
  return lines;
}

/// Fee is recorded just after the send, so it is the newer of the two OUTs.
void addSend(List<WalletTransaction> newestFirst, String phone, int amount) {
  newestFirst.insert(
    0,
    WalletTransaction(
      description: 'Sent to ${phone.trim()}',
      amount: amount,
      direction: MoneyDirection.outgoing,
    ),
  );
  newestFirst.insert(
    0,
    const WalletTransaction(
      description: 'Send fee',
      amount: sendFee,
      direction: MoneyDirection.outgoing,
    ),
  );
}

void addCashOut(List<WalletTransaction> newestFirst, int amount) {
  newestFirst.insert(
    0,
    WalletTransaction(
      description: 'Cash out',
      amount: amount,
      direction: MoneyDirection.outgoing,
    ),
  );
}

void addReceive(
  List<WalletTransaction> newestFirst,
  String description,
  int amount,
) {
  newestFirst.insert(
    0,
    WalletTransaction(
      description: description.trim(),
      amount: amount,
      direction: MoneyDirection.incoming,
    ),
  );
}

/// Replay history without [target]. Refuse if any moment would go below 0.
String? deletionProblem(
  List<WalletTransaction> newestFirst,
  WalletTransaction target,
) {
  var balance = openingBalance;
  for (final transaction in newestFirst.reversed) {
    if (identical(transaction, target)) continue;
    if (transaction.isIncoming) {
      balance += transaction.amount;
    } else {
      balance -= transaction.amount;
    }
    if (balance < 0) {
      return 'Cannot delete this. The balance would go below 0.';
    }
  }
  return null;
}
