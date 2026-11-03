import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../domain/entities/centro_acopio_entity.dart';
import '../../../domain/entities/oferta_entity.dart';
import '../../../domain/entities/recolector_entity.dart';
import '../../../domain/repositories/oferta_repository.dart';
import '../../providers/centro_acopio_providers.dart';
import '../../providers/oferta_providers.dart';
import '../../providers/recolector_providers.dart';
import 'widgets/oferta_card.dart';
import 'widgets/oferta_detail_dialog.dart';

class OfertasPage extends ConsumerStatefulWidget {
  const OfertasPage({super.key});

  @override
  ConsumerState<OfertasPage> createState() => _OfertasPageState();
}

class _OfertasPageState extends ConsumerState<OfertasPage> {
  static const String _all = 'todos';
  String _query = '';
  String _status = _all;
  String _centerId = _all;
  String _collectorId = _all;
  DateTimeRange? _dateRange;

  @override
  Widget build(BuildContext context) {
    final offersAsync = ref.watch(ofertasProvider((
      estado: null,
      centroId: null,
      recolectorId: null,
      desde: null,
      hasta: null,
    )));
    final centersAsync = ref.watch(
      centrosAcopioProvider((zona: null, estadoActivo: true)),
    );
    final collectorsAsync = ref.watch(
      recolectoresProvider((zona: null, estadoActivo: true)),
    );
    final repository = ref.watch(ofertaRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ofertas a Centros'),
        actions: [
          IconButton(
            tooltip: 'Rango de fechas',
            onPressed: _selectDateRange,
            icon: const Icon(Icons.date_range_outlined),
          ),
          if (_dateRange != null)
            IconButton(
              tooltip: 'Limpiar rango',
              onPressed: () => setState(() => _dateRange = null),
              icon: const Icon(Icons.close),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              _buildFilters(centersAsync, collectorsAsync),
              const SizedBox(height: 16),
              Expanded(
                child: offersAsync.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(),
                  ),
                  error: (error, stackTrace) => _errorState(),
                  data: (offers) => _buildOffers(
                    offers,
                    centersAsync.valueOrNull ?? const <CentroAcopioEntity>[],
                    collectorsAsync.valueOrNull ?? const <RecolectorEntity>[],
                    repository,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilters(
    AsyncValue<List<CentroAcopioEntity>> centersAsync,
    AsyncValue<List<RecolectorEntity>> collectorsAsync,
  ) {
    final centers = centersAsync.valueOrNull ?? const <CentroAcopioEntity>[];
    final collectors =
        collectorsAsync.valueOrNull ?? const <RecolectorEntity>[];
    return LayoutBuilder(
      builder: (context, constraints) => Wrap(
        spacing: 14,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: constraints.maxWidth < 640 ? constraints.maxWidth : 300,
            child: TextField(
              key: const Key('oferta_search_field'),
              onChanged: (value) => setState(() => _query = value.trim()),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Buscar centro o recolector...',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          _dropdown(
            label: 'Estado',
            value: _status,
            items: const {
              _all: 'Todos los estados',
              'pendiente': 'Pendientes',
              'aceptada': 'Aceptadas',
              'en_camino': 'En camino',
              'finalizada': 'Finalizadas',
              'cancelada': 'Canceladas',
            },
            onChanged: (value) => setState(() => _status = value),
          ),
          _dropdown(
            label: 'Centro',
            value: _centerId,
            items: {
              _all: 'Todos los centros',
              for (final center in centers) center.id: center.nombre,
            },
            onChanged: (value) => setState(() => _centerId = value),
          ),
          _dropdown(
            label: 'Recolector',
            value: _collectorId,
            items: {
              _all: 'Todos los recolectores',
              for (final collector in collectors)
                collector.id: collector.nombreCompleto,
            },
            onChanged: (value) => setState(() => _collectorId = value),
          ),
          if (_dateRange != null)
            Chip(
              avatar: const Icon(Icons.event_outlined, size: 16),
              label: Text(
                '${_shortDate(_dateRange!.start)} – ${_shortDate(_dateRange!.end)}',
              ),
            ),
        ],
      ),
    );
  }

  Widget _dropdown({
    required String label,
    required String value,
    required Map<String, String> items,
    required ValueChanged<String> onChanged,
  }) {
    return SizedBox(
      width: 210,
      child: DropdownButtonFormField<String>(
        value: items.containsKey(value) ? value : _all,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        items: items.entries
            .map((entry) => DropdownMenuItem(
                  value: entry.key,
                  child: Text(entry.value, overflow: TextOverflow.ellipsis),
                ))
            .toList(growable: false),
        onChanged: (next) {
          if (next != null) onChanged(next);
        },
      ),
    );
  }

  Future<void> _selectDateRange() async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
      initialDateRange: _dateRange,
    );
    if (range != null && mounted) setState(() => _dateRange = range);
  }

  Widget _errorState() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined,
                color: AppColors.error, size: 40),
            const SizedBox(height: 12),
            const Text('No se pudieron cargar las ofertas.'),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => ref.invalidate(ofertasProvider((
                estado: null,
                centroId: null,
                recolectorId: null,
                desde: null,
                hasta: null,
              ))),
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      );

