import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/admin_auth_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../providers/audit_providers.dart';
import '../../providers/firestore_provider.dart';
import '../../widgets/async_states.dart';
import '../../widgets/scaffold_with_navigation.dart';

class ModerationReport {
  const ModerationReport({required this.id, required this.data});
  final String id;
  final Map<String, dynamic> data;
  String get type => data['tipo'] as String? ?? 'otro';
  String get status => data['estado'] as String? ?? 'pendiente';
  String get description => data['descripcion'] as String? ?? '';
  String get reportedBy => data['reportadoPor'] as String? ?? '';
  String get reportedId => data['reportadoId'] as String? ?? '';
  DateTime get date => _readDate(data['fecha'] ?? data['createdAt']);
}

typedef ModerationReportUpdater = Future<void> Function({
  required ModerationReport report,
  required String status,
  required String note,
});

final moderationReportUpdaterProvider = Provider<ModerationReportUpdater>(
  (ref) => ({
    required report,
    required status,
    required note,
  }) async {
    final before = <String, dynamic>{
      'estado': report.status,
      if (report.data.containsKey('notaAdministrador'))
        'notaAdministrador': report.data['notaAdministrador'],
    };
    final after = <String, dynamic>{
      'estado': status,
      'notaAdministrador': note,
      'resueltoPor': 'admin',
    };
    await ref
        .read(firestoreProvider)
        .collection('reports')
        .doc(report.id)
        .update({
      ...after,
      'resueltoEn': FieldValue.serverTimestamp(),
    });
    await ref.read(auditServiceProvider).log(
          action: status == 'resuelto' ? 'report_resolved' : 'report_discarded',
          entityType: 'report',
          entityId: report.id,
          before: before,
          after: after,
        );
  },
);

final moderationReportsProvider =
    StreamProvider.family<List<ModerationReport>, String>((ref, status) {
  Query<Map<String, dynamic>> query =
      ref.watch(firestoreProvider).collection('reports');
  if (status != 'todos') query = query.where('estado', isEqualTo: status);
  return query.snapshots().map((s) => s.docs
      .map((d) => ModerationReport(id: d.id, data: d.data()))
      .toList(growable: false));
});

final allModerationReportsProvider = StreamProvider<List<ModerationReport>>(
    (ref) => ref.watch(firestoreProvider).collection('reports').snapshots().map(
        (s) => s.docs
            .map((d) => ModerationReport(id: d.id, data: d.data()))
            .toList(growable: false)));

class ModeracionPage extends ConsumerStatefulWidget {
  const ModeracionPage({super.key});
  @override
  ConsumerState<ModeracionPage> createState() => _ModeracionPageState();
}

class _ModeracionPageState extends ConsumerState<ModeracionPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  static const statuses = ['pendiente', 'resuelto', 'descartado'];
  var tab = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final permissions = ref.watch(adminPermissionsProvider);
    if (!permissions.viewReports) {
      return const ScaffoldWithNavigation(
        title: 'Moderación y Reportes',
        currentPath: '/moderacion',
        body: Center(child: Text('Sin permisos')),
      );
    }
    final canModerate = permissions.canModerate;
    final reports = ref.watch(moderationReportsProvider(statuses[tab]));
    return ScaffoldWithNavigation(
      title: 'Moderación y Reportes',
      currentPath: '/moderacion',
      body: Scaffold(
        appBar: AppBar(
          title: const Text('Moderación y Reportes'),
          bottom: TabBar(
            controller: _tabController,
            onTap: (index) => setState(() => tab = index),
            tabs: const [
              Tab(text: 'Pendientes'),
              Tab(text: 'Resueltos'),
              Tab(text: 'Descartados')
            ],
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(children: [
            _Stats(reports: ref.watch(allModerationReportsProvider)),
            const SizedBox(height: 16),
            Expanded(
                child: reports.when(
              loading: () => const LoadingState(
                message: 'Cargando reportes...',
              ),
              error: (error, stack) => _error(error),
              data: (items) => items.isEmpty
                  ? const EmptyState(
                      message: 'No hay reportes en esta categoría.',
                    )
                  : ListView.separated(
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (_, index) => _ReportCard(
                        report: items[index],
                        onDetails: () => _details(items[index]),
                        onResolve: canModerate
                            ? () => _changeStatus(items[index], 'resuelto')
                            : null,
                        onDiscard: canModerate
                            ? () => _changeStatus(items[index], 'descartado')
                            : null,
                        onSuspend:
                            canModerate ? () => _suspend(items[index]) : null,
                      ),
                    ),
            )),
          ]),
        ),
      ),
    );
  }

  Widget _error(Object error) => ErrorState(
        message: 'No se pudieron cargar los reportes.',
        error: error,
        onRetry: () => ref.invalidate(moderationReportsProvider(statuses[tab])),
      );

  Future<void> _changeStatus(ModerationReport report, String status) async {
    if (!_requireModerationPermission()) return;

    final note = await showDialog<String>(
      context: context,
      builder: (context) => _ModerationNoteDialog(status: status),
    );
    if (note == null) return;
    if (!_requireModerationPermission()) return;
    try {
      await ref.read(moderationReportUpdaterProvider)(
        report: report,
        status: status,
        note: note,
      );
      _message('Reporte actualizado.');
    } catch (error) {
      _message('No se pudo actualizar el reporte: $error', error: true);
    }
  }

  Future<void> _suspend(ModerationReport report) async {
    if (!_requireModerationPermission()) return;
    if (report.reportedId.isEmpty) return;
    final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('Suspender usuario'),
              content: const Text('Se desactivará el usuario reportado.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancelar')),
                FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Suspender'))
              ],
            ));
    if (ok != true) return;
    if (!_requireModerationPermission()) return;
    try {
      final userReference =
          FirebaseFirestore.instance.collection('usuarios').doc(report.reportedId);
      final userSnapshot = await userReference.get();
      if (!userSnapshot.exists) {
        _message('No existe el usuario reportado.', error: true);
        return;
      }
      final before = {
        'activo': userSnapshot.data()?['activo'] != false,
      };
      final after = {
        'activo': false,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      };
      await userReference.update(after);
      await ref.read(auditServiceProvider).log(
            action: 'user_suspended',
            entityType: 'user',
            entityId: report.reportedId,
            before: before,
            after: after,
          );
      _message('Usuario suspendido.');
    } catch (error) {
      _message('No se pudo suspender el usuario: $error', error: true);
    }
  }

  void _details(ModerationReport report) => showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
            title: Text('Reporte ${report.type}'),
            content: Text(
                '${report.description}\n\nReportado por: ${report.reportedBy}\nEntidad: ${report.reportedId}\nFecha: ${_date(report.date)}'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cerrar'))
            ],
          ));

  bool _requireModerationPermission() {
    if (ref.read(adminPermissionsProvider).canModerate) return true;
    _message('Sin permisos', error: true);
    return false;
  }

  void _message(String text, {bool error = false}) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(text),
          backgroundColor: error ? AppColors.error : null));
}

