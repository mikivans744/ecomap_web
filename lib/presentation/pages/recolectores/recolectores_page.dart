import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/admin_auth_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../domain/entities/recolector_entity.dart';
import '../../../domain/repositories/recolector_repository.dart';
import '../../providers/recolector_providers.dart';
import '../../widgets/async_states.dart';
import '../../widgets/scaffold_with_navigation.dart';
import 'widgets/recolector_form_dialog.dart';

class RecolectoresPage extends ConsumerStatefulWidget {
  const RecolectoresPage({super.key});

  @override
  ConsumerState<RecolectoresPage> createState() => _RecolectoresPageState();
}

class _RecolectoresPageState extends ConsumerState<RecolectoresPage> {
  static const String _allFilter = 'todas';

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _searchDebounce;
  String _searchQuery = '';
  String _zoneFilter = _allFilter;
  String _statusFilter = 'activos';

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() => _searchQuery = value.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final canManageRecolectores =
        ref.watch(adminPermissionsProvider).canManageRecolectores;
    final repository = ref.watch(recolectorRepositoryProvider);
    final allRecolectores = ref.watch(
      recolectoresProvider((zona: null, estadoActivo: null)),
    );
    final AsyncValue<List<RecolectorEntity>> recolectores = _searchQuery.isEmpty
        ? allRecolectores
        : ref.watch(recolectorSearchProvider(_searchQuery));

