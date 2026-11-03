import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../domain/entities/sync_status.dart';

@immutable
class SyncStatusModel {
  const SyncStatusModel({
    required this.deviceId,
    required this.status,
    required this.pendingCount,
    required this.lastSyncAt,
    this.lastError,
  });

  final String deviceId;
  final String status;
  final int pendingCount;
  final DateTime lastSyncAt;
  final String? lastError;

  factory SyncStatusModel.fromMap(Map<String, dynamic> map) {
    final lastSyncAt = map['lastSyncAt'];

    return SyncStatusModel(
      deviceId: map['deviceId'] as String? ?? '',
      status: map['status'] as String? ?? SyncStatusValue.pending.name,
      pendingCount: map['pendingCount'] as int? ?? 0,
      lastSyncAt:
          lastSyncAt is Timestamp ? lastSyncAt.toDate() : DateTime.now(),
      lastError: map['lastError'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'deviceId': deviceId,
      'status': status,
      'pendingCount': pendingCount,
      'lastSyncAt': Timestamp.fromDate(lastSyncAt),
      'lastError': lastError,
    };
  }

  SyncStatus toEntity() {
    return SyncStatus(
      deviceId: deviceId,
      status: SyncStatusValue.values.firstWhere(
        (value) => value.name == status,
        orElse: () => SyncStatusValue.pending,
      ),
      pendingCount: pendingCount,
      lastSyncAt: lastSyncAt,
      lastError: lastError,
    );
  }
}
