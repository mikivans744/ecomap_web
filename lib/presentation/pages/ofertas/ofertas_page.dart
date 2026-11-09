import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/admin_auth_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../domain/entities/centro_acopio_entity.dart';
import '../../../domain/entities/oferta_entity.dart';
import '../../../domain/entities/negociacion_oferta_entity.dart';
import '../../../domain/entities/recolector_entity.dart';
import '../../../domain/repositories/oferta_repository.dart';
import '../../providers/centro_acopio_providers.dart';
import '../../providers/material_category_provider.dart';
import '../../providers/oferta_providers.dart';
import '../../providers/recolector_providers.dart';
import '../../widgets/async_states.dart';
import '../../widgets/category_catalog_notice.dart';
import '../../widgets/scaffold_with_navigation.dart';
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
  String _material = _all;
  String _centerId = _all;
  String _collectorId = _all;
  DateTimeRange? _dateRange;

  @override
  Widget build(BuildContext context) {
    final canManageOffers = ref.watch(adminPermissionsProvider).canManageOffers;
    final offersAsync = ref.watch(ofertasProvider((
      estado: null,
      centroId: null,
      recolectorId: null,
      desde: null,
      hasta: null,
    )));
    final negotiationsAsync = ref.watch(negotiationOffersProvider((
      publicacionId: null,
      ciudadanoId: null,
      recolectorId: null,
    )));
    final centersAsync = ref.watch(
      centrosAcopioProvider((zona: null, estadoActivo: null)),
    );
    final collectorsAsync = ref.watch(
      recolectoresProvider((zona: null, estadoActivo: null)),
    );
    final repository = ref.watch(ofertaRepositoryProvider);
    final categoryCatalog =
        ref.watch(materialCategoryCatalogProvider).valueOrNull ??
            MaterialCategoryCatalog.fallback;

    return DefaultTabController(
      length: 2,
      child: ScaffoldWithNavigation(
        title: 'Ofertas',
        currentPath: '/ofertas',
        body: Scaffold(
          appBar: AppBar(
            title: const Text('Ofertas'),
            bottom: const TabBar(
              tabs: [
                Tab(text: 'Ofertas a centros'),
                Tab(text: 'Negociaciones'),
              ],
            ),
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
          body: TabBarView(
            children: [
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      _buildFilters(
                        centersAsync,
                        collectorsAsync,
                        categoryCatalog,
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: offersAsync.when(
                          loading: () => const LoadingState(
                            message: 'Cargando ofertas...',
                          ),
                          error: (error, stackTrace) => _errorState(),
                          data: (offers) => _buildOffers(
                            offers,
                            centersAsync.valueOrNull ??
                                const <CentroAcopioEntity>[],
                            collectorsAsync.valueOrNull ??
                                const <RecolectorEntity>[],
                            repository,
                            canManageOffers,
                            categoryCatalog,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SafeArea(
                child: negotiationsAsync.when(
                  loading: () => const LoadingState(
                    message: 'Cargando negociaciones...',
                  ),
                  error: (error, stackTrace) => ErrorState(
                    message: 'No se pudieron cargar las negociaciones.',
                    onRetry: () => ref.invalidate(negotiationOffersProvider((
                      publicacionId: null,
                      ciudadanoId: null,
                      recolectorId: null,
                    ))),
                  ),
                  data: (negotiations) => _buildNegotiations(negotiations),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNegotiations(List<NegociacionOfertaEntity> negotiations) {
    if (negotiations.isEmpty) {
      return const EmptyState(message: 'No hay negociaciones.');
    }

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: negotiations.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final negotiation = negotiations[index];
        final state = switch (negotiation.estado) {
          NegociacionOfertaEstado.pendiente => 'PENDIENTE',
          NegociacionOfertaEstado.aceptada => 'ACEPTADA',
          NegociacionOfertaEstado.rechazada => 'RECHAZADA',
        };
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Publicación ${negotiation.publicacionId}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    Chip(label: Text(state)),
                  ],
                ),
                const SizedBox(height: 8),
                Text('Ciudadano: ${negotiation.ciudadanoId}'),
                Text('Recolector: ${negotiation.recolectorId}'),
                Text(
                    'Precio: \$${_formatNegotiationPrice(negotiation.precio)}'),
                Text('Mensaje: ${negotiation.mensaje}'),
                Text(
                  'Fecha: ${_formatNegotiationDate(negotiation.createdAt)}',
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFilters(
    AsyncValue<List<CentroAcopioEntity>> centersAsync,
    AsyncValue<List<RecolectorEntity>> collectorsAsync,
    MaterialCategoryCatalog categoryCatalog,
  ) {
    final centers = centersAsync.valueOrNull ?? const <CentroAcopioEntity>[];
    final collectors =
        collectorsAsync.valueOrNull ?? const <RecolectorEntity>[];
    if (_material != _all &&
        !categoryCatalog.categories
            .any((category) => category.id == _material)) {
      _material = _all;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CategoryCatalogNotice(catalog: categoryCatalog),
        LayoutBuilder(
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
                  'OFERTADA': 'Ofertadas',
                  'ACEPTADA': 'Aceptadas',
                  'ENTREGADA': 'Entregadas',
                  'RECHAZADA': 'Rechazadas',
                },
                onChanged: (value) => setState(() => _status = value),
              ),
              _dropdown(
                label: 'Categoría',
                value: _material,
                items: {
                  _all: 'Todas las categorías',
                  for (final category in categoryCatalog.categories)
                    category.id: category.displayName,
                },
                onChanged: (value) => setState(() => _material = value),
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
        ),
      ],
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

  Widget _errorState() => ErrorState(
        message: 'No se pudieron cargar las ofertas.',
        onRetry: () => ref.invalidate(ofertasProvider((
          estado: null,
          centroId: null,
          recolectorId: null,
          desde: null,
          hasta: null,
        ))),
      );

  Widget _buildOffers(
    List<OfertaEntity> offers,
    List<CentroAcopioEntity> centers,
    List<RecolectorEntity> collectors,
    OfertaRepository repository,
    bool canManageOffers,
    MaterialCategoryCatalog categoryCatalog,
  ) {
    final centersById = {for (final item in centers) item.id: item};
    final collectorsById = {for (final item in collectors) item.id: item};
    final filtered = offers.where((offer) {
      final center = centersById[offer.centroId];
      final collector = collectorsById[offer.recolectorId];
      final matchesStatus = _status == _all || offer.estado == _status;
      final matchesMaterial = _material == _all ||
          materialCategoryId(offer.categoria, categoryCatalog) == _material;
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
          matchesMaterial &&
          matchesCenter &&
          matchesCollector &&
          matchesQuery &&
          matchesDates;
    }).toList(growable: false);

    if (filtered.isEmpty) {
      return const EmptyState(message: 'No hay ofertas para estos filtros.');
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
        final actions = _actions(offer, repository, canManageOffers);
        return OfertaCard(
          oferta: offer,
          categoryLabel:
              displayMaterialCategory(offer.categoria, categoryCatalog),
          recolectorNombre: collector?.nombreCompleto ?? offer.recolectorId,
          centroNombre: center?.nombre ?? 'Centro sin asignar',
          placa: collector?.vehiculoInfo['placa'] as String?,
          actions: actions,
          onDetails: () => showDialog<void>(
            context: context,
            builder: (context) => OfertaDetailDialog(
              oferta: offer,
              categoryLabel:
                  displayMaterialCategory(offer.categoria, categoryCatalog),
              recolector: collector,
              centro: center,
            ),
          ),
        );
      },
    );
  }

  List<Widget> _actions(
    OfertaEntity offer,
    OfertaRepository repository,
    bool canManageOffers,
  ) {
    if (!canManageOffers) return const [];

    final actions = <Widget>[];
    if (offer.estado == 'OFERTADA') {
      actions.add(FilledButton.icon(
        key: Key('accept_offer_${offer.id}'),
        onPressed: () => _runAction(
            offer, repository, () => repository.accept(offer.id),
            success: 'Oferta aceptada.'),
        icon: const Icon(Icons.check_circle_outline),
        label: const Text('Aceptar'),
      ));
      actions.add(OutlinedButton.icon(
        onPressed: () => _runAction(
          offer,
          repository,
          () => repository.cancel(offer.id),
          success: 'Oferta rechazada.',
        ),
        icon: const Icon(Icons.close),
        label: const Text('Rechazar'),
      ));
    } else if (offer.estado == 'ACEPTADA') {
      actions.add(FilledButton.icon(
        onPressed: () => _confirmFinalize(offer, repository),
        icon: const Icon(Icons.task_alt),
        label: const Text('Confirmar entrega'),
      ));
    }
    return actions;
  }

  Future<void> _confirmFinalize(
    OfertaEntity offer,
    OfertaRepository repository,
  ) async {
    if (!_requireOfferPermission()) return;

    final weightController = TextEditingController(
      text: (offer.weightConfirmed ?? offer.peso).toString(),
    );
    final formKey = GlobalKey<FormState>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar recepción'),
        content: SizedBox(
          width: 440,
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'La publicación relacionada se marcará como entregada y '
                  'se sumarán puntos al recolector y al centro.',
                ),
                TextFormField(
                  key: const Key('confirmed_offer_weight'),
                  controller: weightController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Peso confirmado (kg)',
                  ),
                  validator: (value) {
                    final weight = double.tryParse(value?.trim() ?? '');
                    if (weight == null || !weight.isFinite || weight < 0) {
                      return 'Ingresa un peso válido no negativo.';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Volver'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.pop(context, true);
              }
            },
            child: const Text('Confirmar recepción'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _runAction(
        offer,
        repository,
        () => repository.finalize(
          offer.id,
          weightConfirmed: double.parse(weightController.text.trim()),
        ),
        success: 'Oferta finalizada.',
      );
    }
    weightController.dispose();
  }

  Future<void> _runAction(
    OfertaEntity offer,
    OfertaRepository repository,
    Future<void> Function() action, {
    required String success,
  }) async {
    if (!_requireOfferPermission()) return;
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
    } catch (error, stackTrace) {
      debugPrint(
          'No se pudo actualizar oferta ${offer.id}: $error\n$stackTrace');
      if (mounted) {
        _showMessage('No se pudo actualizar la oferta.', isError: true);
      }
    }
  }

  bool _requireOfferPermission() {
    if (ref.read(adminPermissionsProvider).canManageOffers) return true;
    _showMessage('Sin permisos', isError: true);
    return false;
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

String _formatNegotiationDate(DateTime date) {
  if (date.millisecondsSinceEpoch <= 0 || date.year < 1970) return 'Sin fecha';
  return '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/'
      '${date.year} ${date.hour.toString().padLeft(2, '0')}:'
      '${date.minute.toString().padLeft(2, '0')}';
}

String _formatNegotiationPrice(double price) => price == price.roundToDouble()
    ? price.toStringAsFixed(0)
    : price.toStringAsFixed(2);