    return ScaffoldWithNavigation(
      title: 'Gestión de Recolectores',
      currentPath: '/recolectores',
      body: Scaffold(
        appBar: AppBar(
          title: const Text('Gestión de Recolectores'),
          actions: [
            IconButton(
              tooltip: 'Buscar recolectores',
              onPressed: _searchFocusNode.requestFocus,
              icon: const Icon(Icons.search),
            ),
            if (canManageRecolectores)
              IconButton(
                tooltip: 'Nuevo recolector',
                onPressed: () => _openForm(repository),
                icon: const Icon(Icons.add),
              ),
            const SizedBox(width: 8),
          ],
        ),
        floatingActionButton: canManageRecolectores
            ? FloatingActionButton.extended(
                key: const Key('add_recolector_button'),
                tooltip: 'Nuevo recolector',
                onPressed: () => _openForm(repository),
                icon: const Icon(Icons.add),
                label: const Text('Nuevo recolector'),
              )
            : null,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _buildFilters(allRecolectores),
                const SizedBox(height: 16),
                Expanded(
                  child: recolectores.when(
                    loading: () => const LoadingState(
                      message: 'Cargando recolectores...',
                    ),
                    error: (error, stackTrace) => _buildErrorState(),
                    data: (items) => _buildCards(
                      items,
                      repository,
                      canManageRecolectores,
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

  Widget _buildFilters(AsyncValue<List<RecolectorEntity>> allRecolectores) {
    final zones = allRecolectores.maybeWhen(
      data: (items) => items
          .map((item) => item.zona.trim())
          .where((zone) => zone.isNotEmpty)
          .toSet()
          .toList()
        ..sort(),
      orElse: () => <String>[],
    );
    if (_zoneFilter != _allFilter && !zones.contains(_zoneFilter)) {
      _zoneFilter = _allFilter;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return Wrap(
          spacing: 16,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: constraints.maxWidth < 640 ? constraints.maxWidth : 340,
              child: TextField(
                key: const Key('recolector_search_field'),
                controller: _searchController,
                focusNode: _searchFocusNode,
                onChanged: _onSearchChanged,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Buscar por nombre, teléfono o zona...',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            SizedBox(
              width: 220,
              child: DropdownButtonFormField<String>(
                value: _zoneFilter,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Zona',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: [
                  const DropdownMenuItem(
                    value: _allFilter,
                    child: Text('Todas las zonas'),
                  ),
                  ...zones.map(
                    (zone) => DropdownMenuItem(value: zone, child: Text(zone)),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _zoneFilter = value);
                },
              ),
            ),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'activos', label: Text('Activos')),
                ButtonSegment(value: 'inactivos', label: Text('Inactivos')),
                ButtonSegment(value: 'todos', label: Text('Todos')),
              ],
              selected: {_statusFilter},
              onSelectionChanged: (value) =>
                  setState(() => _statusFilter = value.first),
            ),
          ],
        );
      },
    );
  }

  Widget _buildErrorState() {
    return ErrorState(
      message: 'No se pudieron cargar los recolectores.',
      onRetry: () {
        if (_searchQuery.isNotEmpty) {
          ref.invalidate(recolectorSearchProvider(_searchQuery));
        } else {
          ref.invalidate(
            recolectoresProvider((zona: null, estadoActivo: null)),
          );
        }
      },
    );
  }

  Widget _buildCards(
    List<RecolectorEntity> items,
    RecolectorRepository repository,
    bool canManageRecolectores,
  ) {
    final filtered = items.where((item) {
      final matchesZone = _zoneFilter == _allFilter || item.zona == _zoneFilter;
      final matchesStatus = switch (_statusFilter) {
        'activos' => item.estadoActivo,
        'inactivos' => !item.estadoActivo,
        _ => true,
      };
      return matchesZone && matchesStatus;
    }).toList(growable: false);

    if (filtered.isEmpty) {
      return const EmptyState(
        message: 'No hay recolectores para estos filtros.',
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1100
            ? 3
            : constraints.maxWidth >= 700
                ? 2
                : 1;
        return GridView.builder(
          key: const Key('recolectores_grid'),
          padding: const EdgeInsets.only(bottom: 88),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisExtent: 292,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
          ),
          itemCount: filtered.length,
          itemBuilder: (context, index) => _RecolectorCard(
            recolector: filtered[index],
            onDetails: () => _showDetails(filtered[index]),
            onEdit: () => _openForm(repository, recolector: filtered[index]),
            onToggle: () => _confirmToggle(filtered[index], repository),
            canManage: canManageRecolectores,
          ),
        );
      },
    );
  }

  Future<void> _openForm(
    RecolectorRepository repository, {
    RecolectorEntity? recolector,
  }) async {
    if (!_requireRecolectorPermission()) return;

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => RecolectorFormDialog(
        repository: repository,
        recolector: recolector,
      ),
    );
    if (saved == true && mounted) {
      ref.invalidate(recolectoresProvider((zona: null, estadoActivo: null)));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            recolector == null
                ? 'Recolector creado exitosamente.'
                : 'Recolector actualizado exitosamente.',
          ),
        ),
      );
    }
  }

  Future<void> _showDetails(RecolectorEntity recolector) {
    final vehicle = recolector.vehiculoInfo;
    final isVehicle = recolector.medioTransporte == 'vehiculo';
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(recolector.nombreCompleto),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _detailLine(Icons.phone_outlined, recolector.telefono),
                _detailLine(Icons.location_on_outlined, recolector.zona),
                _detailLine(
                  _transportIcon(recolector.medioTransporte),
                  _transportLabel(recolector.medioTransporte),
                ),
                if (isVehicle) ...[
                  _detailLine(
                    Icons.confirmation_number_outlined,
                    'Placa: ${vehicle['placa'] ?? 'Sin placa'}',
                  ),
                  _detailLine(
                    Icons.directions_car_outlined,
                    'Marca: ${vehicle['marca'] ?? 'Sin marca'}',
                  ),
                  _detailLine(
                    Icons.scale_outlined,
                    'Capacidad: ${vehicle['capacidad'] ?? 0} kg',
                  ),
                ],
                _detailLine(
                  Icons.work_history_outlined,
                  '${recolector.aniosExperiencia} años de experiencia',
                ),
                const Divider(height: 24),
                Text('Estadísticas',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text('Kilos ofertados: ${recolector.kilosOfertados} kg'),
                Text('Total de ofertas: ${recolector.totalOfertas}'),
                const SizedBox(height: 16),
                Text('Historial de ofertas',
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 4),
                const Text(
                  'El historial detallado estará disponible al integrar la gestión de ofertas.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Widget _detailLine(IconData icon, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.textSecondary),
            const SizedBox(width: 10),
            Expanded(child: Text(value)),
          ],
        ),
      );

  Future<void> _confirmToggle(
    RecolectorEntity recolector,
    RecolectorRepository repository,
  ) async {
    if (!_requireRecolectorPermission()) return;

    final isBlocking = recolector.estadoActivo;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title:
            Text(isBlocking ? 'Bloquear recolector' : 'Desbloquear recolector'),
        content: Text(
          isBlocking
              ? '¿Estás seguro de bloquear a ${recolector.nombreCompleto}?\n\n'
                  'Esta acción:\n'
                  '- Desactivará su vehículo\n'
                  '- Cancelará sus ofertas activas\n'
                  '- Liberará capacidad en los centros de acopio'
              : '¿Estás seguro de desbloquear a ${recolector.nombreCompleto}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(isBlocking ? 'Bloquear' : 'Desbloquear'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!_requireRecolectorPermission()) return;

    try {
      debugPrint(
        '${isBlocking ? 'Bloqueando' : 'Desbloqueando'} recolector ${recolector.id}',
      );
      await repository.toggleActive(recolector.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Recolector ${isBlocking ? 'bloqueado' : 'desbloqueado'} exitosamente.',
          ),
        ),
      );
    } catch (error, stackTrace) {
      debugPrint('No se pudo bloquear el recolector: $error\n$stackTrace');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is StateError
                ? error.message
                : 'No se pudo actualizar el recolector. Intenta nuevamente.',
          ),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  bool _requireRecolectorPermission() {
    if (ref.read(adminPermissionsProvider).canManageRecolectores) return true;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sin permisos')),
    );
    return false;
  }
}

