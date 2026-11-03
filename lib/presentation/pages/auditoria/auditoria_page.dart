import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/auth/admin_auth_provider.dart';
import '../../../core/auth/admin_auth_state.dart';
import '../../widgets/scaffold_with_navigation.dart';

class AuditoriaPage extends ConsumerWidget {
  const AuditoriaPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      const ScaffoldWithNavigation(
        title: 'Auditoría y Logs',
        currentPath: '/auditoria',
        showHeader: true,
        body: _AuditoriaContent(),
      );
}

class _AuditoriaContent extends ConsumerStatefulWidget {
  const _AuditoriaContent();

  @override
  ConsumerState<_AuditoriaContent> createState() => _AuditoriaContentState();
}

class _AuditoriaContentState extends ConsumerState<_AuditoriaContent> {
  final _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> _logs = [];
  bool _isLoading = true;
  bool _hasRequestedLogs = false;
  String _filterAction = 'all';
  String _searchQuery = '';

  Future<void> _loadLogs() async {
    try {
      Query<Map<String, dynamic>> query = _firestore.collection('audit_logs');
      if (_filterAction != 'all') {
        query = query.where('action', isEqualTo: _filterAction);
      }
      final snapshot =
          await query.orderBy('performedAt', descending: true).limit(100).get();
      if (!mounted) return;
      setState(() {
        _logs = snapshot.docs.map((doc) => doc.data()).toList();
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Sin permisos: $error')));
    }
  }

  List<Map<String, dynamic>> get _filteredLogs {
    final query = _searchQuery.trim().toLowerCase();
    return query.isEmpty
        ? _logs
        : _logs
            .where((log) => (log['entityId'] as String? ?? '')
                .toLowerCase()
                .contains(query))
            .toList();
  }

  Color _actionColor(String action) => switch (action) {
        'create' ||
        'user_created' ||
        'recolector_created' ||
        'centro_created' =>
          Colors.green,
        'update' ||
        'user_updated' ||
        'recolector_updated' ||
        'centro_updated' =>
          Colors.blue,
        'delete' || 'publication_deleted' || 'report_discarded' => Colors.red,
        'toggle' ||
        'user_blocked' ||
        'recolector_blocked' ||
        'centro_deactivated' =>
          Colors.orange,
        _ => Colors.grey,
      };

  String _formatTimestamp(Object? value) => value is Timestamp
      ? DateFormat('dd/MM/yyyy HH:mm').format(value.toDate())
      : 'N/A';

  @override
  Widget build(BuildContext context) {
    final permissions = ref.watch(adminPermissionsProvider);
    ref.listen<AdminPermissions>(
      adminPermissionsProvider,
      (previous, next) {
        if (next.canViewAudit && previous?.canViewAudit != true) {
          _hasRequestedLogs = true;
          _loadLogs();
        }
      },
    );
    if (!permissions.canViewAudit) {
      return const Center(child: Text('Sin permisos'));
    }
    if (!_hasRequestedLogs) {
      _hasRequestedLogs = true;
      Future<void>.microtask(_loadLogs);
    }
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
                child: TextField(
                    decoration: const InputDecoration(
                        labelText: 'Buscar por Entity ID',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.search)),
                    onChanged: (value) =>
                        setState(() => _searchQuery = value))),
            const SizedBox(width: 16),
            DropdownButton<String>(
                value: _filterAction,
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('Todas')),
                  DropdownMenuItem(value: 'create', child: Text('Crear')),
                  DropdownMenuItem(value: 'update', child: Text('Actualizar')),
                  DropdownMenuItem(value: 'delete', child: Text('Eliminar')),
                  DropdownMenuItem(value: 'toggle', child: Text('Toggle')),
                  DropdownMenuItem(
                      value: 'user_blocked', child: Text('Usuario bloqueado')),
                  DropdownMenuItem(
                      value: 'role_changed', child: Text('Rol cambiado')),
                  DropdownMenuItem(
                      value: 'report_resolved',
                      child: Text('Reporte resuelto')),
                  DropdownMenuItem(
                      value: 'report_discarded',
                      child: Text('Reporte descartado')),
                  DropdownMenuItem(
                      value: 'user_suspended',
                      child: Text('Usuario suspendido')),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _filterAction = value;
                    _isLoading = true;
                  });
                  _loadLogs();
                }),
          ]),
          const SizedBox(height: 24),
          Expanded(
              child: _filteredLogs.isEmpty
                  ? const Center(child: Text('No hay logs de auditoría'))
                  : ListView.builder(
                      itemCount: _filteredLogs.length,
                      itemBuilder: (context, index) {
                        final log = _filteredLogs[index];
                        final action = log['action'] as String? ?? 'unknown';
                        return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              leading: Icon(Icons.history,
                                  color: _actionColor(action)),
                              title: Text(
                                  '$action - ${log['entityType'] as String? ?? 'N/A'}'),
                              subtitle: Text(
                                  'Entity ID: ${log['entityId'] as String? ?? 'N/A'}\nPor: ${log['adminId'] as String? ?? log['performedBy'] as String? ?? 'N/A'}\nFecha: ${_formatTimestamp(log['timestamp'] ?? log['performedAt'])}'),
                              onTap: () => _showLogDetail(log),
                            ));
                      })),
        ]));
  }

  void _showLogDetail(Map<String, dynamic> log) => showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
            title: const Text('Detalle del Log'),
            content: SingleChildScrollView(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                  Text('Acción: ${log['action'] ?? 'N/A'}'),
                  const SizedBox(height: 8),
                  Text('Tipo de Entidad: ${log['entityType'] ?? 'N/A'}'),
                  const SizedBox(height: 8),
                  Text('Entity ID: ${log['entityId'] ?? 'N/A'}'),
                  const SizedBox(height: 8),
                  Text(
                      'Realizado por: ${log['adminId'] ?? log['performedBy'] ?? 'N/A'}'),
                  const SizedBox(height: 8),
                  Text(
                      'Fecha: ${_formatTimestamp(log['timestamp'] ?? log['performedAt'])}'),
                  const SizedBox(height: 16),
                  const Text('Datos Anteriores:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  Text((log['before'] ?? log['previousData'])?.toString() ??
                      'N/A'),
                  const SizedBox(height: 16),
                  const Text('Datos Nuevos:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  Text((log['after'] ?? log['newData'])?.toString() ?? 'N/A'),
                ])),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cerrar'))
            ],
          ));
}
