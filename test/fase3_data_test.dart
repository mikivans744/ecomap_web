import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:ecomap_web/data/datasources/local/admin_cache.dart';
import 'package:ecomap_web/data/datasources/local/audit_log_cache.dart';
import 'package:ecomap_web/data/models/sync_status_model.dart';
import 'package:ecomap_web/data/repositories/sync_repository_impl.dart';
import 'package:ecomap_web/domain/entities/sync_status.dart';

void main() {
  setUpAll(() async {
    final tempDir = await Directory.systemTemp.createTemp('ecomap_hive_test');
    Hive.init(tempDir.path);
    await Hive.openBox<dynamic>(AdminCache.boxName);
    await Hive.openBox<dynamic>(AuditLogCache.boxName);
  });

  tearDown(() async {
    await Hive.box(AdminCache.boxName).clear();
    await Hive.box(AuditLogCache.boxName).clear();
  });

  group('forced synchronization contract', () {
    test('produces camelCase sync fields for clients', () {
      final payload = SyncRepositoryImpl.buildForcedSyncPayload(
        deviceId: 'device-123',
        reason: 'Admin requested synchronization',
      );

      expect(payload['requiresSync'], isTrue);
      expect(payload['updatedBy'], 'admin');
      expect(payload['deviceId'], 'device-123');
      expect(payload['reason'], 'Admin requested synchronization');
      expect(payload['updatedAt'], isA<DateTime>());
    });

    test('serializes sync status with camelCase Firestore fields', () {
      final timestamp = Timestamp.fromDate(DateTime.utc(2026, 10, 6));
      final model = SyncStatusModel.fromMap({
        'deviceId': 'device-123',
        'status': 'synced',
        'pendingCount': 0,
        'lastSyncAt': timestamp,
        'lastError': null,
      });

      final serialized = model.toMap();

      expect(
          serialized.keys,
          containsAll([
            'deviceId',
            'status',
            'pendingCount',
            'lastSyncAt',
            'lastError',
          ]));
      expect(
        serialized.keys,
        isNot(contains(anyOf(
          'device_id',
          'pending_count',
          'last_sync_at',
          'last_error',
        ))),
      );
      expect(serialized['lastSyncAt'], timestamp);
    });

    test('maps Firestore sync status into the domain entity', () {
      final model = SyncStatusModel(
        deviceId: 'device-123',
        status: 'synced',
        pendingCount: 0,
        lastSyncAt: DateTime.utc(2026, 10, 6),
        lastError: null,
      );

      final domain = model.toEntity();

      expect(domain.deviceId, 'device-123');
      expect(domain.status, SyncStatusValue.synced);
      expect(domain.requiresSync, isFalse);
    });
  });

  group('local caches', () {
    test('stores and retrieves administrator settings', () async {
      final cache = AdminCache();

      await cache.save('themeMode', 'dark');
      final value = cache.read<String>('themeMode');

      expect(value, 'dark');
    });

    test('records audit entries in a bounded list', () async {
      final auditLog = AuditLogCache();
      final entry = AuditLogEntry(
        id: 'audit-1',
        action: 'force_sync',
        performedBy: 'admin-1',
        timestamp: DateTime.utc(2026, 10, 6, 8),
        details: const {'deviceId': 'device-123'},
      );

      await auditLog.add(entry, limit: 2);
      final entries = await auditLog.readAll();

      expect(entries, hasLength(1));
      expect(entries.single.action, 'force_sync');
    });
  });
}
