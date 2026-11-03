import 'package:flutter/foundation.dart';

@immutable
class UserRating {
  const UserRating({
    required this.id,
    required this.ratedUserId,
    required this.fromUserId,
    required this.score,
    required this.review,
    required this.status,
    required this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String ratedUserId;
  final String fromUserId;
  final int score;
  final String review;
  final UserRatingStatus status;
  final DateTime createdAt;
  final DateTime? updatedAt;

  bool get isDisputed => status == UserRatingStatus.disputed;
}

enum UserRatingStatus {
  active,
  disputed,
  hidden,
}
