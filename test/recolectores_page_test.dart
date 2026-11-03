import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ecomap_web/core/auth/admin_auth_provider.dart';
import 'package:ecomap_web/core/auth/admin_auth_state.dart';
import 'package:ecomap_web/core/constants/route_names.dart';
import 'package:ecomap_web/core/routing/app_router.dart';
import 'package:ecomap_web/domain/entities/recolector_entity.dart';
import 'package:ecomap_web/domain/repositories/recolector_repository.dart';
import 'package:ecomap_web/presentation/pages/recolectores/recolectores_page.dart';
import 'package:ecomap_web/presentation/providers/recolector_providers.dart';

class _FakeRecolectorRepository implements RecolectorRepository {
  _FakeRecolectorRepository(this.items);

  final List<RecolectorEntity> items;
  RecolectorEntity? created;
  String? updatedId;
  Map<String, dynamic>? updateData;
  String? toggledId;

  @override
  Stream<List<RecolectorEntity>> watchAll(
      {String? zona, bool? estadoActivo}) async* {
    yield items
        .where((item) => zona == null || item.zona == zona)
        .where(
            (item) => estadoActivo == null || item.estadoActivo == estadoActivo)
        .toList(growable: false);
  }

  @override
  Stream<RecolectorEntity> watchById(String id) =>
      Stream.value(items.singleWhere((item) => item.id == id));

  @override
  Future<void> create(RecolectorEntity entity) async {
    created = entity;
  }

  @override
  Future<void> update(String id, Map<String, dynamic> data) async {
    updatedId = id;
    updateData = data;
  }

  @override
  Future<void> toggleActive(String id) async {
    toggledId = id;
  }

  @override
  Future<bool> isPlateAvailable(String plate, {String? excludingId}) async {
    final normalizedPlate =
        plate.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    return items.every((item) {
      if (!item.estadoActivo || item.id == excludingId) return true;
      final itemPlate = item.vehiculoInfo['placa']
          ?.toString()
          .toUpperCase()
          .replaceAll(RegExp(r'[^A-Z0-9]'), '');
      return itemPlate != normalizedPlate;
    });
  }

  @override
  Future<List<RecolectorEntity>> search(String query) async {
    final normalized = query.toLowerCase();
    return items
        .where((item) => <String>[
              item.nombreCompleto,
              item.telefono,
              item.zona,
            ].any((value) => value.toLowerCase().contains(normalized)))
        .toList(growable: false);
  }
}

RecolectorEntity _collector({
  String id = 'collector-1',
  String name = 'Ana Recolectora',
  String zone = 'Zona Norte',
  bool active = true,
  String transport = 'vehiculo',
  String plate = 'ABC123',
}) {
  return RecolectorEntity(
    id: id,
    userId: 'user-$id',
    nombreCompleto: name,
    telefono: '+57 3001234567',
    zona: zone,
    medioTransporte: transport,
    aniosExperiencia: 4,
    estadoActivo: active,
    kilosOfertados: 120.5,
    totalOfertas: 6,
    vehiculoInfo: transport == 'vehiculo'
        ? {'placa': plate, 'marca': 'Toyota', 'capacidad': 500}
        : const {},
    fechaRegistro: DateTime(2026, 1, 2),
  );
}

Widget _page(
  _FakeRecolectorRepository repository, {
  AdminPermissions permissions = const AdminPermissions(),
}) {
  return ProviderScope(
    overrides: [
      recolectorRepositoryProvider.overrideWithValue(repository),
      adminPermissionsProvider.overrideWithValue(permissions),
    ],
    child: const MaterialApp(home: RecolectoresPage()),
  );
}

