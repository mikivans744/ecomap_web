import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/constants/route_names.dart';
import '../../../domain/entities/centro_acopio_entity.dart';
import '../../../domain/entities/oferta_entity.dart';
import '../../../domain/entities/recolector_entity.dart';
import '../../../domain/entities/recycling_transaction.dart';
import '../../../domain/entities/user_entity.dart';
import '../../../domain/repositories/oferta_repository.dart';
import '../../providers/centro_acopio_providers.dart';
import '../../providers/oferta_providers.dart';
import '../../providers/material_category_provider.dart';
import '../../providers/recolector_providers.dart';
import '../../providers/recycling_transaction_providers.dart';
import '../../providers/user_providers.dart';
import '../../widgets/async_states.dart';
import '../../widgets/category_catalog_notice.dart';
import '../../widgets/scaffold_with_navigation.dart';
import 'widgets/recycling_transaction_detail_dialog.dart';

const Map<String, double> _co2Factors = {
  'PLASTICO': 1.5,
  'METAL': 4.0,
  'VIDRIO': 0.3,
  'PAPEL_CARTON': 0.9,
  'ELECTRONICO': 2.0,
  'TEXTIL': 3.0,
  'OTRO': 0.5,
};

class ReciclajePage extends ConsumerStatefulWidget {
  const ReciclajePage({super.key});

  @override
  ConsumerState<ReciclajePage> createState() => _ReciclajePageState();
}

class _ReciclajePageState extends ConsumerState<ReciclajePage> {
  static const String _all = 'todos';

  String _material = _all;
  String _userId = _all;
  String _collectorId = _all;
  String _centerId = _all;
  DateTimeRange? _dateRange;