class _RecolectorCard extends StatelessWidget {
  const _RecolectorCard({
    required this.recolector,
    required this.onDetails,
    required this.onEdit,
    required this.onToggle,
    required this.canManage,
  });

  final RecolectorEntity recolector;
  final VoidCallback onDetails;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final bool canManage;

  @override
  Widget build(BuildContext context) {
    final statusColor =
        recolector.estadoActivo ? AppColors.success : AppColors.error;
    final vehicle = recolector.vehiculoInfo;
    final isVehicle = recolector.medioTransporte == 'vehiculo';

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    recolector.nombreCompleto,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                const SizedBox(width: 8),
                Chip(
                  label: Text(recolector.estadoActivo ? 'Activo' : 'Inactivo'),
                  backgroundColor: statusColor.withOpacity(0.12),
                  labelStyle: TextStyle(color: statusColor, fontSize: 12),
                  visualDensity: VisualDensity.compact,
                  side: BorderSide.none,
                ),
              ],
            ),
            const SizedBox(height: 10),
            _RecolectorInfoLine(
              icon: Icons.phone_outlined,
              text: recolector.telefono,
            ),
            _RecolectorInfoLine(
              icon: Icons.location_on_outlined,
              text: recolector.zona,
            ),
            _RecolectorInfoLine(
              icon: _transportIcon(recolector.medioTransporte),
              text: _transportLabel(recolector.medioTransporte),
            ),
            if (isVehicle)
              Padding(
                padding: const EdgeInsets.only(left: 28, top: 1),
                child: Text(
                  '${vehicle['placa'] ?? 'Sin placa'} · ${vehicle['marca'] ?? 'Sin marca'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              ),
            _RecolectorInfoLine(
              icon: Icons.work_history_outlined,
              text: '${recolector.aniosExperiencia} años de experiencia',
            ),
            const Spacer(),
            Row(
              children: [
                _StatisticChip(
                  label: '${_formatNumber(recolector.kilosOfertados)} kg',
                  icon: Icons.scale_outlined,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 8),
                _StatisticChip(
                  label: '${recolector.totalOfertas} ofertas',
                  icon: Icons.local_offer_outlined,
                  color: Colors.blue,
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Ver detalle',
                    visualDensity: VisualDensity.compact,
                    onPressed: onDetails,
                    icon: const Icon(Icons.visibility_outlined),
                  ),
                  if (canManage) ...[
                    IconButton(
                      tooltip: 'Editar recolector',
                      visualDensity: VisualDensity.compact,
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_outlined),
                    ),
                    IconButton(
                      tooltip: recolector.estadoActivo
                          ? 'Bloquear recolector'
                          : 'Desbloquear recolector',
                      visualDensity: VisualDensity.compact,
                      onPressed: onToggle,
                      icon: Icon(
                        recolector.estadoActivo
                            ? Icons.lock_outline
                            : Icons.lock_open_outlined,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecolectorInfoLine extends StatelessWidget {
  const _RecolectorInfoLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 17, color: AppColors.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatisticChip extends StatelessWidget {
  const _StatisticChip({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 16, color: color),
      label: Text(label, maxLines: 1),
      backgroundColor: color.withOpacity(0.1),
      labelStyle: TextStyle(color: color, fontSize: 11),
      visualDensity: VisualDensity.compact,
      side: BorderSide.none,
    );
  }
}

IconData _transportIcon(String transport) => switch (transport) {
      'vehiculo' => Icons.directions_car_outlined,
      'bicicleta' => Icons.pedal_bike_outlined,
      _ => Icons.local_shipping_outlined,
    };

String _transportLabel(String transport) => switch (transport) {
      'vehiculo' => 'Vehículo',
      'bicicleta' => 'Bicicleta',
      _ => 'Otro',
    };

String _formatNumber(double value) {
  final rounded = value.round().toString();
  return rounded.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );
}
