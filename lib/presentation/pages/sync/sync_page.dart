import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/auth/admin_auth_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../domain/entities/sync_records.dart';
import '../../providers/sync_providers.dart';
import '../../widgets/async_states.dart';
import '../../widgets/scaffold_with_navigation.dart';

class SyncPage extends ConsumerWidget {
  const SyncPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canSync = ref.watch(adminPermissionsProvider).canSync;
    if (!canSync) {
      return const ScaffoldWithNavigation(
        title: 'Sincronización',
        currentPath: '/sync',
        body: Center(child: Text('No tienes permisos para gestionar sync.')),
      );
    }

    return ScaffoldWithNavigation(
      title: 'Sincronización',
      currentPath: '/sync',
      body: DefaultTabController(
        length: 3,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Gestión de sincronización'),
            actions: [
              IconButton(
                tooltip: 'Actualizar estado',
                onPressed: () {
                  ref
                    ..invalidate(syncDevicesProvider)
                    ..invalidate(syncRequestsProvider)
                    ..invalidate(syncHistoryProvider);
                },
                icon: const Icon(Icons.refresh),
              ),
              const SizedBox(width: 8),
            ],
            bottom: const TabBar(
              isScrollable: true,
              tabs: [
                Tab(text: 'Dispositivos', icon: Icon(Icons.devices_outlined)),
                Tab(text: 'Solicitudes', icon: Icon(Icons.sync_outlined)),
                Tab(text: 'Historial', icon: Icon(Icons.history)),
              ],
            ),
          ),
          body: const TabBarView(
            children: [
              _DevicesTab(),
              _RequestsTab(),
              _HistoryTab(),
            ],
          ),
        ),
      ),
    );
  }
}

