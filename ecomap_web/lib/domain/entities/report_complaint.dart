
import 'package:flutter/foundation.dart';

@immutable
class ReportComplaint {
  const ReportComplaint({
    required this.id,
    required this.reporterId,
    required this.reportedUserId,
    required this.category,
    required this.description,
    required this.status,
    required this.createdAt,
    this.decidedAt,
    this.adminNote,
  });

  final String id;
  final String reporterId;
  final String reportedUserId;
  final String category;
  final String description;
  final ReportComplaintStatus status;
  final DateTime createdAt;
  final DateTime? decidedAt;
  final String? adminNote;

  bool get isBlocked => status == ReportComplaintStatus.blocked;
}

enum ReportComplaintStatus {
  pending,
  underReview,
  actionTaken,
  blocked,
  dismissed,
}
