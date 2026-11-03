import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../providers/estadisticas_providers.dart';
import '../../widgets/scaffold_with_navigation.dart';
import 'widgets/chart_comparativo_centros.dart';
import 'widgets/chart_distribucion_categorias.dart';
import 'widgets/chart_materiales_mes.dart';
import 'widgets/chart_top_recolectores.dart';
import 'widgets/chart_usuarios_activos.dart';
import 'widgets/metricas_resumen.dart';

class EstadisticasPage extends ConsumerStatefulWidget {
  const EstadisticasPage({super.key});
  @override
  ConsumerState<EstadisticasPage> createState() => _EstadisticasPageState();
}

class _EstadisticasPageState extends ConsumerState<EstadisticasPage> {
  @override
  Widget build(BuildContext context) {
    final filters = ref.watch(estadisticasFiltrosProvider);
    return ScaffoldWithNavigation(
      title: 'Estadísticas Avanzadas',
      currentPath: '/estadisticas',
      body: Scaffold(
        appBar: AppBar(
          title: const Text('Estadísticas Avanzadas'),
          actions: [
            IconButton(
                onPressed: _exportCsv,
                icon: const Icon(Icons.download),
                tooltip: 'Exportar CSV'),
            IconButton(
                onPressed: () => _pickRange(filters),
                icon: const Icon(Icons.date_range),
                tooltip: 'Rango de fechas'),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(materialesPorMesProvider);
            ref.invalidate(distribucionCategoriasProvider);
            ref.invalidate(topRecolectoresProvider);
            ref.invalidate(usuariosActivosTendenciaProvider);
            ref.invalidate(comparativoCentrosProvider);
            ref.invalidate(metricasResumenProvider);
          },
          child: ListView(padding: const EdgeInsets.all(20), children: [
            _filters(filters),
            const SizedBox(height: 20),
            _async(ref.watch(metricasResumenProvider),
                (value) => MetricasResumenGrid(metrics: value)),
            const SizedBox(height: 20),
            _section(
                'Materiales por mes',
                _async(
                    ref.watch(materialesPorMesProvider),
                    (value) => SizedBox(
                        height: 280, child: ChartMaterialesMes(data: value)))),
            _section(
                'Distribución por categoría',
                _async(
                    ref.watch(distribucionCategoriasProvider),
                    (value) => SizedBox(
                        height: 280,
                        child: ChartDistribucionCategorias(data: value)))),
            _section(
                'Top recolectores',
                _async(
                    ref.watch(topRecolectoresProvider),
                    (value) => SizedBox(
                        height: 280,
                        child: ChartTopRecolectores(data: value)))),
            _section(
                'Usuarios activos por mes',
                _async(
                    ref.watch(usuariosActivosTendenciaProvider),
                    (value) => SizedBox(
                        height: 280,
                        child: ChartUsuariosActivos(data: value)))),
            _section(
                'Kilogramos comprometidos por centro',
                _async(
                    ref.watch(comparativoCentrosProvider),
                    (value) => SizedBox(
                        height: 280,
                        child: ChartComparativoCentros(data: value)))),
          ]),
        ),
      ),
    );
  }

  Widget _filters(EstadisticasFiltros filters) => Card(
      child: Padding(
          padding: const EdgeInsets.all(12),
          child: Wrap(spacing: 8, runSpacing: 8, children: [
            for (final preset in <({String label, Duration duration})>[
              (label: '7 días', duration: const Duration(days: 7)),
              (label: '30 días', duration: const Duration(days: 30)),
              (label: '3 meses', duration: const Duration(days: 90)),
              (label: '6 meses', duration: const Duration(days: 180)),
              (label: '1 año', duration: const Duration(days: 365))
            ])
              OutlinedButton(
                  onPressed: () => _setRange(preset.duration),
                  child: Text(preset.label)),
            DropdownButton<String>(
                value: filters.estado,
                items: const [
                  DropdownMenuItem(value: 'todos', child: Text('Todos')),
                  DropdownMenuItem(value: 'activos', child: Text('Activos')),
                  DropdownMenuItem(value: 'inactivos', child: Text('Inactivos'))
                ],
                onChanged: (value) => ref
                    .read(estadisticasFiltrosProvider.notifier)
                    .state = filters.copyWith(estado: value)),
            if (filters.desde != null)
              Chip(
                  label: Text(
                      '${_date(filters.desde!)} - ${_date(filters.hasta ?? DateTime.now())}')),
          ])));

  Widget _section(String title, Widget child) => Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            child
          ])));

  Widget _async<T>(AsyncValue<T> value, Widget Function(T) builder) =>
      value.when(
          loading: () => const SizedBox(
              height: 120, child: Center(child: CircularProgressIndicator())),
          error: (error, stack) => Padding(
              padding: const EdgeInsets.all(16),
              child: Text('No se pudieron cargar las estadísticas: $error')),
          data: builder);

  void _setRange(Duration duration) {
    final now = DateTime.now();
    ref.read(estadisticasFiltrosProvider.notifier).state = EstadisticasFiltros(
        desde: now.subtract(duration),
        hasta: now,
        estado: ref.read(estadisticasFiltrosProvider).estado);
  }

  Future<void> _pickRange(EstadisticasFiltros filters) async {
    final range = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2020),
        lastDate: DateTime.now(),
        initialDateRange: filters.desde == null
            ? null
            : DateTimeRange(
                start: filters.desde!, end: filters.hasta ?? DateTime.now()));
    if (range != null) {
      ref.read(estadisticasFiltrosProvider.notifier).state =
          EstadisticasFiltros(
              desde: range.start, hasta: range.end, estado: filters.estado);
    }
  }

  Future<void> _exportCsv() async {
    final snapshot =
        await FirebaseFirestore.instance.collection('ofertas_centro').get();
    final rows = <List<Object?>>[
      ['fecha', 'tipo', 'entidad', 'kilos', 'estado']
    ];
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final date = data['createdAt'] is num
          ? DateTime.fromMillisecondsSinceEpoch(
                  (data['createdAt'] as num).toInt())
              .toIso8601String()
          : '';
      rows.add(
          [date, 'oferta_centro', doc.id, data['pesoKg'] ?? 0, data['estado'] ?? '']);
    }
    await Share.share(const ListToCsvConverter().convert(rows),
        subject: 'ECOMAP estadísticas');
  }
}

String _date(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
