import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'firestore_entity_converters.dart';

@immutable
class RecyclingTransaction {
  const RecyclingTransaction({
    required this.id,
    required this.userId,
    required this.collectorId,
    required this.materialCategory,
    required this.weightKg,
    required this.pointsAwarded,
    required this.status,
    required this.createdAt,
    this.completedAt,
  });

  final String id;
  final String userId;
  final String collectorId;
  final String materialCategory;
  final double weightKg;
  final int pointsAwarded;
  final RecyclingTransactionStatus status;
  final DateTime createdAt;
  final DateTime? completedAt;

  factory RecyclingTransaction.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? const <String, dynamic>{};
    final statusValue = data['status'] as String?;
    final status = RecyclingTransactionStatus.values.firstWhere(
      (value) => value.name == statusValue,
      orElse: () => RecyclingTransactionStatus.pending,
    );

    return RecyclingTransaction(
      id: snapshot.id,
      userId: data['userId'] as String? ?? '',
      collectorId: data['collectorId'] as String? ?? '',
      materialCategory: data['materialCategory'] as String? ?? '',
      weightKg: readFirestoreDouble(data['weightKg']),
      pointsAwarded: readFirestoreInt(data['pointsAwarded']),
      status: status,
      createdAt: readFirestoreDateTime(data['createdAt']),
      completedAt: data['completedAt'] == null
          ? null
          : readFirestoreDateTime(data['completedAt']),
    );
  }
}

enum RecyclingTransactionStatus {
  pending,
  assigned,
  completed,
  cancelled,
}
