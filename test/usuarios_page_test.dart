import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ecomap_web/core/auth/admin_auth_provider.dart';
import 'package:ecomap_web/core/auth/admin_auth_state.dart';
import 'package:ecomap_web/core/constants/route_names.dart';
import 'package:ecomap_web/core/routing/app_router.dart';
import 'package:ecomap_web/domain/entities/user_entity.dart';
import 'package:ecomap_web/domain/repositories/user_repository.dart';
import 'package:ecomap_web/presentation/pages/usuarios/usuarios_page.dart';
import 'package:ecomap_web/presentation/providers/user_providers.dart';

class _FakeUserRepository implements UserRepository {
  _FakeUserRepository(this.users);

  final List<UserEntity> users;
  String? toggledUserId;
  String? adjustedUserId;
  double? adjustedReputation;
  int? adjustedPointsDelta;
  String? adjustmentReason;

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
  Future<void> adjustReputationPoints(
    String id, {
    double? reputation,
    int? pointsDelta,
    required String reason,
  }) async {
    adjustedUserId = id;
    adjustedReputation = reputation;
    adjustedPointsDelta = pointsDelta;
    adjustmentReason = reason;
  }

  @override
  Future<void> toggleActive(String id) async {
    toggledUserId = id;
    final index = users.indexWhere((user) => user.uid == id);
    if (index >= 0) {
      final user = users[index];
      users[index] = UserEntity(
        uid: user.uid,
        email: user.email,
        nombre: user.nombre,
        rol: user.rol,
        telefono: user.telefono,
        zona: user.zona,
        estadoActivo: !user.estadoActivo,
        reputacion: user.reputacion,
        totalReciclado: user.totalReciclado,
        fechaRegistro: user.fechaRegistro,
      );
    }
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

UserEntity _user(
  int index, {
  String? name,
  String role = 'ciudadano',
  bool active = true,
}) {
  return UserEntity(
    uid: 'user-$index',
    email: 'user$index@example.com',
    nombre: name ?? 'Usuario $index',
    rol: role,
    telefono: '+521234567890',
    zona: 'Norte',
    estadoActivo: active,
    reputacion: 4.5,
    totalReciclado: 20,
    fechaRegistro: DateTime(2026, 1, 2),
  );
}

Widget _page(
  _FakeUserRepository repository, {
  AdminPermissions permissions = const AdminPermissions(),
}) {
  return ProviderScope(
    overrides: [
      userRepositoryProvider.overrideWithValue(repository),
      adminPermissionsProvider.overrideWithValue(permissions),
    ],
    child: const MaterialApp(home: UsuariosPage()),
  );
}

void main() {
  testWidgets('shows the user table and paginates by 20 rows', (tester) async {
    tester.view.physicalSize = const Size(1440, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _FakeUserRepository(
      List<UserEntity>.generate(21, (index) => _user(index)),
    );
    await tester.pumpWidget(_page(repository));
    await tester.pumpAndSettle();

    expect(find.text('Gestión de Usuarios'), findsWidgets);
    expect(find.text('Página 1 de 2'), findsOneWidget);
    expect(find.text('user0@example.com'), findsOneWidget);
    expect(find.text('user20@example.com'), findsNothing);

    await tester.tap(find.byTooltip('Página siguiente'));
    await tester.pumpAndSettle();

    expect(find.text('Página 2 de 2'), findsOneWidget);
    expect(find.text('user20@example.com'), findsOneWidget);
  });

  testWidgets('shows full role names and the correct active status',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _page(_FakeUserRepository([
        _user(1, role: 'CENTRO_ACOPIO'),
      ])),
    );
    await tester.pumpAndSettle();

    expect(find.text('CENTRO_ACOPIO'), findsOneWidget);
    expect(find.text('Activo'), findsOneWidget);
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
    tester.view.physicalSize = const Size(1440, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

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
    expect(find.text('Usuario bloqueado exitosamente.'), findsOneWidget);

    await tester.tap(find.text('Inactivos'));
    await tester.pumpAndSettle();
    expect(find.text('Usuario 7'), findsOneWidget);
    expect(find.text('Inactivo'), findsOneWidget);
  });

  testWidgets('hides user actions without user management permission',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _FakeUserRepository([_user(8)]);
    await tester.pumpWidget(
      _page(repository,
          permissions: const AdminPermissions(manageUsers: false)),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('Bloquear usuario'), findsNothing);
    expect(find.byTooltip('Enviar recuperación'), findsNothing);

    expect(repository.toggledUserId, isNull);
  });

  testWidgets('records point adjustments with the required reason',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _FakeUserRepository([_user(9)]);
    await tester.pumpWidget(_page(repository));
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byTooltip('Ajustar reputación/puntos'),
    );
    await tester.tap(find.byTooltip('Ajustar reputación/puntos'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Puntos').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('user_adjustment_value')),
      '-3',
    );
    await tester.enterText(
      find.byKey(const Key('user_adjustment_reason')),
      'Corrección de puntos',
    );
    await tester.tap(find.text('Guardar ajuste'));
    await tester.pumpAndSettle();

    expect(repository.adjustedUserId, 'user-9');
    expect(repository.adjustedReputation, isNull);
    expect(repository.adjustedPointsDelta, -3);
    expect(repository.adjustmentReason, 'Corrección de puntos');
  });

  test('registers the users route for an authenticated admin', () {
    final container = ProviderContainer(
      overrides: [
        isAdminProvider.overrideWith(
          (ref) => Stream.value(
            const AdminAuthState.authenticated(
              uid: 'admin-1',
              email: 'admin@example.com',
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    final router = container.read(appRouterProvider);
    router.go(RouteNames.usuarios);

    expect(router.routeInformationProvider.value.uri.path, RouteNames.usuarios);
  });
}
