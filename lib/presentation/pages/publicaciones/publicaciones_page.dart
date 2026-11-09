import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/admin_auth_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../domain/entities/publicacion_entity.dart';
import '../../../domain/entities/user_entity.dart';
import '../../../domain/repositories/publicacion_repository.dart';
import '../../providers/publicacion_providers.dart';
import '../../providers/material_category_provider.dart';
import '../../providers/user_providers.dart';
import '../../widgets/async_states.dart';
import '../../widgets/category_catalog_notice.dart';
import '../../widgets/scaffold_with_navigation.dart';
import 'widgets/publicacion_card.dart';
import 'widgets/publicacion_detail_dialog.dart';

class PublicacionesPage extends ConsumerStatefulWidget {
  const PublicacionesPage({super.key});

  @override
  ConsumerState<PublicacionesPage> createState() => _PublicacionesPageState();
}

class _PublicacionesPageState extends ConsumerState<PublicacionesPage> {
  static const String _all = 'todos';
  static const int _pageSize = 20;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  Timer? _debounce;
  String _query = '';
  String _status = _all;
  String _category = _all;
  String _activeFilter = 'activas';
  int _pageIndex = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _query = value.trim();
          _pageIndex = 0;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final canModerate = ref.watch(adminPermissionsProvider).canModerate;
    final publicationRepository = ref.watch(publicacionRepositoryProvider);
    final publicationsAsync = _query.isEmpty
        ? ref.watch(publicacionesProvider((
            estado: null,
            categoria: null,
            estadoActivo: null,
          )))
        : ref.watch(publicacionSearchProvider(_query));
    final categoryCatalog =
        ref.watch(materialCategoryCatalogProvider).valueOrNull ??
            MaterialCategoryCatalog.fallback;
    final usersAsync = ref.watch(
      usersProvider((zona: null, estadoActivo: null)),
    );

