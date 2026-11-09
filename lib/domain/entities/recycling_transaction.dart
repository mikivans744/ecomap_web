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
    this.centerId = '',
    this.signatureUrl,
    this.isCenterOffer = false,
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
  final String centerId;
  final String? signatureUrl;
  final bool isCenterOffer;

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
      centerId:
          data['centerId'] as String? ?? data['centroId'] as String? ?? '',
      signatureUrl:
          data['signatureUrl'] as String? ?? data['firmaUrl'] as String?,
    );
  }

  factory RecyclingTransaction.fromCenterOffer(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? const <String, dynamic>{};
    final createdAtValue = data['createdAt'];
    final updatedAtValue = data['updatedAt'];
    final createdAt = readFirestoreDateTime(createdAtValue);
    final effectiveDate = createdAt.millisecondsSinceEpoch == 0
        ? readFirestoreDateTime(updatedAtValue)
        : createdAt;
    final weightConfirmed = data['weightConfirmed'];
    final weight = weightConfirmed is num ? weightConfirmed.toDouble() : 0.0;
    return RecyclingTransaction(
      id: 'oferta_${snapshot.id}',
      userId: '',
      collectorId: data['recolectorId'] as String? ?? '',
      materialCategory:
          data['categoria'] as String? ?? data['categoriaId'] as String? ?? '',
      weightKg: weight,
      pointsAwarded: weight.round(),
      status: RecyclingTransactionStatus.completed,
      createdAt: effectiveDate,
      completedAt: data['finalizedAt'] == null
          ? null
          : readFirestoreDateTime(data['finalizedAt']),
      centerId:
          data['centroId'] as String? ?? data['centerId'] as String? ?? '',
      signatureUrl:
          data['signatureUrl'] as String? ?? data['firmaUrl'] as String?,
      isCenterOffer: true,
    );
  }
}

enum RecyclingTransactionStatus {
  pending,
  assigned,
  completed,
  cancelled,
}
