import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/recycling_transaction.dart';
import 'firestore_provider.dart';

final recyclingTransactionsProvider =
    StreamProvider<List<RecyclingTransaction>>((ref) {
  final firestore = ref.watch(firestoreProvider);
  final controller = StreamController<List<RecyclingTransaction>>();
  List<RecyclingTransaction> transactions = const [];
  List<RecyclingTransaction> deliveredOffers = const [];
  var transactionSnapshotReady = false;
  var offerSnapshotReady = false;

  void emitIfReady() {
    if (!transactionSnapshotReady || !offerSnapshotReady) return;
    final combined = [...transactions, ...deliveredOffers]
      ..sort((first, second) => second.createdAt.compareTo(first.createdAt));
    controller.add(combined);
  }

  final transactionSubscription =
      firestore.collection('transactions').snapshots().listen((snapshot) {
    transactions = snapshot.docs
        .map(RecyclingTransaction.fromFirestore)
        .toList(growable: false);
    transactionSnapshotReady = true;
    emitIfReady();
  }, onError: (Object error, StackTrace stackTrace) {
    controller.addError(error, stackTrace);
  });
  final offersSubscription = firestore
      .collection('ofertas_centro')
      .where('estado', isEqualTo: 'ENTREGADA')
      .snapshots()
      .listen((snapshot) {
    deliveredOffers = snapshot.docs
        .where((document) => document.data()['weightConfirmed'] is num)
        .map(RecyclingTransaction.fromCenterOffer)
        .toList(growable: false);
    offerSnapshotReady = true;
    emitIfReady();
  }, onError: (Object error, StackTrace stackTrace) {
    controller.addError(error, stackTrace);
  });

  ref.onDispose(() async {
    await transactionSubscription.cancel();
    await offersSubscription.cancel();
    await controller.close();
  });
  return controller.stream;
});