    return ScaffoldWithNavigation(
      title: 'Publicaciones',
      currentPath: '/publicaciones',
      body: Scaffold(
        appBar: AppBar(
          title: const Text('Publicaciones'),
          actions: [
            IconButton(
              tooltip: 'Buscar publicaciones',
              onPressed: _searchFocus.requestFocus,
              icon: const Icon(Icons.search),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                CategoryCatalogNotice(
                  catalog: categoryCatalog,
                  onSeed: _seedCategoryCatalog,
                ),
                _buildFilters(categoryCatalog),
                const SizedBox(height: 16),
                Expanded(
                  child: publicationsAsync.when(
                    loading: () => const LoadingState(
                      message: 'Cargando publicaciones...',
                    ),
                    error: (error, stackTrace) => _errorState(),
                    data: (publications) => _buildList(
                      publications,
                      usersAsync.valueOrNull ?? const <UserEntity>[],
                      publicationRepository,
                      canModerate,
                      categoryCatalog,
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

  Widget _buildFilters(MaterialCategoryCatalog categoryCatalog) {
    final categories = categoryCatalog.categories;
    if (_category != _all &&
        !categories.any((category) => category.id == _category)) {
      _category = _all;
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
              key: const Key('publicacion_search_field'),
              controller: _searchController,
              focusNode: _searchFocus,
              onChanged: _onSearchChanged,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Buscar por título o descripción...',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          _dropdown(
            label: 'Estado',
            value: _status,
            options: const {
              _all: 'Todas',
              'DISPONIBLE': 'Disponibles',
              'ENTREGADO': 'Entregadas',
              'RESERVADO': 'Reservadas',
              'CANCELADO': 'Canceladas',
            },
            onChanged: (value) => setState(() {
              _status = value;
              _pageIndex = 0;
            }),
          ),
          _dropdown(
            label: 'Categoría',
            value: _category,
            options: {
              _all: 'Todas las categorías',
              for (final category in categories)
                category.id: category.displayName,
            },
            onChanged: (value) => setState(() {
              _category = value;
              _pageIndex = 0;
            }),
          ),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'activas', label: Text('Activas')),
              ButtonSegment(value: 'inactivas', label: Text('Inactivas')),
              ButtonSegment(value: 'todos', label: Text('Todas')),
            ],
            selected: {_activeFilter},
            onSelectionChanged: (selection) => setState(() {
              _activeFilter = selection.first;
              _pageIndex = 0;
            }),
          ),
        ],
      ),
    );
  }

  Widget _dropdown({
    required String label,
    required String value,
    required Map<String, String> options,
    required ValueChanged<String> onChanged,
  }) {
    return SizedBox(
      width: 210,
      child: DropdownButtonFormField<String>(
        value: value,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        items: options.entries
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

  Widget _errorState() => ErrorState(
        message: 'No se pudieron cargar las publicaciones.',
        onRetry: () {
          if (_query.isEmpty) {
            ref.invalidate(publicacionesProvider((
              estado: null,
              categoria: null,
              estadoActivo: null,
            )));
          } else {
            ref.invalidate(publicacionSearchProvider(_query));
          }
        },
      );

  Widget _buildList(
    List<PublicacionEntity> items,
    List<UserEntity> users,
    PublicacionRepository repository,
    bool canModerate,
    MaterialCategoryCatalog categoryCatalog,
  ) {
    final usersById = {for (final user in users) user.uid: user};
    final filtered = items.where((item) {
      final activeMatches = switch (_activeFilter) {
        'activas' => item.estadoActivo,
        'inactivas' => !item.estadoActivo,
        _ => true,
      };
      return activeMatches &&
          (_status == _all || item.estado == _status) &&
          (_category == _all ||
              materialCategoryId(item.categoria, categoryCatalog) == _category);
    }).toList(growable: false);
    if (filtered.isEmpty) {
      return const EmptyState(
        message: 'No hay publicaciones para estos filtros.',
        icon: Icons.inventory_2_outlined,
      );
    }
    final pageCount = (filtered.length + _pageSize - 1) ~/ _pageSize;
    final currentPage = _pageIndex.clamp(0, pageCount - 1);
    final start = currentPage * _pageSize;
    final end = (start + _pageSize).clamp(0, filtered.length);
    final pageItems = filtered.sublist(start, end);

    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            key: const Key('publicaciones_list'),
            padding: const EdgeInsets.only(bottom: 24),
            itemCount: pageItems.length,
            separatorBuilder: (context, index) => const SizedBox(height: 14),
            itemBuilder: (context, index) {
              final item = pageItems[index];
              return PublicacionCard(
                publicacion: item,
                categoryLabel:
                    displayMaterialCategory(item.categoria, categoryCatalog),
                vendedorEmail: usersById[item.userId]?.email ?? '',
                onDetails: () => showDialog<void>(
                  context: context,
                  builder: (context) => PublicacionDetailDialog(
                    publicacion: item,
                    categoryLabel: displayMaterialCategory(
                      item.categoria,
                      categoryCatalog,
                    ),
                    vendedor: usersById[item.userId],
                    ofertas: const [],
                  ),
                ),
                onToggleActive:
                    canModerate ? () => _toggleActive(item, repository) : null,
                onSoftDelete: canModerate
                    ? (id, adminId) => _softDelete(item, repository)
                    : null,
                onMarkSold:
                    canModerate ? () => _markSold(item, repository) : null,
              );
            },
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            IconButton(
              tooltip: 'Página anterior',
              onPressed: currentPage > 0
                  ? () => setState(() => _pageIndex = currentPage - 1)
                  : null,
              icon: const Icon(Icons.chevron_left),
            ),
            Text('Página ${currentPage + 1} de $pageCount'),
            IconButton(
              tooltip: 'Página siguiente',
              onPressed: currentPage + 1 < pageCount
                  ? () => setState(() => _pageIndex = currentPage + 1)
                  : null,
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _softDelete(
    PublicacionEntity item,
    PublicacionRepository repository,
  ) async {
    if (!_requireModerationPermission()) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar publicación'),
        content: Text(
            '¿Deseas eliminar permanentemente la publicación “${item.titulo}”? Esta acción no se puede deshacer y quedará registrada.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!_requireModerationPermission()) return;
    final adminId = FirebaseAuth.instance.currentUser?.uid;
    if (adminId == null) {
      _showMessage('No hay un administrador autenticado.', isError: true);
      return;
    }
    try {
      await repository.softDelete(item.id, adminId);
      if (mounted) {
        _showMessage('Publicación eliminada correctamente.');
      }
    } catch (error) {
      if (mounted) {
        _showMessage('No se pudo eliminar la publicación.', isError: true);
      }
    }
  }

  Future<void> _toggleActive(
    PublicacionEntity item,
    PublicacionRepository repository,
  ) async {
    if (!_requireModerationPermission()) return;

    final action = item.estadoActivo ? 'desactivar' : 'activar';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title:
            Text('${item.estadoActivo ? 'Desactivar' : 'Activar'} publicación'),
        content: Text('¿Deseas $action “${item.titulo}”?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(item.estadoActivo ? 'Desactivar' : 'Activar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!_requireModerationPermission()) return;
    final adminId = FirebaseAuth.instance.currentUser?.uid;
    if (adminId == null) {
      _showMessage('No hay un administrador autenticado.', isError: true);
      return;
    }
    try {
      await repository.toggleActive(item.id, adminId: adminId);
      if (mounted) {
        _showMessage(
          'Publicación ${item.estadoActivo ? 'desactivada' : 'activada'}.',
        );
      }
    } on PublicacionAlreadySold catch (error) {
      if (mounted) {
        _showMessage(error.toString(), isError: true);
      }
    } catch (error, stackTrace) {
      debugPrint(
          'No se pudo cambiar publicación ${item.id}: $error\n$stackTrace');
      if (mounted) {
        _showMessage('No se pudo actualizar la publicación.', isError: true);
      }
    }
  }

  Future<void> _markSold(
    PublicacionEntity item,
    PublicacionRepository repository,
  ) async {
    if (!_requireModerationPermission()) return;
    try {
      await repository.update(item.id, {
        'estado': 'ENTREGADO',
      });
      if (mounted) _showMessage('Publicación marcada como entregada.');
    } catch (error, stackTrace) {
      debugPrint('No se pudo marcar vendida ${item.id}: $error\n$stackTrace');
      if (mounted) {
        _showMessage('No se pudo marcar la publicación como entregada.',
            isError: true);
      }
    }
  }

  bool _requireModerationPermission() {
    if (ref.read(adminPermissionsProvider).canModerate) return true;
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

  Future<void> _seedCategoryCatalog() async {
    try {
      await ref.read(materialCategoryRepositoryProvider).seedOfficialCatalog();
      ref.invalidate(materialCategoryCatalogProvider);
      if (mounted) _showMessage('Catálogo oficial sembrado correctamente.');
    } catch (error, stackTrace) {
      debugPrint(
          'No se pudo sembrar el catálogo de categorías: $error\n$stackTrace');
      if (mounted) {
        _showMessage('No se pudo sembrar el catálogo oficial.', isError: true);
      }
    }
  }
}
