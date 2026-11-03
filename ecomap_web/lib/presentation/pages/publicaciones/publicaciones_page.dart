import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../domain/entities/oferta_entity.dart';
import '../../../domain/entities/publicacion_entity.dart';
import '../../../domain/entities/user_entity.dart';
import '../../../domain/repositories/publicacion_repository.dart';
import '../../providers/oferta_providers.dart';
import '../../providers/publicacion_providers.dart';
import '../../providers/user_providers.dart';
import 'widgets/publicacion_card.dart';
import 'widgets/publicacion_detail_dialog.dart';

class PublicacionesPage extends ConsumerStatefulWidget {
  const PublicacionesPage({super.key});

  @override
  ConsumerState<PublicacionesPage> createState() => _PublicacionesPageState();
}

class _PublicacionesPageState extends ConsumerState<PublicacionesPage> {
  static const String _all = 'todos';
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  Timer? _debounce;
  String _query = '';
  String _status = _all;
  String _category = _all;
  String _activeFilter = 'activas';

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
      if (mounted) setState(() => _query = value.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final publicationRepository = ref.watch(publicacionRepositoryProvider);
    final publicationsAsync = _query.isEmpty
        ? ref.watch(publicacionesProvider((
            estado: null,
            categoria: null,
            estadoActivo: null,
          )))
        : ref.watch(publicacionSearchProvider(_query));
    final usersAsync = ref.watch(
      usersProvider((zona: null, estadoActivo: null)),
    );
    final offersAsync = ref.watch(ofertasProvider((
      estado: null,
      centroId: null,
      recolectorId: null,
      desde: null,
      hasta: null,
    )));

    return Scaffold(
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
              _buildFilters(publicationsAsync),
              const SizedBox(height: 16),
              Expanded(
                child: publicationsAsync.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(),
                  ),
                  error: (error, stackTrace) => _errorState(),
                  data: (publications) => _buildList(
                    publications,
                    usersAsync.valueOrNull ?? const <UserEntity>[],
                    offersAsync.valueOrNull ?? const <OfertaEntity>[],
                    publicationRepository,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilters(AsyncValue<List<PublicacionEntity>> publications) {
    final categories = publications.maybeWhen(
      data: (items) =>
          items.map((item) => item.categoria).toSet().toList()..sort(),
      orElse: () => <String>[],
    );
    if (_category != _all && !categories.contains(_category)) {
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
              'disponible': 'Disponibles',
              'vendido': 'Vendidas',
              'reservado': 'Reservadas',
            },
            onChanged: (value) => setState(() => _status = value),
          ),
          _dropdown(
            label: 'Categoría',
            value: _category,
            options: {
              _all: 'Todas las categorías',
              for (final category in categories) category: category,
            },
            onChanged: (value) => setState(() => _category = value),
          ),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'activas', label: Text('Activas')),
              ButtonSegment(value: 'inactivas', label: Text('Inactivas')),
              ButtonSegment(value: 'todos', label: Text('Todas')),
            ],
            selected: {_activeFilter},
            onSelectionChanged: (selection) =>
                setState(() => _activeFilter = selection.first),
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

  Widget _errorState() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined,
                color: AppColors.error, size: 40),
            const SizedBox(height: 12),
            const Text('No se pudieron cargar las publicaciones.'),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () {
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
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      );

  Widget _buildList(
    List<PublicacionEntity> items,
    List<UserEntity> users,
    List<OfertaEntity> offers,
    PublicacionRepository repository,
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
          (_category == _all || item.categoria == _category);
    }).toList(growable: false);
    if (filtered.isEmpty) {
      return const Center(
          child: Text('No hay publicaciones para estos filtros.'));
    }
    return ListView.separated(
      key: const Key('publicaciones_list'),
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: filtered.length,
      separatorBuilder: (context, index) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        final item = filtered[index];
        return PublicacionCard(
          publicacion: item,
          vendedorEmail: usersById[item.userId]?.email ?? '',
          onDetails: () => showDialog<void>(
            context: context,
            builder: (context) => PublicacionDetailDialog(
              publicacion: item,
              onToggleActive: () {
                Navigator.pop(context);
                _toggleActive(item, repository);
              },
              vendedor: usersById[item.userId],
              ofertas: offers
                  .where((offer) => offer.publicacionId == item.id)
                  .toList(growable: false),
            ),
          ),
          onToggleActive: () => _toggleActive(item, repository),
        );
      },
    );
  }

  Future<void> _toggleActive(
    PublicacionEntity item,
    PublicacionRepository repository,
  ) async {
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
    try {
      await repository.toggleActive(
        item.id,
        adminId: FirebaseAuth.instance.currentUser?.uid,
      );
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

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : null,
      ));
  }
}