  @override
  Widget build(BuildContext context) {
    final transactionsAsync = ref.watch(recyclingTransactionsProvider);
    final requestPointsAsync = ref.watch(completedRequestPointsProvider);
    final offersAsync = ref.watch(ofertasProvider((
      estado: null,
      centroId: null,
      recolectorId: null,
      desde: null,
      hasta: null,
    )));
    final usersAsync = ref.watch(
      usersProvider((zona: null, estadoActivo: null)),
    );
    final collectorsAsync = ref.watch(
      recolectoresProvider((zona: null, estadoActivo: null)),
    );
    final centersAsync = ref.watch(
      centrosAcopioProvider((zona: null, estadoActivo: null)),
    );
    final offerRepository = ref.watch(ofertaRepositoryProvider);
    final categoryCatalog =
        ref.watch(materialCategoryCatalogProvider).valueOrNull ??
            MaterialCategoryCatalog.fallback;

    return ScaffoldWithNavigation(
      title: 'Reciclaje',
      currentPath: '/reciclaje',
      body: Scaffold(
        appBar: AppBar(
          title: const Text('Transacciones de reciclaje'),
          actions: [
            IconButton(
              tooltip: 'Filtrar por fecha',
              onPressed: _selectDateRange,
              icon: const Icon(Icons.date_range_outlined),
            ),
            IconButton(
              tooltip: 'Actualizar transacciones',
              onPressed: () => ref.invalidate(recyclingTransactionsProvider),
              icon: const Icon(Icons.refresh),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (requestPointsAsync.isLoading)
                  const LinearProgressIndicator(),
                if (requestPointsAsync.hasError)
                  ErrorState(
                    message:
                        'No se pudieron otorgar puntos de solicitudes completadas.',
                    error: requestPointsAsync.error,
                    onRetry: () =>
                        ref.invalidate(completedRequestPointsProvider),
                  ),
                transactionsAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (error, stackTrace) => const SizedBox.shrink(),
                  data: (transactions) => _buildFilters(
                    usersAsync.valueOrNull ?? const <UserEntity>[],
                    collectorsAsync.valueOrNull ?? const <RecolectorEntity>[],
                    centersAsync.valueOrNull ?? const <CentroAcopioEntity>[],
                    categoryCatalog,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: transactionsAsync.when(
                    loading: () => const LoadingState(
                      message: 'Cargando transacciones...',
                    ),
                    error: (error, stackTrace) => _buildErrorState(error),
                    data: (transactions) => _buildTransactionList(
                      transactions,
                      usersAsync.valueOrNull ?? const <UserEntity>[],
                      collectorsAsync.valueOrNull ?? const <RecolectorEntity>[],
                      centersAsync.valueOrNull ?? const <CentroAcopioEntity>[],
                      categoryCatalog,
                      offersAsync,
                      offerRepository,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilters(
    List<UserEntity> users,
    List<RecolectorEntity> collectors,
    List<CentroAcopioEntity> centers,
    MaterialCategoryCatalog categoryCatalog,
  ) {
    if (_material != _all &&
        !categoryCatalog.categories
            .any((category) => category.id == _material)) {
      _material = _all;
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth < 600
            ? constraints.maxWidth
            : (constraints.maxWidth - 36) / 4;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CategoryCatalogNotice(catalog: categoryCatalog),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: width,
                  child: _dropdown(
                    label: 'Centro',
                    value: _centerId,
                    items: {
                      _all: 'Todos los centros',
                      for (final center in centers)
                        center.id:
                            center.nombre.isEmpty ? center.id : center.nombre,
                    },
                    onChanged: (value) => setState(() => _centerId = value),
                  ),
                ),
                SizedBox(
                  width: width,
                  child: _dropdown(
                    label: 'Material',
                    value: _material,
                    items: {
                      _all: 'Todos los materiales',
                      for (final material in categoryCatalog.categories)
                        material.id: material.displayName,
                    },
                    onChanged: (value) => setState(() => _material = value),
                  ),
                ),
                SizedBox(
                  width: width,
                  child: _dropdown(
                    label: 'Usuario',
                    value: _userId,
                    items: {
                      _all: 'Todos los usuarios',
                      for (final user in users)
                        user.uid: user.nombre.isEmpty ? user.uid : user.nombre,
                    },
                    onChanged: (value) => setState(() => _userId = value),
                  ),
                ),
                SizedBox(
                  width: width,
                  child: _dropdown(
                    label: 'Recolector',
                    value: _collectorId,
                    items: {
                      _all: 'Todos los recolectores',
                      for (final collector in collectors)
                        collector.id: collector.nombreCompleto.isEmpty
                            ? collector.id
                            : collector.nombreCompleto,
                    },
                    onChanged: (value) => setState(() => _collectorId = value),
                  ),
                ),
                if (_dateRange != null)
                  Chip(
                    avatar: const Icon(Icons.event_outlined, size: 16),
                    label: Text(
                      '${_shortDate(_dateRange!.start)} – '
                      '${_shortDate(_dateRange!.end)}',
                    ),
                    onDeleted: () => setState(() => _dateRange = null),
                  ),
                if (_hasFilters)
                  TextButton.icon(
                    onPressed: () => setState(() {
                      _material = _all;
                      _userId = _all;
                      _collectorId = _all;
                      _centerId = _all;
                      _dateRange = null;
                    }),
                    icon: const Icon(Icons.filter_alt_off_outlined),
                    label: const Text('Limpiar filtros'),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _dropdown({
    required String label,
    required String value,
    required Map<String, String> items,
    required ValueChanged<String> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      key: Key('recycling_filter_$label'),
      value: items.containsKey(value) ? value : _all,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      items: items.entries
          .map(
            (entry) => DropdownMenuItem(
              value: entry.key,
              child: Text(entry.value, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(growable: false),
      onChanged: (next) {
        if (next != null) onChanged(next);
      },
    );
  }

  Future<void> _selectDateRange() async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 1),
      initialDateRange: _dateRange,
    );
    if (range != null && mounted) {
      setState(() => _dateRange = range);
    }
  }

  Widget _buildTransactionList(
    List<RecyclingTransaction> transactions,
    List<UserEntity> users,
    List<RecolectorEntity> collectors,
    List<CentroAcopioEntity> centers,
    MaterialCategoryCatalog categoryCatalog,
    AsyncValue<List<OfertaEntity>> offersAsync,
    OfertaRepository offerRepository,
  ) {
    final usersById = {for (final user in users) user.uid: user};
    final collectorsById = {
      for (final collector in collectors) collector.id: collector,
    };
    final centersById = {for (final center in centers) center.id: center};
    final filtered = transactions
        .where((transaction) => _matchesFilters(transaction, categoryCatalog))
        .toList(growable: false);
    final delivered = filtered
        .where((transaction) =>
            transaction.status == RecyclingTransactionStatus.completed)
        .toList(growable: false);
    final totalWeight = delivered.fold<double>(
      0,
      (total, transaction) => total + transaction.weightKg,
    );
    final totalCo2 = delivered.fold<double>(
      0,
      (total, transaction) =>
          total +
          transaction.weightKg *
              (_co2Factors[materialCategoryId(
                    transaction.materialCategory,
                    categoryCatalog,
                  )] ??
                  _co2Factors['OTRO']!),
    );
    final topCollectors = _topCollectors(delivered, collectorsById);
    final recentMonths = _monthlyTotals(delivered);
    final acceptedOffers = offersAsync.valueOrNull
            ?.where((offer) => offer.estado == 'ACEPTADA')
            .toList(growable: false) ??
        const <OfertaEntity>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _StatCard(
              label: 'Entregas',
              value: delivered.length.toString(),
              icon: Icons.receipt_long_outlined,
            ),
            _StatCard(
              label: 'Kg entregados',
              value: '${totalWeight.toStringAsFixed(1)} kg',
              icon: Icons.scale_outlined,
            ),
            _StatCard(
              label: 'CO₂ estimado',
              value: '${totalCo2.toStringAsFixed(1)} kg',
              icon: Icons.co2_outlined,
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (topCollectors.isNotEmpty)
          _TopCollectorsCard(topCollectors: topCollectors),
        const SizedBox(height: 8),
        _MonthlyKgChart(totals: recentMonths),
        const SizedBox(height: 8),
        if (offersAsync.isLoading) const LinearProgressIndicator(),
        if (offersAsync.hasError)
          ErrorState(
            message: 'No se pudieron cargar las entregas pendientes.',
            error: offersAsync.error,
            onRetry: () => ref.invalidate(ofertasProvider((
              estado: null,
              centroId: null,
              recolectorId: null,
              desde: null,
              hasta: null,
            ))),
          ),
        if (offersAsync.hasValue)
          _pendingOffersSection(acceptedOffers, offerRepository),
        const SizedBox(height: 16),
        Expanded(
          child: filtered.isEmpty
              ? EmptyState(
                  message: transactions.isEmpty
                      ? 'Aún no hay entregas ni transacciones de reciclaje.'
                      : 'No hay transacciones para los filtros seleccionados.',
                )
              : SingleChildScrollView(
                  key: const Key('recycling_transactions_list'),
                  scrollDirection: Axis.horizontal,
                  child: SingleChildScrollView(
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Detalle')),
                        DataColumn(label: Text('Fecha')),
                        DataColumn(label: Text('Categoría')),
                        DataColumn(label: Text('Recolector')),
                        DataColumn(label: Text('Centro')),
                        DataColumn(label: Text('Peso')),
                      ],
                      rows: [
                        for (final transaction in filtered)
                          _transactionRow(
                            transaction,
                            usersById,
                            collectorsById,
                            centersById,
                            categoryCatalog,
                          ),
                      ],
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _pendingOffersSection(
    List<OfertaEntity> offers,
    OfertaRepository repository,
  ) {
    return ExpansionTile(
      key: const Key('recycling_pending_offers'),
      tilePadding: EdgeInsets.zero,
      title: Text('Entregas pendientes de confirmar (${offers.length})'),
      children: [
        if (offers.isEmpty)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('No hay ofertas aceptadas por confirmar.'),
            ),
          )
        else
          SizedBox(
            height: offers.length > 2 ? 240 : offers.length * 88,
            child: ListView.builder(
              itemCount: offers.length,
              itemBuilder: (context, index) {
                final offer = offers[index];
                return Card(
                  child: ListTile(
                    title: Text(displayMaterialCategory(offer.categoria)),
                    subtitle: Text(
                      'Recolector: ${offer.recolectorId} · Centro: ${offer.centroId} · '
                      'Peso estimado: ${offer.peso.toStringAsFixed(1)} kg',
                    ),
                    trailing: FilledButton(
                      key: Key('recycling_finalize_offer_${offer.id}'),
                      onPressed: () =>
                          _confirmOfferDelivery(offer, repository),
                      child: const Text('Confirmar entrega'),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Future<void> _confirmOfferDelivery(
    OfertaEntity offer,
    OfertaRepository repository,
  ) async {
    final confirmedWeight = await showDialog<double>(
      context: context,
      builder: (_) => _WeightConfirmationDialog(
        initialWeight: offer.weightConfirmed ?? offer.peso,
      ),
    );
    if (confirmedWeight != null && mounted) {
      try {
        await repository.finalize(
          offer.id,
          weightConfirmed: confirmedWeight,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Entrega confirmada; puntos actualizados.'),
            ),
          );
        }
      } catch (error, stackTrace) {
        debugPrint(
            'No se pudo confirmar la entrega ${offer.id}: $error\n$stackTrace');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('No se pudo confirmar la entrega: $error'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  DataRow _transactionRow(
    RecyclingTransaction transaction,
    Map<String, UserEntity> usersById,
    Map<String, RecolectorEntity> collectorsById,
    Map<String, CentroAcopioEntity> centersById,
    MaterialCategoryCatalog categoryCatalog,
  ) {
    final user = usersById[transaction.userId];
    final collector = collectorsById[transaction.collectorId];
    final center = centersById[transaction.centerId];
    final collectorName = collector?.nombreCompleto.isNotEmpty == true
        ? collector!.nombreCompleto
        : transaction.collectorId;
    final centerName = center?.nombre.isNotEmpty == true
        ? center!.nombre
        : transaction.centerId;
    return DataRow(
      cells: [
        DataCell(
          KeyedSubtree(
            key: Key('recycling_transaction_${transaction.id}'),
            child: IconButton(
              tooltip: 'Ver detalle',
              key: Key('recycling_details_${transaction.id}'),
              onPressed: () => showDialog<void>(
                context: context,
                builder: (dialogContext) => RecyclingTransactionDetailDialog(
                  transaction: transaction,
                  categoryLabel: displayMaterialCategory(
                    transaction.materialCategory,
                    categoryCatalog,
                  ),
                  userName: user?.nombre ?? transaction.userId,
                  collectorName: collectorName,
                  centerName: centerName,
                  onOpenCollector: transaction.collectorId.isEmpty
                      ? null
                      : () => context.go(RouteNames.recolectores),
                  onOpenCenter: transaction.centerId.isEmpty
                      ? null
                      : () => context.go(RouteNames.centros),
                ),
              ),
              icon: const Icon(Icons.visibility_outlined),
            ),
          ),
        ),
        DataCell(Text(_formatRecyclingDate(transaction.createdAt))),
        DataCell(Text(displayMaterialCategory(
          transaction.materialCategory,
          categoryCatalog,
        ))),
        DataCell(
          transaction.collectorId.isEmpty
              ? const Text('Sin recolector')
              : TextButton(
                  onPressed: () => context.go(RouteNames.recolectores),
                  child: Text(collectorName),
                ),
        ),
        DataCell(
          transaction.centerId.isEmpty
              ? const Text('Sin centro')
              : TextButton(
                  onPressed: () => context.go(RouteNames.centros),
                  child: Text(centerName),
                ),
        ),
        DataCell(Text('${transaction.weightKg.toStringAsFixed(2)} kg')),
      ],
    );
  }

  bool _matchesFilters(
    RecyclingTransaction transaction,
    MaterialCategoryCatalog categoryCatalog,
  ) {
    final start =
        _dateRange == null ? null : DateUtils.dateOnly(_dateRange!.start);
    final endExclusive = _dateRange == null
        ? null
        : DateUtils.dateOnly(_dateRange!.end).add(const Duration(days: 1));
    final inDateRange = (start == null ||
            !transaction.createdAt.isBefore(start)) &&
        (endExclusive == null || transaction.createdAt.isBefore(endExclusive));

    return (_material == _all ||
            materialCategoryId(transaction.materialCategory, categoryCatalog) ==
                _material) &&
        (_userId == _all || transaction.userId == _userId) &&
        (_collectorId == _all || transaction.collectorId == _collectorId) &&
        (_centerId == _all || transaction.centerId == _centerId) &&
        inDateRange;
  }

  Widget _buildErrorState(Object error) => ErrorState(
        message: 'No se pudieron cargar las transacciones.',
        error: error,
        onRetry: () => ref.invalidate(recyclingTransactionsProvider),
      );

  bool get _hasFilters =>
      _material != _all ||
      _userId != _all ||
      _collectorId != _all ||
      _centerId != _all ||
      _dateRange != null;

  String _shortDate(DateTime date) => DateFormat.yMd().format(date);

  List<({String name, double kilograms})> _topCollectors(
    List<RecyclingTransaction> transactions,
    Map<String, RecolectorEntity> collectorsById,
  ) {
    final kilogramsByCollector = <String, double>{};
    for (final transaction in transactions) {
      if (transaction.collectorId.isEmpty) continue;
      kilogramsByCollector.update(
        transaction.collectorId,
        (total) => total + transaction.weightKg,
        ifAbsent: () => transaction.weightKg,
      );
    }
    final top = kilogramsByCollector.entries.toList()
      ..sort((first, second) => second.value.compareTo(first.value));
    return top.take(5).map((entry) {
      final name = collectorsById[entry.key]?.nombreCompleto;
      return (
        name: name == null || name.isEmpty ? entry.key : name,
        kilograms: entry.value,
      );
    }).toList(growable: false);
  }

  List<({DateTime month, double kilograms})> _monthlyTotals(
    List<RecyclingTransaction> transactions,
  ) {
    final now = DateTime.now();
    final months = List.generate(
      6,
      (index) => DateTime(now.year, now.month - 5 + index),
    );
    return months.map((month) {
      final kilograms = transactions
          .where((transaction) =>
              transaction.createdAt.year == month.year &&
              transaction.createdAt.month == month.month)
          .fold<double>(
            0,
            (total, transaction) => total + transaction.weightKg,
          );
      return (month: month, kilograms: kilograms);
    }).toList(growable: false);
  }
}

class _WeightConfirmationDialog extends StatefulWidget {
  const _WeightConfirmationDialog({required this.initialWeight});

  final double initialWeight;

  @override
  State<_WeightConfirmationDialog> createState() =>
      _WeightConfirmationDialogState();
}

class _WeightConfirmationDialogState extends State<_WeightConfirmationDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialWeight.toString());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Confirmar entrega'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          key: const Key('recycling_confirmed_weight'),
          controller: _controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Peso confirmado (kg)'),
          validator: (value) {
            final parsed = double.tryParse(value?.trim() ?? '');
            if (parsed == null || !parsed.isFinite || parsed < 0) {
              return 'Ingresa un peso válido no negativo.';
            }
            return null;
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            if (_formKey.currentState?.validate() ?? false) {
              Navigator.pop(context, double.parse(_controller.text.trim()));
            }
          },
          child: const Text('Confirmar'),
        ),
      ],
    );
  }
}

String _formatRecyclingDate(DateTime date) {
  if (date.millisecondsSinceEpoch <= 0) return 'Sin fecha';
  return DateFormat('dd/MM/yyyy HH:mm').format(date);
}

class _StatCard extends StatelessWidget {
  const _StatCard({
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
      width: 210,
      child: Card(
        key: Key('recycling_stat_$label'),
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
                    Text(
                      label,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
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

class _TopCollectorsCard extends StatelessWidget {
  const _TopCollectorsCard({required this.topCollectors});

  final List<({String name, double kilograms})> topCollectors;

  @override
  Widget build(BuildContext context) => Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Top 5 recolectores por kg entregados',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  for (var index = 0; index < topCollectors.length; index++)
                    Text(
                      '${index + 1}. ${topCollectors[index].name}: '
                      '${topCollectors[index].kilograms.toStringAsFixed(1)} kg',
                    ),
                ],
              ),
            ],
          ),
        ),
      );
}

class _MonthlyKgChart extends StatelessWidget {
  const _MonthlyKgChart({required this.totals});

  final List<({DateTime month, double kilograms})> totals;

  @override
  Widget build(BuildContext context) {
    if (totals.isEmpty) return const SizedBox.shrink();
    final maxKg = totals.fold<double>(
      0,
      (maximum, entry) => entry.kilograms > maximum ? entry.kilograms : maximum,
    );
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 20, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Kg entregados por mes',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 170,
              child: BarChart(
                BarChartData(
                  maxY: maxKg == 0 ? 1 : maxKg * 1.2,
                  barGroups: [
                    for (var index = 0; index < totals.length; index++)
                      BarChartGroupData(
                        x: index,
                        barRods: [
                          BarChartRodData(
                            toY: totals[index].kilograms,
                            color: AppColors.primary,
                            width: 18,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ],
                      ),
                  ],
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 || index >= totals.length) {
                            return const SizedBox.shrink();
                          }
                          return SideTitleWidget(
                            axisSide: meta.axisSide,
                            child: Text(
                              DateFormat.MMM().format(totals[index].month),
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 42,
                        getTitlesWidget: (value, meta) => SideTitleWidget(
                          axisSide: meta.axisSide,
                          child: Text(
                            value.toStringAsFixed(0),
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ),
                      ),
                    ),
                  ),
                  gridData: const FlGridData(show: true),
                  borderData: FlBorderData(show: false),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
