import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/wallet_transaction.dart';
import '../repositories/txn_repository.dart';
import '../utils/wallet_rules.dart' as rules;

enum TxFilter { all, incoming, outgoing }

/// The one place the transactions live. Screens watch this class.
class WalletState extends ChangeNotifier {
  WalletState(TxnRepository repo) : _repo = repo {
    _subscription = _repo!.watchAll().listen(
      (list) {
        _transactions = list;
        _loading = false;
        _error = null;
        notifyListeners();
      },
      onError: (Object error) {
        _loading = false;
        _error = 'Could not load your transactions.\n$error';
        notifyListeners();
      },
    );
  }

  /// Sample wallet on this phone, used by tests and before Firebase is connected.
  WalletState.local(List<WalletTransaction> transactions)
    : _repo = null,
      _transactions = List<WalletTransaction>.of(transactions),
      _loading = false;

  final TxnRepository? _repo;
  StreamSubscription<List<WalletTransaction>>? _subscription;

  List<WalletTransaction> _transactions = [];
  bool _loading = true;
  String? _error;
  TxFilter _filter = TxFilter.all;

  bool get isCloud => _repo != null;
  bool get loading => _loading;
  String? get error => _error;
  TxFilter get filter => _filter;

  List<WalletTransaction> get transactions => _transactions;

  rules.WalletStats get stats => rules.calculateStats(_transactions);

  int get balance => stats.balance;

  /// The list the chips show. The balance always uses every transaction.
  List<WalletTransaction> get visible {
    switch (_filter) {
      case TxFilter.all:
        return _transactions;
      case TxFilter.incoming:
        return _transactions
            .where((transaction) => transaction.isIncoming)
            .toList();
      case TxFilter.outgoing:
        return _transactions
            .where((transaction) => !transaction.isIncoming)
            .toList();
    }
  }

  void setFilter(TxFilter value) {
    _filter = value;
    notifyListeners();
  }

  Future<void> addReceive(String description, int amount) async {
    final transaction = WalletTransaction(
      description: description.trim(),
      amount: amount,
      direction: MoneyDirection.incoming,
    );
    if (_repo != null) {
      await _repo.add(transaction);
      return;
    }
    rules.addReceive(_transactions, description, amount);
    notifyListeners();
  }

  Future<void> addSend(String phone, int amount) async {
    if (_repo != null) {
      await _repo.addSend(phone, amount);
      return;
    }
    rules.addSend(_transactions, phone, amount);
    notifyListeners();
  }

  Future<void> addCashOut(int amount) async {
    final transaction = WalletTransaction(
      description: 'Cash out',
      amount: amount,
      direction: MoneyDirection.outgoing,
    );
    if (_repo != null) {
      await _repo.add(transaction);
      return;
    }
    rules.addCashOut(_transactions, amount);
    notifyListeners();
  }

  Future<String?> saveEdit(
    WalletTransaction transaction,
    String description,
    int amount,
  ) async {
    if (description.trim().isEmpty) {
      return 'Description cannot be empty.';
    }
    final amountProblem = rules.positiveAmountProblem('$amount');
    if (amountProblem != null) return amountProblem;
    final replacement = WalletTransaction(
      id: transaction.id,
      description: description.trim(),
      amount: amount,
      direction: transaction.direction,
    );
    final problem = rules.replacementProblem(
      _transactions,
      transaction,
      replacement,
    );
    if (problem != null) return problem;
    if (_repo != null) {
      await _repo.update(transaction.id, replacement);
      return null;
    }
    final index = _transactions.indexOf(transaction);
    if (index >= 0) _transactions[index] = replacement;
    notifyListeners();
    return null;
  }

  Future<void> remove(WalletTransaction transaction) async {
    if (_repo != null) {
      await _repo.delete(transaction.id);
      return;
    }
    _transactions.remove(transaction);
    notifyListeners();
  }

  void restore(int index, WalletTransaction transaction) {
    _transactions.insert(index, transaction);
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
