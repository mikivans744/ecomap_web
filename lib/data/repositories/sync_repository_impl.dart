import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/sync_records.dart';
import '../../domain/repositories/sync_repository.dart';

class SyncRepositoryImpl implements SyncRepository {
  SyncRepositoryImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  @override
  Stream<List<SyncDevice>> watchDevices() =>
      _firestore.collection('devices').snapshots().map((snapshot) {
        final devices = snapshot.docs.map(SyncDevice.fromDocument).toList();
        devices.sort((first, second) => first.name.compareTo(second.name));
        return devices;
      });

  @override
  Stream<List<SyncRequest>> watchRequests() =>
      _firestore.collection('sync_requests').snapshots().map((snapshot) {
        final requests = snapshot.docs.map(SyncRequest.fromDocument).toList();
        requests.sort(
          (first, second) => (second.requestedAt ?? DateTime(1970))
              .compareTo(first.requestedAt ?? DateTime(1970)),
        );
        return requests;
      });

  @override
  Stream<List<SyncHistoryEntry>> watchHistory() =>
      _firestore.collection('sync').snapshots().map((snapshot) {
        final history =
            snapshot.docs.map(SyncHistoryEntry.fromDocument).toList();
        history.sort(
          (first, second) => (second.occurredAt ?? DateTime(1970))
              .compareTo(first.occurredAt ?? DateTime(1970)),
        );
        return history;
      });

  static Map<String, dynamic> buildForcedSyncPayload({
    required String deviceId,
    required String reason,
    DateTime? updatedAt,
  }) {
    return {
      'requiresSync': true,
      'updatedBy': 'admin',
      'deviceId': deviceId,
      'reason': reason,
      'updatedAt': updatedAt ?? DateTime.now(),
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

    final batch = _firestore.batch();
    batch.set(
      _firestore.collection('sync_requests').doc(deviceId),
      payload,
      SetOptions(merge: true),
    );
    batch.set(_firestore.collection('sync').doc(), {
      ...payload,
      'requestedBy': adminId ?? 'admin',
      'status': 'requested',
      'requestedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  @override
  Future<void> markDeviceSynced({
    required String deviceId,
    required String adminId,
  }) async {
    await _firestore.collection('devices').doc(deviceId).update({
      'requiresSync': false,
      'syncedBy': adminId,
      'lastSyncRequestedAt': FieldValue.serverTimestamp(),
    });
  }
}
