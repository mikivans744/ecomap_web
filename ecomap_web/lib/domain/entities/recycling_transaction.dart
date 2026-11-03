
import 'package:flutter/foundation.dart';

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
}

enum RecyclingTransactionStatus {
  pending,
  assigned,
  completed,
  cancelled,
}