class _DevicesTab extends ConsumerWidget {
  const _DevicesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devicesAsync = ref.watch(syncDevicesProvider);
    final requestsAsync = ref.watch(syncRequestsProvider);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: devicesAsync.when(
        loading: () => const LoadingState(
          message: 'Cargando dispositivos...',
        ),
        error: (error, stackTrace) => ErrorState(
          message: 'No se pudieron cargar los datos de sincronización.',
          error: error,
          onRetry: () => ref.invalidate(syncDevicesProvider),
        ),
        data: (devices) {
          final requests = requestsAsync.valueOrNull ?? const <SyncRequest>[];
          final pendingCount =
              requests.where((request) => _isPending(request.status)).length;
          final requiresSyncCount =
              devices.where((device) => device.requiresSync).length;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _SummaryCard(
                    label: 'Dispositivos',
                    value: devices.length.toString(),
                    icon: Icons.devices_outlined,
                  ),
                  _SummaryCard(
                    label: 'Requieren sincronización',
                    value: requiresSyncCount.toString(),
                    icon: Icons.sync_problem_outlined,
                  ),
                  _SummaryCard(
                    label: 'Solicitudes pendientes',
                    value: pendingCount.toString(),
                    icon: Icons.pending_actions_outlined,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: devices.isEmpty
                    ? const EmptyState(
                        message: 'No hay dispositivos registrados.',
                      )
                    : ListView.separated(
                        key: const Key('sync_devices_list'),
                        itemCount: devices.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 8),
                        itemBuilder: (context, index) => _DeviceCard(
                          device: devices[index],
                          onForceSync: () => _forceSync(
                            context,
                            ref,
                            devices[index].id,
                          ),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _RequestsTab extends ConsumerWidget {
  const _RequestsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(syncRequestsProvider);
    return Padding(
      padding: const EdgeInsets.all(20),
      child: requestsAsync.when(
        loading: () => const LoadingState(
          message: 'Cargando solicitudes...',
        ),
        error: (error, stackTrace) => ErrorState(
          message: 'No se pudieron cargar los datos de sincronización.',
          error: error,
          onRetry: () => ref.invalidate(syncRequestsProvider),
        ),
        data: (requests) {
          final pending = requests
              .where((request) => _isPending(request.status))
              .toList(growable: false);
          if (pending.isEmpty) {
            return const EmptyState(
              message: 'No hay solicitudes de sincronización pendientes.',
            );
          }
          return ListView.separated(
            key: const Key('sync_pending_requests_list'),
            itemCount: pending.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final request = pending[index];
              return Card(
                child: ListTile(
                  key: Key('sync_request_${request.id}'),
                  leading: const CircleAvatar(
                    child: Icon(Icons.sync_outlined),
                  ),
                  title: Text('Dispositivo ${request.deviceId}'),
                  subtitle: Text(
                    '${request.reason}\n'
                    'Solicitada: ${_dateLabel(request.requestedAt)}',
                  ),
                  isThreeLine: true,
                  trailing: Text(_syncStatusLabel(request.status)),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _HistoryTab extends ConsumerWidget {
  const _HistoryTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(syncHistoryProvider);
    return Padding(
      padding: const EdgeInsets.all(20),
      child: historyAsync.when(
        loading: () => const LoadingState(
          message: 'Cargando historial...',
        ),
        error: (error, stackTrace) => ErrorState(
          message: 'No se pudieron cargar los datos de sincronización.',
          error: error,
          onRetry: () => ref.invalidate(syncHistoryProvider),
        ),
        data: (history) {
          if (history.isEmpty) {
            return const EmptyState(
              message: 'Aún no hay eventos en el historial de sync.',
            );
          }
          return ListView.separated(
            key: const Key('sync_history_list'),
            itemCount: history.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) =>
                _HistoryCard(entry: history[index]),
          );
        },
      ),
    );
  }
}

class _DeviceCard extends StatelessWidget {
  const _DeviceCard({required this.device, required this.onForceSync});

  final SyncDevice device;
  final VoidCallback onForceSync;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        key: Key('sync_device_${device.id}'),
        leading: CircleAvatar(
          backgroundColor: device.requiresSync
              ? AppColors.warning.withOpacity(0.12)
              : AppColors.surfaceVariant,
          child: Icon(
            Icons.devices_outlined,
            color: device.requiresSync ? AppColors.warning : AppColors.primary,
          ),
        ),
        title: Text(
          device.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          'ID: ${device.id}\n'
          'Usuario: ${device.ownerId} · Plataforma: ${device.platform}\n'
          'Última actividad: ${_dateLabel(device.lastSeen)} · '
          'Última sync: ${_dateLabel(device.lastSyncAt)}',
        ),
        isThreeLine: true,
        trailing: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          children: [
            _StatusChip(status: device.status),
            FilledButton.tonalIcon(
              key: Key('force_sync_${device.id}'),
              onPressed: onForceSync,
              icon: const Icon(Icons.sync),
              label: const Text('Forzar sync'),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.entry});

  final SyncHistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        key: Key('sync_history_${entry.id}'),
        leading: const CircleAvatar(child: Icon(Icons.history)),
        title: Text('Dispositivo ${entry.deviceId}'),
        subtitle: Text(
          '${entry.reason}\n'
          '${_syncStatusLabel(entry.status)} · '
          '${_dateLabel(entry.occurredAt)} · Por: ${entry.requestedBy}',
        ),
        isThreeLine: true,
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 230,
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.surfaceVariant,
                child: Icon(icon, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status.toLowerCase()) {
      'failed' || 'error' => AppColors.error,
      'pending' || 'requested' || 'syncing' => AppColors.warning,
      'synced' || 'success' || 'completed' => AppColors.success,
      _ => AppColors.textSecondary,
    };
    return Chip(
      label: Text(_syncStatusLabel(status)),
      backgroundColor: color.withOpacity(0.12),
      side: BorderSide.none,
    );
  }
}

Future<void> _forceSync(
  BuildContext context,
  WidgetRef ref,
  String deviceId,
) async {
  final reasonController = TextEditingController();
  final formKey = GlobalKey<FormState>();
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Forzar sincronización'),
      content: Form(
        key: formKey,
        child: TextFormField(
          key: const Key('sync_reason_field'),
          controller: reasonController,
          decoration: const InputDecoration(
            labelText: 'Motivo',
            hintText: 'Ej.: solicitar actualización del dispositivo',
          ),
          validator: (value) => value == null || value.trim().isEmpty
              ? 'Indica el motivo de la solicitud'
              : null,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            if (formKey.currentState?.validate() ?? false) {
              Navigator.pop(dialogContext, true);
            }
          },
          child: const Text('Enviar solicitud'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    reasonController.dispose();
    return;
  }

  try {
    final authState = await ref.read(adminAuthStateProvider.future);
    if (authState.userId.isEmpty) {
      throw StateError('No hay un administrador autenticado.');
    }
    await ref.read(syncRepositoryProvider).forceSync(
          deviceId: deviceId,
          reason: reasonController.text.trim(),
          adminId: authState.userId,
        );
    ref
      ..invalidate(syncDevicesProvider)
      ..invalidate(syncRequestsProvider)
      ..invalidate(syncHistoryProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Solicitud de sincronización enviada a $deviceId.'),
        ),
      );
    }
  } catch (error, stackTrace) {
    debugPrint(
        'No se pudo forzar la sincronización de $deviceId: $error\n$stackTrace');
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo enviar la solicitud: $error'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  } finally {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    reasonController.dispose();
  }
}

bool _isPending(String status) => const {
      'pending',
      'requested',
      'queued',
    }.contains(status.toLowerCase());

String _syncStatusLabel(String status) => switch (status.toLowerCase()) {
      'pending' || 'requested' || 'queued' => 'Pendiente',
      'syncing' || 'in_progress' => 'Sincronizando',
      'synced' || 'success' || 'completed' => 'Sincronizado',
      'failed' || 'error' => 'Fallido',
      'processed' => 'Procesado',
      _ => status,
    };

String _dateLabel(DateTime? date) =>
    date == null ? 'No disponible' : DateFormat.yMd().add_jm().format(date);