void main() {
  testWidgets('shows collector card details and opens the detail dialog',
      (tester) async {
    await tester.pumpWidget(_page(_FakeRecolectorRepository([_collector()])));
    await tester.pumpAndSettle();

    expect(find.text('Gestión de Recolectores'), findsOneWidget);
    expect(find.text('Ana Recolectora'), findsOneWidget);
    expect(find.text('ABC123 · Toyota'), findsOneWidget);
    expect(find.text('121 kg'), findsOneWidget);
    expect(find.text('6 ofertas'), findsOneWidget);

    await tester.tap(find.byTooltip('Ver detalle'));
    await tester.pumpAndSettle();
    expect(find.text('Estadísticas'), findsOneWidget);
    expect(find.text('Historial de ofertas'), findsOneWidget);
  });

  testWidgets('searches by zone/name after the debounce', (tester) async {
    final repository = _FakeRecolectorRepository([
      _collector(id: 'one', name: 'Ana', zone: 'Norte'),
      _collector(id: 'two', name: 'Bruno', zone: 'Sur', transport: 'bicicleta'),
    ]);
    await tester.pumpWidget(_page(repository));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('recolector_search_field')),
      'Bruno',
    );
    await tester.pump(const Duration(milliseconds: 301));
    await tester.pumpAndSettle();

    expect(find.text('Bruno'), findsNWidgets(2));
    expect(find.text('Ana'), findsNothing);
  });

  testWidgets('validates and creates a vehicle collector', (tester) async {
    tester.view.physicalSize = const Size(1440, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _FakeRecolectorRepository([]);
    await tester.pumpWidget(_page(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('add_recolector_button')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('recolector_name_field')),
      'Luis Nuevo',
    );
    await tester.enterText(
      find.byKey(const Key('recolector_phone_field')),
      '+57 3001234567',
    );
    await tester.enterText(
      find.byKey(const Key('recolector_experience_field')),
      '2',
    );
    await tester.enterText(
      find.byKey(const Key('recolector_plate_field')),
      'NEW123',
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const Key('recolector_brand_field')),
    );
    await tester.enterText(
      find.byKey(const Key('recolector_brand_field')),
      'Renault',
    );
    await tester.ensureVisible(
      find.byKey(const Key('recolector_capacity_field')),
    );
    await tester.enterText(
      find.byKey(const Key('recolector_capacity_field')),
      '450',
    );
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(repository.created?.nombreCompleto, 'Luis Nuevo');
    expect(repository.created?.vehiculoInfo['placa'], 'NEW-123');
    expect(find.text('Recolector creado exitosamente.'), findsOneWidget);
  });

  testWidgets('shows an error when an active collector already owns the plate',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _FakeRecolectorRepository([_collector()]);
    await tester.pumpWidget(_page(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('add_recolector_button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('recolector_plate_field')),
      'abc123',
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(
      find.text('Esta placa ya está registrada en otro recolector activo'),
      findsOneWidget,
    );
  });

  testWidgets('rejects a phone number without country code and valid length',
      (tester) async {
    final repository = _FakeRecolectorRepository([]);
    await tester.pumpWidget(_page(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('add_recolector_button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('recolector_phone_field')),
      '300123',
    );
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(
      find.text('Usa código de país y 7 a 12 dígitos'),
      findsOneWidget,
    );
    expect(repository.created, isNull);
  });

  testWidgets('confirms the requested collector deactivation', (tester) async {
    tester.view.physicalSize = const Size(1440, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _FakeRecolectorRepository([_collector()]);
    await tester.pumpWidget(_page(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Bloquear recolector'));
    await tester.pumpAndSettle();
    expect(
        find.textContaining('Cancelará sus ofertas activas'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Bloquear'));
    await tester.pumpAndSettle();

    expect(repository.toggledId, 'collector-1');
    expect(find.text('Recolector bloqueado exitosamente.'), findsOneWidget);
  });

  testWidgets('hides collector mutations without management permission',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _FakeRecolectorRepository([_collector()]);
    await tester.pumpWidget(
      _page(
        repository,
        permissions: const AdminPermissions(manageRecolectores: false),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('add_recolector_button')), findsNothing);
    expect(find.byTooltip('Editar recolector'), findsNothing);
    expect(find.byTooltip('Bloquear recolector'), findsNothing);
    expect(repository.toggledId, isNull);
  });

  test('registers /recolectores for authenticated admins', () {
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
    router.go(RouteNames.recolectores);

    expect(
      router.routeInformationProvider.value.uri.path,
      RouteNames.recolectores,
    );
  });
}
