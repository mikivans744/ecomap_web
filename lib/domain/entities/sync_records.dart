import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

@immutable
class SyncDevice {
  const SyncDevice({required this.id, required this.data});

  final String id;
  final Map<String, dynamic> data;

  String get name =>
      _readString(data, ['deviceName', 'name', 'deviceModel', 'model'], id);
  String get ownerId =>
      _readString(data, ['ownerId', 'userId', 'uid'], 'No especificado');
  String get platform =>
      _readString(data, ['platform', 'deviceType', 'os'], 'No especificada');
  String get status {
    final explicitStatus = _readString(data, ['status', 'syncStatus'], '');
    if (explicitStatus.isNotEmpty) return explicitStatus.toLowerCase();
    return data['requiresSync'] == true ? 'pending' : 'synced';
  }

  bool get requiresSync =>
      data['requiresSync'] == true || status == 'pending' || status == 'failed';
  DateTime? get lastSeen => _readDate(data['lastSeen']);
  DateTime? get lastSyncAt => _readDate(data['lastSyncAt'] ?? data['syncedAt']);

  factory SyncDevice.fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) =>
      SyncDevice(id: document.id, data: document.data());
}

@immutable
class SyncRequest {
  const SyncRequest({required this.id, required this.data});

  final String id;
  final Map<String, dynamic> data;

  String get deviceId => _readString(data, ['deviceId'], id);
  String get status => data['requiresSync'] == true
      ? 'pending'
      : _readString(data, ['status', 'state'], 'pending').toLowerCase();
  String get reason => _readString(data, ['reason'], 'Sin motivo indicado');
  DateTime? get requestedAt => _readDate(
        data['requestedAt'] ?? data['updatedAt'] ?? data['createdAt'],
      );

  factory SyncRequest.fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) =>
      SyncRequest(id: document.id, data: document.data());
}

@immutable
class SyncHistoryEntry {
  const SyncHistoryEntry({required this.id, required this.data});

  final String id;
  final Map<String, dynamic> data;

  String get deviceId => _readString(data, ['deviceId'], 'Dispositivo');
  String get reason => _readString(data, ['reason'], 'Sin detalle');
  String get requestedBy =>
      _readString(data, ['requestedBy', 'updatedBy'], 'Sistema');
  String get status =>
      _readString(data, ['status', 'event'], 'Solicitud enviada');
  DateTime? get occurredAt => _readDate(
        data['requestedAt'] ?? data['createdAt'] ?? data['updatedAt'],
      );

  factory SyncHistoryEntry.fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) =>
      SyncHistoryEntry(id: document.id, data: document.data());
}

String _readString(
  Map<String, dynamic> data,
  List<String> keys,
  String fallback,
) {
  for (final key in keys) {
    final value = data[key];
    if (value is String && value.trim().isNotEmpty) return value.trim();
  }
  return fallback;
}

DateTime? _readDate(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}
