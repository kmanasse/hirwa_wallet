import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'logic/wallet_rules.dart';
import 'models/wallet_transaction.dart';

/// users/{uid}/transactions — the path the security rules protect.
CollectionReference<Map<String, dynamic>> myTransactions() {
  final uid = FirebaseAuth.instance.currentUser!.uid;
  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('transactions');
}

WalletTransaction transactionFromDoc(
  DocumentSnapshot<Map<String, dynamic>> doc,
) {
  final data = doc.data()!;
  return WalletTransaction(
    id: doc.id,
    description: data['description'] as String,
    amount: (data['amount'] as num).toInt(),
    direction: MoneyDirection.values.byName(data['direction'] as String),
  );
}

Future<void> addWalletTransaction(WalletTransaction transaction) {
  return myTransactions().add({
    ...transaction.toMap(),
    'createdAt': FieldValue.serverTimestamp(),
  });
}

Future<void> updateWalletTransaction(WalletTransaction transaction) {
  return myTransactions().doc(transaction.id).update(transaction.toMap());
}

/// Written once, when a new account is created.
Future<void> addSampleTransactions() async {
  final oldestFirst = sampleTransactions().reversed.toList();
  final start = DateTime.now().subtract(Duration(minutes: oldestFirst.length));
  final batch = FirebaseFirestore.instance.batch();
  for (var i = 0; i < oldestFirst.length; i++) {
    batch.set(myTransactions().doc(), {
      ...oldestFirst[i].toMap(),
      'createdAt': Timestamp.fromDate(start.add(Duration(minutes: i))),
    });
  }
  await batch.commit();
}

Future<void> addSendToCloud(String phone, int amount) async {
  final now = DateTime.now();
  final batch = FirebaseFirestore.instance.batch();
  batch.set(myTransactions().doc(), {
    'description': 'Send fee',
    'amount': sendFee,
    'direction': MoneyDirection.outgoing.name,
    'createdAt': Timestamp.fromDate(now),
  });
  batch.set(myTransactions().doc(), {
    'description': 'Sent to ${phone.trim()}',
    'amount': amount,
    'direction': MoneyDirection.outgoing.name,
    'createdAt': Timestamp.fromDate(now.add(const Duration(seconds: 1))),
  });
  await batch.commit();
}
