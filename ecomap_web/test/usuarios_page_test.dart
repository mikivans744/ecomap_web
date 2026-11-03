import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ecomap_web/core/auth/admin_auth_state.dart';
import 'package:ecomap_web/core/routing/app_router.dart';
import 'package:ecomap_web/domain/entities/user_entity.dart';
import 'package:ecomap_web/domain/repositories/user_repository.dart';
import 'package:ecomap_web/presentation/pages/usuarios/usuarios_page.dart';
import 'package:ecomap_web/presentation/providers/user_providers.dart';

class _FakeUserRepository implements UserRepository {
  _FakeUserRepository(this.users);

  final List<UserEntity> users;
  String? toggledUserId;

  @override
  Stream<List<UserEntity>> watchAll({String? zona, bool? estadoActivo}) async* {
    yield users
        .where(
            (user) => estadoActivo == null || user.estadoActivo == estadoActivo)
        .where((user) => zona == null || user.zona == zona)
        .toList(growable: false);
  }

  @override
  Stream<UserEntity> watchById(String id) =>
      Stream.value(users.singleWhere((user) => user.uid == id));

  @override
  Future<void> create(UserEntity entity) async {}

  @override
  Future<void> update(String id, Map<String, dynamic> data) async {}

  @override
  Future<void> toggleActive(String id) async {
    toggledUserId = id;
  }

  @override
  Future<List<UserEntity>> search(String query) async {
    final normalized = query.toLowerCase();
    return users
        .where((user) =>
            user.email.toLowerCase().contains(normalized) ||
            user.nombre.toLowerCase().contains(normalized))
        .toList(growable: false);
  }
}

UserEntity _user(int index, {String? name, bool active = true}) {
  return UserEntity(
    uid: 'user-$index',
    email: 'user$index@example.com',
    nombre: name ?? 'Usuario $index',
    rol: 'ciudadano',
    telefono: '+521234567890',
    zona: 'Norte',
    estadoActivo: active,
    reputacion: 4.5,
    totalReciclado: 20,
    fechaRegistro: DateTime(2026, 1, 2),
  );
}

Widget _page(_FakeUserRepository repository) {
  return ProviderScope(
    overrides: [userRepositoryProvider.overrideWithValue(repository)],
    child: const MaterialApp(home: UsuariosPage()),
  );
}

void main() {
  testWidgets('shows the user table and paginates by 20 rows', (tester) async {
    final repository = _FakeUserRepository(
      List<UserEntity>.generate(21, (index) => _user(index)),
    );
    await tester.pumpWidget(_page(repository));
    await tester.pumpAndSettle();

    expect(find.text('Gestión de Usuarios'), findsOneWidget);
    expect(find.text('Página 1 de 2'), findsOneWidget);
    expect(find.text('user0@example.com'), findsOneWidget);
    expect(find.text('user20@example.com'), findsNothing);

    await tester.tap(find.byTooltip('Página siguiente'));
    await tester.pumpAndSettle();

    expect(find.text('Página 2 de 2'), findsOneWidget);
    expect(find.text('user20@example.com'), findsOneWidget);
  });

  testWidgets('debounces search before showing matches', (tester) async {
    final repository = _FakeUserRepository([
      _user(1, name: 'Nombre común'),
      _user(2, name: 'Persona buscada'),
    ]);
    await tester.pumpWidget(_page(repository));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'buscada');
    await tester.pump(const Duration(milliseconds: 299));
    expect(find.text('user1@example.com'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('user2@example.com'), findsOneWidget);
    expect(find.text('user1@example.com'), findsNothing);
  });

  testWidgets('opens user details and confirms blocking', (tester) async {
    final repository = _FakeUserRepository([_user(7)]);
    await tester.pumpWidget(_page(repository));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byTooltip('Ver detalle'));
    await tester.tap(find.byTooltip('Ver detalle'));
    await tester.pumpAndSettle();
    expect(find.text('user7@example.com'), findsNWidgets(2));
    await tester.tap(find.text('Cerrar'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Bloquear usuario'));
    await tester.pumpAndSettle();
    expect(find.text('¿Estás seguro de bloquear a Usuario 7?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Bloquear'));
    await tester.pumpAndSettle();

    expect(repository.toggledUserId, 'user-7');
    expect(
      find.text(
        'Usuario bloqueado. Sus publicaciones se desactivarán automáticamente.',
      ),
      findsOneWidget,
    );
  });

  test('registers the users route for an authenticated admin', () {
    final router = AppRouter(
        authState: const AdminAuthState(
      userId: 'admin-1',
      email: 'admin@example.com',
      isAdmin: true,
    )).router;

    expect(router.namedLocation('users'), '/usuarios');
    router.dispose();
  });
}
