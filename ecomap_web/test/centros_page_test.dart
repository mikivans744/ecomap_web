import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ecomap_web/core/auth/admin_auth_state.dart';
import 'package:ecomap_web/core/routing/app_router.dart';
import 'package:ecomap_web/domain/entities/centro_acopio_entity.dart';
import 'package:ecomap_web/domain/repositories/centro_acopio_repository.dart';
import 'package:ecomap_web/presentation/pages/centros/centros_page.dart';
import 'package:ecomap_web/presentation/providers/centro_acopio_providers.dart';

class _FakeCentroRepository implements CentroAcopioRepository {
  _FakeCentroRepository(this.centers, {this.offersByCenter = const {}});

  final List<CentroAcopioEntity> centers;
  final Map<String, List<Map<String, dynamic>>> offersByCenter;
  CentroAcopioEntity? created;
  String? updatedId;
  Map<String, dynamic>? updatedData;
  String? toggledId;

  @override
  Stream<List<CentroAcopioEntity>> watchAll(
      {String? zona, bool? estadoActivo}) async* {
    yield centers
        .where((center) => zona == null || center.zona == zona)
        .where((center) =>
            estadoActivo == null || center.estadoActivo == estadoActivo)
        .toList(growable: false);
  }

  @override
  Stream<CentroAcopioEntity> watchById(String id) =>
      Stream.value(centers.singleWhere((center) => center.id == id));

  @override
  Future<void> create(CentroAcopioEntity entity) async {
    created = entity;
  }

  @override
  Future<void> update(String id, Map<String, dynamic> data) async {
    updatedId = id;
    updatedData = data;
  }

  @override
  Future<void> toggleActive(String id) async {
    final center = centers.singleWhere((item) => item.id == id);
    final activeOffers = await getActiveOffers(id);
    if (center.estadoActivo && activeOffers.isNotEmpty) {
      throw CentroAcopioHasActiveOffers(activeOffers.length);
    }
    toggledId = id;
  }

  @override
  Future<List<Map<String, dynamic>>> getActiveOffers(String centerId) async {
    return offersByCenter[centerId] ?? const <Map<String, dynamic>>[];
  }

  @override
  Future<List<CentroAcopioEntity>> search(String query) async {
    final normalized = query.toLowerCase();
    return centers
        .where((center) => <String>[
              center.nombre,
              center.responsable,
              center.direccion,
            ].any((value) => value.toLowerCase().contains(normalized)))
        .toList(growable: false);
  }
}

CentroAcopioEntity _center({
  String id = 'center-1',
  String name = 'Centro Norte',
  bool active = true,
  List<String> materials = const ['plastico', 'vidrio'],
  double capacity = 1000,
  double committed = 450,
}) {
  return CentroAcopioEntity(
    id: id,
    nombre: name,
    responsable: 'Responsable Uno',
    telefono: '+57 3001234567',
    direccion: 'Avenida Principal 123',
    materialesAceptados: materials,
    capacidadMaxima: capacity,
    estadoActivo: active,
    kilosComprometidos: committed,
    totalOfertas: 12,
    horario: 'Lunes a Viernes 8:00-18:00',
    zona: 'Zona Norte',
  );
}

Widget _page(_FakeCentroRepository repository) {
  return ProviderScope(
    overrides: [centroAcopioRepositoryProvider.overrideWithValue(repository)],
    child: const MaterialApp(home: CentrosPage()),
  );
}

void main() {
  testWidgets('shows center details and capacity usage', (tester) async {
    await tester.pumpWidget(_page(_FakeCentroRepository([_center()])));
    await tester.pumpAndSettle();

    expect(find.text('Centros de Acopio'), findsOneWidget);
    expect(find.text('Centro Norte'), findsOneWidget);
    expect(find.text('Responsable Uno'), findsOneWidget);
    expect(find.text('Capacidad: 450 kg / 1000 kg'), findsOneWidget);
    expect(find.text('Plástico'), findsOneWidget);
  });

  testWidgets('searches by address after 300ms debounce', (tester) async {
    final repository = _FakeCentroRepository([
      _center(id: 'one', name: 'Centro Uno'),
      _center(id: 'two', name: 'Bodega Sur'),
    ]);
    await tester.pumpWidget(_page(repository));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('centro_search_field')),
      'Avenida Principal',
    );
    await tester.pump(const Duration(milliseconds: 301));
    await tester.pumpAndSettle();

    expect(find.text('Bodega Sur'), findsOneWidget);
    expect(find.text('Centro Uno'), findsOneWidget);
  });

  testWidgets('creates a center with selected material slugs', (tester) async {
    final repository = _FakeCentroRepository([]);
    await tester.pumpWidget(_page(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('add_centro_button')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('centro_name_field')), 'Punto Verde');
    await tester.enterText(
        find.byKey(const Key('centro_manager_field')), 'María');
    await tester.enterText(
        find.byKey(const Key('centro_phone_field')), '+57 3001234567');
    await tester.enterText(
        find.byKey(const Key('centro_address_field')), 'Calle 10');
    await tester.enterText(find.byKey(const Key('centro_schedule_field')),
        'Lunes a viernes 8:00-18:00');
    await tester.enterText(
        find.byKey(const Key('centro_capacity_field')), '1500');
    await tester.ensureVisible(find.byKey(const Key('material_vidrio')));
    await tester.tap(find.byKey(const Key('material_vidrio')));
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(repository.created?.nombre, 'Punto Verde');
    expect(repository.created?.materialesAceptados, contains('vidrio'));
    expect(repository.created?.capacidadMaxima, 1500);
    expect(find.text('Centro creado exitosamente.'), findsOneWidget);
  });

  testWidgets('blocks deactivation when active offers exist', (tester) async {
    final repository = _FakeCentroRepository(
      [_center()],
      offersByCenter: {
        'center-1': [
          {
            'id': 'offer-1',
            'estado': 'pendiente',
            'peso': 50,
            'categoria': 'plastico'
          },
          {
            'id': 'offer-2',
            'estado': 'aceptada',
            'peso': 20,
            'categoria': 'vidrio'
          },
        ],
      },
    );
    await tester.pumpWidget(_page(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Desactivar centro'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('tiene 2 ofertas activas'),
      findsOneWidget,
    );
    expect(repository.toggledId, isNull);
    await tester.tap(find.text('Ver ofertas'));
    await tester.pumpAndSettle();
    expect(find.text('Ofertas activas · Centro Norte'), findsOneWidget);
    expect(find.text('plastico · 50 kg'), findsOneWidget);
  });

  testWidgets('allows deactivation after confirming when there are no offers',
      (tester) async {
    final repository = _FakeCentroRepository([_center()]);
    await tester.pumpWidget(_page(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Desactivar centro'));
    await tester.pumpAndSettle();
    expect(find.textContaining('No permitirá nuevas ofertas'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Desactivar'));
    await tester.pumpAndSettle();

    expect(repository.toggledId, 'center-1');
    expect(find.text('Centro desactivado exitosamente.'), findsOneWidget);
  });

  test('registers /centros for authenticated admins', () {
    final router = AppRouter(
      authState: const AdminAuthState(
        userId: 'admin-1',
        email: 'admin@example.com',
        isAdmin: true,
      ),
    ).router;

    expect(router.namedLocation('centros'), '/centros');
    router.dispose();
  });
}
