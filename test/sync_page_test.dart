import 'package:ecomap_web/core/auth/admin_auth_provider.dart';
import 'package:ecomap_web/core/auth/admin_auth_state.dart';
import 'package:ecomap_web/domain/entities/sync_records.dart';
import 'package:ecomap_web/domain/repositories/sync_repository.dart';
import 'package:ecomap_web/presentation/pages/sync/sync_page.dart';
import 'package:ecomap_web/presentation/providers/sync_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows devices, pending requests, history, and forces sync',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _FakeSyncRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          adminPermissionsProvider.overrideWithValue(const AdminPermissions()),
          adminAuthStateProvider.overrideWith(
            (ref) => Stream.value(
              const AdminAuthState(
                userId: 'admin-1',
                email: 'admin@example.test',
                isAdmin: true,
              ),
            ),
          ),
          syncRepositoryProvider.overrideWithValue(repository),
          syncDevicesProvider.overrideWith((ref) => repository.watchDevices()),
          syncRequestsProvider.overrideWith(
            (ref) => repository.watchRequests(),
          ),
          syncHistoryProvider.overrideWith((ref) => repository.watchHistory()),
        ],
        child: const MaterialApp(home: SyncPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tablet de prueba'), findsOneWidget);
    expect(find.text('Requieren sincronización'), findsOneWidget);
    await tester.tap(find.byKey(const Key('force_sync_device-1')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('sync_reason_field')),
      'Solicitado por soporte',
    );
    await tester.tap(find.text('Enviar solicitud'));
    await tester.pumpAndSettle();
    expect(repository.forcedDeviceId, 'device-1');
    expect(repository.forcedReason, 'Solicitado por soporte');
    expect(repository.forcedAdminId, 'admin-1');

    await tester.tap(find.text('Solicitudes'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('sync_pending_requests_list')), findsOneWidget);
    expect(find.textContaining('Reintentar actualización'), findsOneWidget);

    await tester.tap(find.text('Historial'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('sync_history_list')), findsOneWidget);
    expect(find.textContaining('Solicitado por soporte'), findsOneWidget);
  });
}

class _FakeSyncRepository implements SyncRepository {
  String? forcedDeviceId;
  String? forcedReason;
  String? forcedAdminId;

  @override
  Stream<List<SyncDevice>> watchDevices() => Stream.value([
        const SyncDevice(
          id: 'device-1',
          data: {
            'deviceName': 'Tablet de prueba',
            'ownerId': 'user-1',
            'platform': 'android',
            'requiresSync': true,
          },
        ),
      ]);

  @override
  Stream<List<SyncRequest>> watchRequests() => Stream.value([
        const SyncRequest(
          id: 'device-1',
          data: {
            'deviceId': 'device-1',
            'status': 'pending',
            'reason': 'Reintentar actualización',
          },
        ),
      ]);

  @override
  Stream<List<SyncHistoryEntry>> watchHistory() => Stream.value([
        const SyncHistoryEntry(
          id: 'history-1',
          data: {
            'deviceId': 'device-1',
            'reason': 'Solicitado por soporte',
            'requestedBy': 'admin-1',
            'status': 'requested',
          },
        ),
      ]);

  @override
  Future<void> forceSync({
    required String deviceId,
    required String reason,
    String? adminId,
  }) async {
    forcedDeviceId = deviceId;
    forcedReason = reason;
    forcedAdminId = adminId;
  }

  @override
  Future<void> markDeviceSynced({
    required String deviceId,
    required String adminId,
  }) async {}
}
