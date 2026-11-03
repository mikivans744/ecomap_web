
import 'package:flutter/foundation.dart';

@immutable
class SyncStatus {
  const SyncStatus({
    required this.deviceId,
    required this.status,
    required this.pendingCount,
    required this.lastSyncAt,
    this.lastError,
  });

  final String deviceId;
  final SyncStatusValue status;
  final int pendingCount;
  final DateTime lastSyncAt;
  final String? lastError;

  bool get requiresSync =>
      status == SyncStatusValue.failed || status == SyncStatusValue.pending;
}

enum SyncStatusValue {
  pending,
  syncing,
  synced,
  failed,
}
