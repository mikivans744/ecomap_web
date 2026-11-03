import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../domain/entities/user_entity.dart';
import '../../../domain/repositories/user_repository.dart';
import '../../providers/user_providers.dart';

class UsuariosPage extends ConsumerStatefulWidget {
  const UsuariosPage({super.key});

  @override
  ConsumerState<UsuariosPage> createState() => _UsuariosPageState();
}

class _UsuariosPageState extends ConsumerState<UsuariosPage> {
  static const int _pageSize = 20;
  static const String _allFilter = 'todos';

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _searchDebounce;
  String _searchQuery = '';
  String _roleFilter = _allFilter;
  String _statusFilter = 'activos';
  int _pageIndex = 0;

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
      setState(() {
        _searchQuery = value.trim();
        _pageIndex = 0;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final repository = ref.watch(userRepositoryProvider);
    final AsyncValue<List<UserEntity>> usersAsync;
    if (_searchQuery.isNotEmpty) {
      usersAsync = ref.watch(userSearchProvider(_searchQuery));
    } else {
      usersAsync = ref.watch(
        usersProvider((
          zona: null,
          estadoActivo: switch (_statusFilter) {
            'activos' => true,
            'inactivos' => false,
            _ => null,
          },
        )),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de Usuarios'),
        actions: [
          IconButton(
            tooltip: 'Buscar usuarios',
            icon: const Icon(Icons.search),
            onPressed: _searchFocusNode.requestFocus,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              _buildFilters(),
              const SizedBox(height: 16),
              Expanded(
                child: usersAsync.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(),
                  ),
                  error: (error, stackTrace) => _buildErrorState(),
                  data: (users) => _buildUserTable(users, repository),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final searchWidth =
            constraints.maxWidth < 700 ? constraints.maxWidth : 340.0;
        return Wrap(
          spacing: 16,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: searchWidth,
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                onChanged: _onSearchChanged,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Buscar por email o nombre...',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            SizedBox(
              width: 220,
              child: DropdownButtonFormField<String>(
                value: _roleFilter,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Rol',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: const [
                  DropdownMenuItem(value: _allFilter, child: Text('Todos')),
                  DropdownMenuItem(
                    value: 'ciudadano',
                    child: Text('Ciudadano'),
                  ),
                  DropdownMenuItem(
                    value: 'recolector',
                    child: Text('Recolector'),
                  ),
                  DropdownMenuItem(
                    value: 'centro_acopio',
                    child: Text('Centro de Acopio'),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _roleFilter = value;
                    _pageIndex = 0;
                  });
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
              onSelectionChanged: (selection) {
                setState(() {
                  _statusFilter = selection.first;
                  _pageIndex = 0;
                });
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_outlined,
              color: AppColors.error, size: 40),
          const SizedBox(height: 12),
          const Text('No se pudieron cargar los usuarios.'),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () {
              if (_searchQuery.isNotEmpty) {
                ref.invalidate(userSearchProvider(_searchQuery));
              } else {
                ref.invalidate(usersProvider((
                  zona: null,
                  estadoActivo: switch (_statusFilter) {
                    'activos' => true,
                    'inactivos' => false,
                    _ => null,
                  },
                )));
              }
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }

  Widget _buildUserTable(List<UserEntity> users, UserRepository repository) {
    final filteredUsers = users.where((user) {
      final matchesRole = _roleFilter == _allFilter || user.rol == _roleFilter;
      final matchesStatus = switch (_statusFilter) {
        'activos' => user.estadoActivo,
        'inactivos' => !user.estadoActivo,
        _ => true,
      };
      return matchesRole && matchesStatus;
    }).toList(growable: false);

    final pageCount = filteredUsers.isEmpty
        ? 1
        : (filteredUsers.length + _pageSize - 1) ~/ _pageSize;
    final currentPage = _pageIndex.clamp(0, pageCount - 1);
    final start = currentPage * _pageSize;
    final end = (start + _pageSize).clamp(0, filteredUsers.length);
    final pageUsers = filteredUsers.sublist(start, end);

    if (filteredUsers.isEmpty) {
      return const Center(child: Text('No hay usuarios para estos filtros.'));
    }

    return Column(
      children: [
        Expanded(
          child: Card(
            clipBehavior: Clip.antiAlias,
            child: SingleChildScrollView(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columnSpacing: 18,
                  headingRowColor: const WidgetStatePropertyAll(
                    AppColors.surfaceVariant,
                  ),
                  columns: const [
                    DataColumn(
                        label: SizedBox(width: 200, child: Text('Email'))),
                    DataColumn(
                        label: SizedBox(width: 150, child: Text('Nombre'))),
                    DataColumn(label: SizedBox(width: 120, child: Text('Rol'))),
                    DataColumn(
                        label: SizedBox(width: 100, child: Text('Zona'))),
                    DataColumn(
                      label: SizedBox(width: 100, child: Text('Reputación')),
                    ),
                    DataColumn(
                        label: SizedBox(width: 100, child: Text('Estado'))),
                    DataColumn(
                      label:
                          SizedBox(width: 120, child: Text('Fecha Registro')),
                    ),
                    DataColumn(
                        label: SizedBox(width: 150, child: Text('Acciones'))),
                  ],
                  rows: pageUsers
                      .map(
                        (user) => DataRow(
                          key: ValueKey('user_row_${user.uid}'),
                          cells: [
                            DataCell(_ellipsizedCell(user.email, 200)),
                            DataCell(_ellipsizedCell(user.nombre, 150)),
                            DataCell(_roleChip(user.rol)),
                            DataCell(_ellipsizedCell(user.zona, 100)),
                            DataCell(
                              SizedBox(
                                width: 100,
                                child: Text(
                                  '${user.reputacion.toStringAsFixed(1)} ★',
                                  maxLines: 1,
                                ),
                              ),
                            ),
                            DataCell(_statusChip(user.estadoActivo)),
                            DataCell(
                              SizedBox(
                                width: 120,
                                child: Text(_formatDate(user.fechaRegistro)),
                              ),
                            ),
                            DataCell(
                              SizedBox(
                                width: 150,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      tooltip: 'Ver detalle',
                                      visualDensity: VisualDensity.compact,
                                      onPressed: () => _showUserDetails(user),
                                      icon:
                                          const Icon(Icons.visibility_outlined),
                                    ),
                                    IconButton(
                                      tooltip: user.estadoActivo
                                          ? 'Bloquear usuario'
                                          : 'Desbloquear usuario',
                                      visualDensity: VisualDensity.compact,
                                      onPressed: () => _confirmToggleActive(
                                        user,
                                        repository,
                                      ),
                                      icon: Icon(
                                        user.estadoActivo
                                            ? Icons.lock_outline
                                            : Icons.lock_open_outlined,
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Enviar recuperación',
                                      visualDensity: VisualDensity.compact,
                                      onPressed: () =>
                                          _confirmPasswordReset(user),
                                      icon: const Icon(Icons.password),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                      .toList(growable: false),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
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

  Widget _ellipsizedCell(String value, double width) {
    return SizedBox(
      width: width,
      child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }

  Widget _roleChip(String role) {
    final (label, color) = switch (role) {
      'ciudadano' => ('Ciudadano', Colors.blue),
      'recolector' => ('Recolector', AppColors.primary),
      'centro_acopio' => ('Centro de Acopio', AppColors.warning),
      _ => (role, AppColors.textSecondary),
    };
    return SizedBox(
      width: 120,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Chip(
          label: Text(label, overflow: TextOverflow.ellipsis),
          backgroundColor: color.withOpacity(0.12),
          labelStyle: TextStyle(color: color, fontSize: 12),
          visualDensity: VisualDensity.compact,
          side: BorderSide.none,
        ),
      ),
    );
  }

  Widget _statusChip(bool isActive) {
    final color = isActive ? AppColors.success : AppColors.error;
    return SizedBox(
      width: 100,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Chip(
          label: Text(isActive ? 'Activo' : 'Inactivo'),
          backgroundColor: color.withOpacity(0.12),
          labelStyle: TextStyle(color: color, fontSize: 12),
          visualDensity: VisualDensity.compact,
          side: BorderSide.none,
        ),
      ),
    );
  }

  Future<void> _showUserDetails(UserEntity user) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(user.nombre.isEmpty ? 'Detalle del usuario' : user.nombre),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _detailRow('Email', user.email),
                _detailRow('Nombre', user.nombre),
                _detailRow('Rol', _roleLabel(user.rol)),
                _detailRow('Teléfono', user.telefono),
                _detailRow('Zona', user.zona),
                _detailRow(
                    'Reputación', '${user.reputacion.toStringAsFixed(1)} ★'),
                _detailRow('Total reciclado', '${user.totalReciclado} kg'),
                _detailRow('Fecha registro', _formatDate(user.fechaRegistro)),
                _detailRow('Estado', user.estadoActivo ? 'Activo' : 'Inactivo'),
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

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
          Expanded(child: Text(value.isEmpty ? 'No especificado' : value)),
        ],
      ),
    );
  }

  Future<void> _confirmToggleActive(
    UserEntity user,
    UserRepository repository,
  ) async {
    final action = user.estadoActivo ? 'bloquear' : 'desbloquear';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title:
            Text('${user.estadoActivo ? 'Bloquear' : 'Desbloquear'} usuario'),
        content: Text('¿Estás seguro de $action a ${user.nombre}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(user.estadoActivo ? 'Bloquear' : 'Desbloquear'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      debugPrint(
          '${user.estadoActivo ? 'Bloqueando' : 'Desbloqueando'} usuario: ${user.uid}');
      await repository.toggleActive(user.uid);
      if (!mounted) return;
      _showMessage(
        user.estadoActivo
            ? 'Usuario bloqueado. Sus publicaciones se desactivarán automáticamente.'
            : 'Usuario desbloqueado exitosamente.',
      );
    } catch (error, stackTrace) {
      debugPrint(
          'No se pudo cambiar el estado de ${user.uid}: $error\n$stackTrace');
      if (mounted) {
        _showMessage(
          error is StateError
              ? error.message.toString()
              : 'No se pudo actualizar el estado del usuario.',
          isError: true,
        );
      }
    }
  }

  Future<void> _confirmPasswordReset(UserEntity user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restablecer contraseña'),
        content: Text(
          '¿Enviar email de recuperación de contraseña a ${user.email}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Enviar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: user.email.trim(),
      );
      if (mounted) {
        _showMessage('Email de recuperación enviado a ${user.email}.');
      }
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      final message = switch (error.code) {
        'user-not-found' => 'No existe una cuenta con ese correo electrónico.',
        'invalid-email' => 'El correo electrónico del usuario no es válido.',
        _ => 'No se pudo enviar el email de recuperación.',
      };
      _showMessage(message, isError: true);
    } catch (error, stackTrace) {
      debugPrint(
          'Error al enviar recuperación para ${user.uid}: $error\n$stackTrace');
      if (mounted) _showMessage('No se pudo enviar el email de recuperación.');
    }
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

String _roleLabel(String role) => switch (role) {
      'ciudadano' => 'Ciudadano',
      'recolector' => 'Recolector',
      'centro_acopio' => 'Centro de Acopio',
      _ => role,
    };

String _formatDate(DateTime date) => '${date.day.toString().padLeft(2, '0')}/'
    '${date.month.toString().padLeft(2, '0')}/'
    '${date.year.toString().padLeft(4, '0')}';
