import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/admin_auth_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../domain/entities/centro_acopio_entity.dart';
import '../../../domain/repositories/centro_acopio_repository.dart';
import '../../providers/centro_acopio_providers.dart';
import '../../widgets/async_states.dart';
import '../../widgets/scaffold_with_navigation.dart';
import 'widgets/centro_form_dialog.dart';

class CentrosPage extends ConsumerStatefulWidget {
  const CentrosPage({super.key});

  @override
  ConsumerState<CentrosPage> createState() => _CentrosPageState();
}

class _CentrosPageState extends ConsumerState<CentrosPage> {
  static const String _allFilter = 'todos';
  static const List<({String id, String label})> _knownMaterials = [
    (id: 'plastico', label: 'Plástico'),
    (id: 'vidrio', label: 'Vidrio'),
    (id: 'metal', label: 'Metal'),
    (id: 'papel', label: 'Papel/Cartón'),
    (id: 'organico', label: 'Orgánico'),
    (id: 'textil', label: 'Textil'),
    (id: 'electronico', label: 'Electrónico'),
    (id: 'otro', label: 'Otro'),
  ];

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _searchDebounce;
  String _searchQuery = '';
  String _materialFilter = _allFilter;
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
      if (mounted) setState(() => _searchQuery = value.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final canManageCentros =
        ref.watch(adminPermissionsProvider).canManageCentros;
    final repository = ref.watch(centroAcopioRepositoryProvider);
    final allCenters = ref.watch(
      centrosAcopioProvider((zona: null, estadoActivo: null)),
    );
    final AsyncValue<List<CentroAcopioEntity>> centers = _searchQuery.isEmpty
        ? allCenters
        : ref.watch(centroAcopioSearchProvider(_searchQuery));

    return ScaffoldWithNavigation(
      title: 'Centros de Acopio',
      currentPath: '/centros',
      body: Scaffold(
        appBar: AppBar(
          title: const Text('Centros de Acopio'),
          actions: [
            IconButton(
              tooltip: 'Buscar centros',
              onPressed: _searchFocusNode.requestFocus,
              icon: const Icon(Icons.search),
            ),
            if (canManageCentros)
              IconButton(
                tooltip: 'Nuevo centro',
                onPressed: () => _openForm(repository),
                icon: const Icon(Icons.add),
              ),
            const SizedBox(width: 8),
          ],
        ),
        floatingActionButton: canManageCentros
            ? FloatingActionButton.extended(
                key: const Key('add_centro_button'),
                tooltip: 'Nuevo centro de acopio',
                onPressed: () => _openForm(repository),
                icon: const Icon(Icons.add),
                label: const Text('Nuevo centro'),
              )
            : null,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _buildFilters(allCenters),
                const SizedBox(height: 16),
                Expanded(
                  child: centers.when(
                    loading: () => const LoadingState(
                      message: 'Cargando centros de acopio...',
                    ),
                    error: (error, stackTrace) => _buildErrorState(),
                    data: (items) => _buildCenterList(
                      items,
                      repository,
                      canManageCentros,
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

  Widget _buildFilters(AsyncValue<List<CentroAcopioEntity>> allCenters) {
    final storedMaterials = allCenters.maybeWhen(
      data: (centers) => centers
          .expand((center) => center.materialesAceptados)
          .toSet()
          .toList()
        ..sort(),
      orElse: () => <String>[],
    );
    final knownIds = _knownMaterials.map((material) => material.id).toSet();
    final materials = <String>{...knownIds, ...storedMaterials}.toList()
      ..sort();
    if (_materialFilter != _allFilter && !materials.contains(_materialFilter)) {
      _materialFilter = _allFilter;
    }

    return LayoutBuilder(
      builder: (context, constraints) => Wrap(
        spacing: 16,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: constraints.maxWidth < 640 ? constraints.maxWidth : 360,
            child: TextField(
              key: const Key('centro_search_field'),
              controller: _searchController,
              focusNode: _searchFocusNode,
              onChanged: _onSearchChanged,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Buscar por nombre, responsable o dirección...',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          SizedBox(
            width: 230,
            child: DropdownButtonFormField<String>(
              value: _materialFilter,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Material',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: [
                const DropdownMenuItem(
                  value: _allFilter,
                  child: Text('Todos los materiales'),
                ),
                ...materials.map(
                  (material) => DropdownMenuItem(
                    value: material,
                    child: Text(_materialLabel(material)),
                  ),
                ),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _materialFilter = value);
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
            onSelectionChanged: (selection) =>
                setState(() => _statusFilter = selection.first),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return ErrorState(
      message: 'No se pudieron cargar los centros de acopio.',
      onRetry: () {
        if (_searchQuery.isNotEmpty) {
          ref.invalidate(centroAcopioSearchProvider(_searchQuery));
        } else {
          ref.invalidate(
            centrosAcopioProvider((zona: null, estadoActivo: null)),
          );
        }
      },
    );
  }

  Widget _buildCenterList(
    List<CentroAcopioEntity> centers,
    CentroAcopioRepository repository,
    bool canManageCentros,
  ) {
    final filtered = centers.where((center) {
      final matchesMaterial = _materialFilter == _allFilter ||
          center.materialesAceptados.contains(_materialFilter);
      final matchesStatus = switch (_statusFilter) {
        'activos' => center.estadoActivo,
        'inactivos' => !center.estadoActivo,
        _ => true,
      };
      return matchesMaterial && matchesStatus;
    }).toList(growable: false);

    if (filtered.isEmpty) {
      return const EmptyState(message: 'No hay centros para estos filtros.');
    }

    return ListView.separated(
      key: const Key('centros_list'),
      padding: const EdgeInsets.only(bottom: 88),
      itemCount: filtered.length,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) => _CentroCard(
        centro: filtered[index],
        onDetails: () => _showDetails(filtered[index], repository),
        onEdit: () => _openForm(repository, centro: filtered[index]),
        onToggle: () => _toggleCenter(filtered[index], repository),
        canManage: canManageCentros,
      ),
    );
  }

  Future<void> _openForm(
    CentroAcopioRepository repository, {
    CentroAcopioEntity? centro,
  }) async {
    if (!_requireCentroPermission()) return;

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => CentroFormDialog(
        repository: repository,
        centro: centro,
      ),
    );
    if (saved == true && mounted) {
      ref.invalidate(centrosAcopioProvider((zona: null, estadoActivo: null)));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            centro == null
                ? 'Centro creado exitosamente.'
                : 'Centro actualizado exitosamente.',
          ),
        ),
      );
    }
  }

  Future<void> _showDetails(
    CentroAcopioEntity center,
    CentroAcopioRepository repository,
  ) async {
    final activeOffersFuture = repository.getActiveOffers(center.id);
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(center.nombre),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _detailLine(
                    Icons.person_outline, 'Responsable: ${center.responsable}'),
                _detailLine(
                    Icons.phone_outlined, 'Teléfono: ${center.telefono}'),
                _detailLine(Icons.location_on_outlined,
                    'Dirección: ${center.direccion}'),
                _detailLine(Icons.map_outlined,
                    'Zona: ${center.zona ?? 'No especificada'}'),
                _detailLine(
                    Icons.schedule_outlined, 'Horario: ${center.horario}'),
                const SizedBox(height: 12),
                const Text('Materiales aceptados'),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: center.materialesAceptados
                      .map((material) => _MaterialChip(material: material))
                      .toList(growable: false),
                ),
                const SizedBox(height: 16),
                _CapacityIndicator(center: center),
                const SizedBox(height: 16),
                Text('Estadísticas',
                    style: Theme.of(context).textTheme.titleSmall),
                Text('Ofertas históricas: ${center.totalOfertas}'),
                Text(
                    'Kilos comprometidos: ${_formatKg(center.kilosComprometidos)} kg'),
                const SizedBox(height: 16),
                Text('Ofertas activas',
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 6),
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: activeOffersFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return const Text(
                          'No se pudieron cargar las ofertas activas.');
                    }
                    final offers = snapshot.data ?? const [];
                    if (offers.isEmpty) {
                      return const Text('No hay ofertas activas.');
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: offers.take(10).map((offer) {
                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.local_offer_outlined),
                          title: Text(
                              '${offer['categoria'] ?? 'Oferta'} · ${offer['pesoKg'] ?? 0} kg'),
                          subtitle: Text(
                              'Recolector: ${offer['recolectorId'] ?? 'No especificado'} · ${offer['estado'] ?? ''}'),
                        );
                      }).toList(growable: false),
                    );
                  },
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
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: AppColors.textSecondary),
            const SizedBox(width: 10),
            Expanded(child: Text(value)),
          ],
        ),
      );

  Future<void> _toggleCenter(
    CentroAcopioEntity center,
    CentroAcopioRepository repository,
  ) async {
    if (!_requireCentroPermission()) return;

    final isDeactivating = center.estadoActivo;
    if (isDeactivating) {
      try {
        final offers = await repository.getActiveOffers(center.id);
        if (!mounted) return;
        if (offers.isNotEmpty) {
          await _showActiveOffersBlockDialog(center, offers);
          return;
        }
      } catch (error, stackTrace) {
        debugPrint(
            'No se pudieron verificar ofertas del centro ${center.id}: $error\n$stackTrace');
        if (mounted) {
          _showMessage(
            'No se pudieron verificar las ofertas activas. Intenta nuevamente.',
            isError: true,
          );
        }
        return;
      }
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isDeactivating ? 'Desactivar centro' : 'Activar centro'),
        content: Text(
          isDeactivating
              ? '¿Estás seguro de desactivar el centro ${center.nombre}?\n\n'
                  'Esta acción:\n'
                  '- No permitirá nuevas ofertas\n'
                  '- Mantiene el historial de ofertas anteriores'
              : '¿Estás seguro de activar el centro ${center.nombre}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(isDeactivating ? 'Desactivar' : 'Activar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!_requireCentroPermission()) return;

    try {
      await repository.toggleActive(center.id);
      if (mounted) {
        _showMessage(
          'Centro ${isDeactivating ? 'desactivado' : 'activado'} exitosamente.',
        );
      }
    } on CentroAcopioHasActiveOffers catch (error) {
      try {
        final activeOffers = await repository.getActiveOffers(center.id);
        if (!mounted) return;
        if (activeOffers.isEmpty) {
          _showMessage(
            'Las ofertas del centro cambiaron. Actualiza y vuelve a intentarlo.',
            isError: true,
          );
        } else {
          await _showActiveOffersBlockDialog(center, activeOffers);
        }
      } catch (refreshError, stackTrace) {
        debugPrint(
          'No se pudieron recargar las ofertas de ${center.id}: '
          '$refreshError\n$stackTrace (conteo inicial: ${error.offerCount})',
        );
        if (mounted) {
          _showMessage(
            'No se pudieron verificar las ofertas activas.',
            isError: true,
          );
        }
      }
    } catch (error, stackTrace) {
      debugPrint(
          'No se pudo cambiar el estado del centro ${center.id}: $error\n$stackTrace');
      if (mounted) {
        _showMessage(
          'No se pudo actualizar el centro. Intenta nuevamente.',
          isError: true,
        );
      }
    }
  }

  bool _requireCentroPermission() {
    if (ref.read(adminPermissionsProvider).canManageCentros) return true;
    _showMessage('Sin permisos', isError: true);
    return false;
  }

  Future<void> _showActiveOffersBlockDialog(
    CentroAcopioEntity center,
    List<Map<String, dynamic>> offers,
  ) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('No se puede desactivar el centro'),
        content: Text(
          'No se puede desactivar este centro porque tiene ${offers.length} ofertas activas.\n\n'
          'Primero debes cancelar o finalizar estas ofertas antes de desactivar el centro.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _showOffersModal(center, offers);
            },
            child: const Text('Ver ofertas'),
          ),
        ],
      ),
    );
  }

  Future<void> _showOffersModal(
    CentroAcopioEntity center,
    List<Map<String, dynamic>> offers,
  ) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Ofertas activas · ${center.nombre}'),
        content: SizedBox(
          width: 480,
          child: offers.isEmpty
              ? const Text('No hay ofertas activas.')
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: offers.length,
                  itemBuilder: (context, index) {
                    final offer = offers[index];
                    return ListTile(
                      leading: const Icon(Icons.local_offer_outlined),
                      title: Text(
                          '${offer['categoria'] ?? 'Oferta'} · ${offer['pesoKg'] ?? 0} kg'),
                      subtitle: Text(
                          '${offer['estado'] ?? ''} · Recolector ${offer['recolectorId'] ?? ''}'),
                    );
                  },
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

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? AppColors.error : null,
        ),
      );
  }
}

