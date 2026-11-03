import '../entities/sync_records.dart';

abstract interface class SyncRepository {
  Stream<List<SyncDevice>> watchDevices();

  Stream<List<SyncRequest>> watchRequests();

  Stream<List<SyncHistoryEntry>> watchHistory();

  Future<void> forceSync({
    required String deviceId,
    required String reason,
    String? adminId,
  });

  Future<void> markDeviceSynced({
    required String deviceId,
    required String adminId,
  });
}
