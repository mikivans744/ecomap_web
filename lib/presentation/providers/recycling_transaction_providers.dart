import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/recycling_transaction.dart';
import 'firestore_provider.dart';

final recyclingTransactionsProvider =
    StreamProvider<List<RecyclingTransaction>>((ref) {
  return ref
      .watch(firestoreProvider)
      .collection('transactions')
      .snapshots()
      .map((snapshot) {
    final transactions = snapshot.docs
        .map(RecyclingTransaction.fromFirestore)
        .toList()
      ..sort((first, second) => second.createdAt.compareTo(first.createdAt));
    return transactions;
  });
});