class _CentroCard extends StatelessWidget {
  const _CentroCard({
    required this.centro,
    required this.onDetails,
    required this.onEdit,
    required this.onToggle,
    required this.canManage,
  });

  final CentroAcopioEntity centro;
  final VoidCallback onDetails;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final bool canManage;

  @override
  Widget build(BuildContext context) {
    final statusColor =
        centro.estadoActivo ? AppColors.success : AppColors.error;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    centro.nombre,
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
                  label: Text(centro.estadoActivo ? 'Activo' : 'Inactivo'),
                  backgroundColor: statusColor.withOpacity(0.12),
                  labelStyle: TextStyle(color: statusColor),
                  visualDensity: VisualDensity.compact,
                  side: BorderSide.none,
                ),
              ],
            ),
            const SizedBox(height: 8),
            _CentroInfoLine(
                icon: Icons.person_outline, text: centro.responsable),
            _CentroInfoLine(icon: Icons.phone_outlined, text: centro.telefono),
            _CentroInfoLine(
                icon: Icons.location_on_outlined, text: centro.direccion),
            _CentroInfoLine(
                icon: Icons.schedule_outlined, text: centro.horario),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 2,
              children: centro.materialesAceptados
                  .map((material) => _MaterialChip(material: material))
                  .toList(growable: false),
            ),
            const SizedBox(height: 10),
            _CapacityIndicator(center: centro),
            const Divider(height: 20),
            Row(
              children: [
                Chip(
                  avatar: const Icon(Icons.local_offer_outlined, size: 16),
                  label: Text('${centro.totalOfertas} ofertas'),
                  backgroundColor: Colors.blue.withOpacity(0.1),
                  labelStyle: const TextStyle(color: Colors.blue),
                  visualDensity: VisualDensity.compact,
                  side: BorderSide.none,
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Ver detalle',
                  visualDensity: VisualDensity.compact,
                  onPressed: onDetails,
                  icon: const Icon(Icons.visibility_outlined),
                ),
                if (canManage) ...[
                  IconButton(
                    tooltip: 'Editar centro',
                    visualDensity: VisualDensity.compact,
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  IconButton(
                    tooltip: centro.estadoActivo
                        ? 'Desactivar centro'
                        : 'Activar centro',
                    visualDensity: VisualDensity.compact,
                    onPressed: onToggle,
                    icon: Icon(
                      centro.estadoActivo
                          ? Icons.lock_outline
                          : Icons.lock_open_outlined,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CentroInfoLine extends StatelessWidget {
  const _CentroInfoLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
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

class _MaterialChip extends StatelessWidget {
  const _MaterialChip({required this.material});

  final String material;

  @override
  Widget build(BuildContext context) {
    final color = _materialColor(material);
    return Chip(
      label: Text(_materialLabel(material)),
      backgroundColor: color.withOpacity(0.12),
      labelStyle: TextStyle(color: color, fontSize: 11),
      visualDensity: VisualDensity.compact,
      side: BorderSide.none,
    );
  }
}

class _CapacityIndicator extends StatelessWidget {
  const _CapacityIndicator({required this.center});

  final CentroAcopioEntity center;

  @override
  Widget build(BuildContext context) {
    final ratio = center.capacidadMaxima <= 0
        ? 0.0
        : (center.kilosComprometidos / center.capacidadMaxima)
            .clamp(0.0, 1.0)
            .toDouble();
    final color = ratio >= 0.9
        ? AppColors.error
        : ratio >= 0.7
            ? AppColors.warning
            : AppColors.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Capacidad: ${_formatKg(center.kilosComprometidos)} kg / ${_formatKg(center.capacidadMaxima)} kg',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 6),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: ratio),
          duration: const Duration(milliseconds: 450),
          builder: (context, value, child) => LinearProgressIndicator(
            value: value,
            minHeight: 8,
            borderRadius: BorderRadius.circular(8),
            color: color,
            backgroundColor: AppColors.surfaceVariant,
          ),
        ),
      ],
    );
  }
}

String _materialLabel(String material) {
  for (final entry in _CentroFormMaterial.labels.entries) {
    if (entry.key == material) return entry.value;
  }
  return material;
}

Color _materialColor(String material) => switch (material) {
      'plastico' => Colors.blue,
      'vidrio' => Colors.lightGreen,
      'metal' => Colors.blueGrey,
      'papel' => Colors.brown,
      'organico' => AppColors.primaryDark,
      'textil' => Colors.deepPurple,
      'electronico' => AppColors.warning,
      _ => Colors.grey.shade800,
    };

String _formatKg(double value) => value == value.roundToDouble()
    ? value.toStringAsFixed(0)
    : value.toStringAsFixed(1);

abstract final class _CentroFormMaterial {
  static const labels = <String, String>{
    'plastico': 'Plástico',
    'vidrio': 'Vidrio',
    'metal': 'Metal',
    'papel': 'Papel/Cartón',
    'organico': 'Orgánico',
    'textil': 'Textil',
    'electronico': 'Electrónico',
    'otro': 'Otro',
  };
}
