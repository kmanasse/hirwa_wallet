import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/wallet_transaction.dart';
import '../utils/wallet_rules.dart';

/// The only class that talks to Firestore.
/// One repository belongs to one signed-in user.
class TxnRepository {
  TxnRepository(this.uid);

  final String uid;

  CollectionReference<Map<String, dynamic>> get _transactions =>
      FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('transactions');

  Stream<List<WalletTransaction>> watchAll() => _transactions
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snapshot) => snapshot.docs.map(WalletTransaction.fromDoc).toList());

  Future<void> add(WalletTransaction transaction) => _transactions.add({
    ...transaction.toMap(),
    'createdAt': FieldValue.serverTimestamp(),
  });

  Future<void> update(String id, WalletTransaction transaction) =>
      _transactions.doc(id).update(transaction.toMap());

  Future<void> delete(String id) => _transactions.doc(id).delete();

  /// Fee first, then the payment one second later, so newest-first stays right.
  Future<void> addSend(String phone, int amount) async {
    final now = DateTime.now();
    final batch = FirebaseFirestore.instance.batch();
    batch.set(_transactions.doc(), {
      'description': 'Send fee',
      'amount': sendFee,
      'direction': MoneyDirection.outgoing.name,
      'createdAt': Timestamp.fromDate(now),
    });
    batch.set(_transactions.doc(), {
      'description': 'Sent to ${phone.trim()}',
      'amount': amount,
      'direction': MoneyDirection.outgoing.name,
      'createdAt': Timestamp.fromDate(now.add(const Duration(seconds: 1))),
    });
    await batch.commit();
  }

  /// Written once, when a new account is created.
  Future<void> addSamples() async {
    final oldestFirst = sampleTransactions().reversed.toList();
    final start = DateTime.now().subtract(
      Duration(minutes: oldestFirst.length),
    );
    final batch = FirebaseFirestore.instance.batch();
    for (var i = 0; i < oldestFirst.length; i++) {
      batch.set(_transactions.doc(), {
        ...oldestFirst[i].toMap(),
        'createdAt': Timestamp.fromDate(start.add(Duration(minutes: i))),
      });
    }
    await batch.commit();
  }
}