  Widget _buildOffers(
    List<OfertaEntity> offers,
    List<CentroAcopioEntity> centers,
    List<RecolectorEntity> collectors,
    OfertaRepository repository,
  ) {
    final centersById = {for (final item in centers) item.id: item};
    final collectorsById = {for (final item in collectors) item.id: item};
    final filtered = offers.where((offer) {
      final center = centersById[offer.centroId];
      final collector = collectorsById[offer.recolectorId];
      final matchesStatus = _status == _all || offer.estado == _status;
      final matchesCenter = _centerId == _all || offer.centroId == _centerId;
      final matchesCollector =
          _collectorId == _all || offer.recolectorId == _collectorId;
      final normalizedQuery = _query.toLowerCase();
      final matchesQuery = normalizedQuery.isEmpty ||
          (center?.nombre.toLowerCase().contains(normalizedQuery) ?? false) ||
          (collector?.nombreCompleto.toLowerCase().contains(normalizedQuery) ??
              false);
      final matchesDates = _dateRange == null ||
          (!offer.fechaOferta.isBefore(DateUtils.dateOnly(_dateRange!.start)) &&
              !offer.fechaOferta.isAfter(
                DateUtils.dateOnly(_dateRange!.end)
                    .add(const Duration(days: 1))
                    .subtract(const Duration(microseconds: 1)),
              ));
      return matchesStatus &&
          matchesCenter &&
          matchesCollector &&
          matchesQuery &&
          matchesDates;
    }).toList(growable: false);

    if (filtered.isEmpty) {
      return const Center(child: Text('No hay ofertas para estos filtros.'));
    }
    return ListView.separated(
      key: const Key('ofertas_list'),
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: filtered.length,
      separatorBuilder: (context, index) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        final offer = filtered[index];
        final collector = collectorsById[offer.recolectorId];
        final center = centersById[offer.centroId];
        final actions = _actions(offer, repository);
        return OfertaCard(
          oferta: offer,
          recolectorNombre: collector?.nombreCompleto ?? offer.recolectorId,
          centroNombre: center?.nombre ?? offer.centroId,
          placa: collector?.vehiculoInfo['placa'] as String?,
          actions: actions,
          onDetails: () => showDialog<void>(
            context: context,
            builder: (context) => OfertaDetailDialog(
              oferta: offer,
              recolector: collector,
              centro: center,
              actions: actions,
            ),
          ),
        );
      },
    );
  }

  List<Widget> _actions(OfertaEntity offer, OfertaRepository repository) {
    final actions = <Widget>[];
    if (offer.estado == 'pendiente') {
      actions.add(FilledButton.icon(
        key: Key('accept_offer_${offer.id}'),
        onPressed: () => _runAction(
            offer, repository, () => repository.accept(offer.id),
            success: 'Oferta aceptada. La publicación quedó reservada.'),
        icon: const Icon(Icons.check_circle_outline),
        label: const Text('Aceptar'),
      ));
      actions.add(OutlinedButton.icon(
        onPressed: () => _runAction(
          offer,
          repository,
          () => repository.cancel(offer.id, reason: 'rechazada'),
          success: 'Oferta rechazada.',
        ),
        icon: const Icon(Icons.close),
        label: const Text('Rechazar'),
      ));
    } else if (offer.estado == 'aceptada') {
      actions.add(FilledButton.icon(
        onPressed: () => _runAction(
          offer,
          repository,
          () => repository.markInTransit(offer.id),
          success: 'Oferta marcada en camino.',
        ),
        icon: const Icon(Icons.local_shipping_outlined),
        label: const Text('Marcar en camino'),
      ));
    } else if (offer.estado == 'en_camino') {
      actions.add(FilledButton.icon(
        onPressed: () => _confirmFinalize(offer, repository),
        icon: const Icon(Icons.task_alt),
        label: const Text('Finalizar'),
      ));
    }
    if (offer.estado != 'finalizada' && offer.estado != 'cancelada') {
      actions.add(OutlinedButton.icon(
        onPressed: () => _confirmCancel(offer, repository),
        icon: const Icon(Icons.cancel_outlined),
        label: const Text('Cancelar'),
      ));
    }
    return actions;
  }

  Future<void> _confirmCancel(
    OfertaEntity offer,
    OfertaRepository repository,
  ) async {
    String? selectedReason;
    String otherReason = '';
    final reasons = [
      'Capacidad excedida',
      'Material no corresponde',
      'Recolector no disponible',
      'Centro no disponible',
      'Error en datos',
      'Otro',
    ];

    final result = await showDialog<({String reason, String? detail})?>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Cancelar oferta'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Esta acción libera la capacidad del centro y ajusta los contadores del recolector. Selecciona el motivo:',
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedReason,
                hint: const Text('Seleccionar motivo'),
                items: reasons
                    .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                    .toList(),
                onChanged: (val) => setDialogState(() => selectedReason = val),
                decoration: const InputDecoration(border: OutlineInputBorder()),
              ),
              if (selectedReason == 'Otro') ...[
                const SizedBox(height: 12),
                TextField(
                  onChanged: (val) => otherReason = val,
                  decoration: const InputDecoration(
                    labelText: 'Detalle del motivo',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Volver'),
            ),
            FilledButton(
              onPressed: selectedReason == null ||
                      (selectedReason == 'Otro' && otherReason.isEmpty)
                  ? null
                  : () => Navigator.pop(
                        context,
                        (reason: selectedReason!, detail: otherReason),
                      ),
              child: const Text('Confirmar Cancelación'),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      final finalReason =
          result.reason == 'Otro' ? result.detail : result.reason;
      await _runAction(
        offer,
        repository,
        () => repository.cancel(offer.id, reason: finalReason),
        success: 'Oferta cancelada y capacidad liberada.',
      );
    }
  }

  Future<void> _confirmFinalize(
    OfertaEntity offer,
    OfertaRepository repository,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar recepción'),
        content: const Text(
          'Al finalizar, la publicación relacionada se marcará vendida y se liberará la capacidad comprometida del centro.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Volver'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmar recepción'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _runAction(
        offer,
        repository,
        () => repository.finalize(offer.id),
        success: 'Oferta finalizada.',
      );
    }
  }

  Future<void> _runAction(
    OfertaEntity offer,
    OfertaRepository repository,
    Future<void> Function() action, {
    required String success,
  }) async {
    try {
      await action();
      if (mounted) _showMessage(success);
    } on OfertaCapacityExceeded catch (error) {
      if (mounted) {
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Capacidad insuficiente'),
            content: Text(error.toString()),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cerrar'),
              ),
            ],
          ),
        );
      }
    } on OfertaStateTransitionException catch (error) {
      if (mounted) _showMessage(error.message, isError: true);
    } on OfertaDuplicateActive catch (error) {
      if (mounted) _showMessage(error.toString(), isError: true);
    } on OfertaValidationException catch (error) {
      if (mounted) {
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('No se puede procesar la oferta'),
            content: Text(error.message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cerrar'),
              ),
            ],
          ),
        );
      }
    } catch (error, stackTrace) {
      debugPrint(
          'No se pudo actualizar oferta ${offer.id}: $error\n$stackTrace');
      if (mounted) {
        _showMessage('No se pudo actualizar la oferta.', isError: true);
      }
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : null,
      ));
  }
}

String _shortDate(DateTime date) => '${date.day.toString().padLeft(2, '0')}/'
    '${date.month.toString().padLeft(2, '0')}/'
    '${date.year}';
