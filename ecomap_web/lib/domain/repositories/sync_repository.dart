abstract interface class SyncRepository {
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
