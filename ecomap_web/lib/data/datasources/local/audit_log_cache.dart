import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

class AuditLogCache {
  AuditLogCache({Box<dynamic>? box}) : _box = box ?? Hive.box(_boxName);

  static const String boxName = 'audit_logs';
  static const String _boxName = boxName;

  final Box<dynamic> _box;

  Future<void> add(AuditLogEntry entry, {int limit = 100}) async {
    final current = await readAll();
    final updatedLog = <AuditLogEntry>[entry, ...current];
    final limited = updatedLog.take(limit).toList(growable: false);

    await _box.put(entry.id, entry.toMap());
    final keys =
        _box.keys.where((key) => key != entry.id).toList(growable: false);

    for (final key in keys) {
      final value = _box.get(key);
      if (value is Map) {
        final map = Map<String, dynamic>.from(value);
        final auditEntry = AuditLogEntry.fromMap(map);
        if (!limited.any((item) => item.id == auditEntry.id)) {
          await _box.delete(key);
        }
      }
    }
  }

  Future<List<AuditLogEntry>> readAll() async {
    final entries = <AuditLogEntry>[];
    for (final key in _box.keys) {
      final value = _box.get(key);
      if (value is Map) {
        entries.add(AuditLogEntry.fromMap(Map<String, dynamic>.from(value)));
      }
    }
    return entries;
  }
}

@immutable
class AuditLogEntry {
  const AuditLogEntry({
    required this.id,
    required this.action,
    required this.performedBy,
    required this.timestamp,
    required this.details,
  });

  final String id;
  final String action;
  final String performedBy;
  final DateTime timestamp;
  final Map<String, dynamic> details;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'action': action,
      'performedBy': performedBy,
      'timestamp': timestamp.toIso8601String(),
      'details': details,
    };
  }

  factory AuditLogEntry.fromMap(Map<String, dynamic> map) {
    return AuditLogEntry(
      id: map['id'] as String,
      action: map['action'] as String,
      performedBy: map['performedBy'] as String,
      timestamp: DateTime.parse(map['timestamp'] as String),
      details: Map<String, dynamic>.from(map['details'] as Map? ?? const {}),
    );
  }
}
