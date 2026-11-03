import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../domain/entities/recolector_entity.dart';
import '../../../domain/entities/recycling_transaction.dart';
import '../../../domain/entities/user_entity.dart';
import '../../providers/recolector_providers.dart';
import '../../providers/recycling_transaction_providers.dart';
import '../../providers/user_providers.dart';
import '../../widgets/async_states.dart';
import '../../widgets/scaffold_with_navigation.dart';
import 'widgets/recycling_transaction_card.dart';
import 'widgets/recycling_transaction_detail_dialog.dart';

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
  DateTimeRange? _dateRange;

  @override
  Widget build(BuildContext context) {
    final transactionsAsync = ref.watch(recyclingTransactionsProvider);
    final usersAsync = ref.watch(
      usersProvider((zona: null, estadoActivo: null)),
    );
    final collectorsAsync = ref.watch(
      recolectoresProvider((zona: null, estadoActivo: null)),
    );

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
                transactionsAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (error, stackTrace) => const SizedBox.shrink(),
                  data: (transactions) => _buildFilters(
                    transactions,
                    usersAsync.valueOrNull ?? const <UserEntity>[],
                    collectorsAsync.valueOrNull ?? const <RecolectorEntity>[],
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
    List<RecyclingTransaction> transactions,
    List<UserEntity> users,
    List<RecolectorEntity> collectors,
  ) {
    final materials = transactions
        .map((transaction) => transaction.materialCategory)
        .where((material) => material.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth < 600
            ? constraints.maxWidth
            : (constraints.maxWidth - 24) / 3;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: width,
              child: _dropdown(
                label: 'Material',
                value: _material,
                items: {
                  _all: 'Todos los materiales',
                  for (final material in materials) material: material,
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
                  _dateRange = null;
                }),
                icon: const Icon(Icons.filter_alt_off_outlined),
                label: const Text('Limpiar filtros'),
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
  ) {
    final usersById = {for (final user in users) user.uid: user};
    final collectorsById = {
      for (final collector in collectors) collector.id: collector,
    };
    final filtered =
        transactions.where(_matchesFilters).toList(growable: false);
    final totalWeight = filtered.fold<double>(
      0,
      (total, transaction) => total + transaction.weightKg,
    );
    final totalPoints = filtered.fold<int>(
      0,
      (total, transaction) => total + transaction.pointsAwarded,
    );
    final pendingCount = filtered
        .where((item) => item.status == RecyclingTransactionStatus.pending)
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _StatCard(
              label: 'Transacciones',
              value: filtered.length.toString(),
              icon: Icons.receipt_long_outlined,
            ),
            _StatCard(
              label: 'Peso reciclado',
              value: '${totalWeight.toStringAsFixed(1)} kg',
              icon: Icons.scale_outlined,
            ),
            _StatCard(
              label: 'Puntos otorgados',
              value: NumberFormat.decimalPattern().format(totalPoints),
              icon: Icons.stars_outlined,
            ),
            _StatCard(
              label: 'Pendientes',
              value: pendingCount.toString(),
              icon: Icons.hourglass_bottom_outlined,
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: filtered.isEmpty
              ? EmptyState(
                  message: transactions.isEmpty
                      ? 'Aún no hay transacciones de reciclaje.'
                      : 'No hay transacciones para los filtros seleccionados.',
                )
              : ListView.separated(
                  key: const Key('recycling_transactions_list'),
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: filtered.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final transaction = filtered[index];
                    final user = usersById[transaction.userId];
                    final collector = collectorsById[transaction.collectorId];
                    final userName = user?.nombre.isNotEmpty == true
                        ? user!.nombre
                        : transaction.userId;
                    final collectorName =
                        collector?.nombreCompleto.isNotEmpty == true
                            ? collector!.nombreCompleto
                            : transaction.collectorId;

                    return RecyclingTransactionCard(
                      transaction: transaction,
                      userName:
                          userName.isEmpty ? 'Usuario no disponible' : userName,
                      collectorName: collectorName.isEmpty
                          ? 'Recolector no asignado'
                          : collectorName,
                      onTap: () => showDialog<void>(
                        context: context,
                        builder: (context) => RecyclingTransactionDetailDialog(
                          transaction: transaction,
                          userName: userName.isEmpty
                              ? 'Usuario no disponible'
                              : userName,
                          collectorName: collectorName.isEmpty
                              ? 'Recolector no asignado'
                              : collectorName,
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  bool _matchesFilters(RecyclingTransaction transaction) {
    final start =
        _dateRange == null ? null : DateUtils.dateOnly(_dateRange!.start);
    final endExclusive = _dateRange == null
        ? null
        : DateUtils.dateOnly(_dateRange!.end).add(const Duration(days: 1));
    final inDateRange = (start == null ||
            !transaction.createdAt.isBefore(start)) &&
        (endExclusive == null || transaction.createdAt.isBefore(endExclusive));

    return (_material == _all || transaction.materialCategory == _material) &&
        (_userId == _all || transaction.userId == _userId) &&
        (_collectorId == _all || transaction.collectorId == _collectorId) &&
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
      _dateRange != null;

  String _shortDate(DateTime date) => DateFormat.yMd().format(date);
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