class _ModerationNoteDialog extends StatefulWidget {
  const _ModerationNoteDialog({required this.status});

  final String status;

  @override
  State<_ModerationNoteDialog> createState() => _ModerationNoteDialogState();
}

class _ModerationNoteDialogState extends State<_ModerationNoteDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.status == 'resuelto'
            ? 'Resolver reporte'
            : 'Descartar reporte'),
        content: TextField(
          key: const Key('moderation_note_field'),
          controller: _controller,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Nota del administrador',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, _controller.text.trim()),
            child: const Text('Guardar'),
          ),
        ],
      );
}

class _ReportCard extends StatelessWidget {
  const _ReportCard(
      {required this.report,
      required this.onDetails,
      required this.onResolve,
      required this.onDiscard,
      required this.onSuspend});
  final ModerationReport report;
  final VoidCallback onDetails;
  final VoidCallback? onResolve;
  final VoidCallback? onDiscard;
  final VoidCallback? onSuspend;
  @override
  Widget build(BuildContext context) => Card(
      child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                  child: Text(report.type.toUpperCase(),
                      style: const TextStyle(fontWeight: FontWeight.bold))),
              Chip(label: Text(report.status))
            ]),
            Text(report.description,
                maxLines: 2, overflow: TextOverflow.ellipsis),
            Text('Reportado por: ${report.reportedBy}'),
            Text(_date(report.date),
                style: Theme.of(context).textTheme.bodySmall),
            const Divider(),
            Wrap(spacing: 8, runSpacing: 8, children: [
              OutlinedButton.icon(
                  onPressed: onDetails,
                  icon: const Icon(Icons.visibility_outlined),
                  label: const Text('Ver detalle')),
              if (report.status == 'pendiente') ...[
                if (onResolve != null)
                  FilledButton.icon(
                      onPressed: onResolve,
                      icon: const Icon(Icons.check),
                      label: const Text('Resolver')),
                if (onDiscard != null)
                  OutlinedButton.icon(
                      onPressed: onDiscard,
                      icon: const Icon(Icons.close),
                      label: const Text('Descartar')),
                if (onSuspend != null)
                  OutlinedButton.icon(
                      onPressed: onSuspend,
                      icon: const Icon(Icons.person_off_outlined),
                      label: const Text('Suspender usuario')),
              ],
            ]),
          ])));
}

class _Stats extends StatelessWidget {
  const _Stats({required this.reports});
  final AsyncValue<List<ModerationReport>> reports;
  @override
  Widget build(BuildContext context) => reports.when(
        loading: () => const LinearProgressIndicator(),
        error: (_, __) => const SizedBox.shrink(),
        data: (items) {
          final pending = items.where((r) => r.status == 'pendiente').length;
          final resolved = items.where((r) => r.status == 'resuelto').length;
          return Wrap(spacing: 10, children: [
            Chip(label: Text('Total: ${items.length}')),
            Chip(label: Text('Pendientes: $pending')),
            Chip(label: Text('Resueltos: $resolved'))
          ]);
        },
      );
}

DateTime _readDate(dynamic value) => value is Timestamp
    ? value.toDate()
    : DateTime.tryParse('$value') ?? DateTime.now();
String _date(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
