import 'package:cloud_firestore/cloud_firestore.dart';


import '../../domain/repositories/sync_repository.dart';

class SyncRepositoryImpl implements SyncRepository {
  SyncRepositoryImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static Map<String, dynamic> buildForcedSyncPayload({
    required String deviceId,
    required String reason,
    DateTime? updatedAt,
  }) {
    return {
      'requires_sync': true,
      'updated_by': 'admin',
      'device_id': deviceId,
      'reason': reason,
      'updated_at': updatedAt ?? DateTime.now(),
    };
  }

  @override
  Future<void> forceSync({
    required String deviceId,
    required String reason,
    String? adminId,
  }) async {
    final payload = buildForcedSyncPayload(
      deviceId: deviceId,
      reason: reason,
      updatedAt: DateTime.now(),
    );

    await _firestore
        .collection('sync_requests')
        .doc(deviceId)
        .set(payload, SetOptions(merge: true));
  }

  @override
  Future<void> markDeviceSynced({
    required String deviceId,
    required String adminId,
  }) async {
    await _firestore.collection('devices').doc(deviceId).update({
      'requires_sync': false,
      'synced_by': adminId,
      'last_sync_requested_at': FieldValue.serverTimestamp(),
    });
  }
}
