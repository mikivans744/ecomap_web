import 'package:ecomap_web/domain/entities/centro_acopio_entity.dart';
import 'package:ecomap_web/domain/entities/publicacion_entity.dart';
import 'package:ecomap_web/domain/entities/recolector_entity.dart';
import 'package:ecomap_web/presentation/pages/mapa/mapa_page.dart';
import 'package:ecomap_web/presentation/providers/mapa_providers.dart';
import 'package:ecomap_web/presentation/providers/material_category_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('serializes separate coordinates for map entities', () {
    expect(_center().toFirestore(), containsPair('lat', 4.711));
    expect(_center().toFirestore(), containsPair('lon', -74.0721));
    expect(_collector().toFirestore(), containsPair('lat', 4.711));
    expect(_collector().toFirestore(), containsPair('lon', -74.0521));
    expect(_publication().toFirestore(), containsPair('lat', 4.711));
    expect(_publication().toFirestore(), containsPair('lon', -74.0321));
  });

  testWidgets('renders located records and opens marker details',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          materialCategoryCatalogProvider.overrideWith(
            (ref) => Stream.value(MaterialCategoryCatalog.fallback),
          ),
          centrosMapaProvider.overrideWith((ref) {
            final filters = ref.watch(mapaFiltrosProvider);
            return Stream.value(
              [_center(), _glassCenter()]
                  .where((center) =>
                      filters.zona == null || center.zona == filters.zona)
                  .toList(),
            );
          }),
          recolectoresMapaProvider.overrideWith(
            (ref) => Stream.value([_collector()]),
          ),
          publicacionesMapaProvider.overrideWith(
            (ref) => Stream.value([_publication()]),
          ),
        ],
        child: const MaterialApp(home: MapaPage()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(FlutterMap), findsOneWidget);
    expect(find.byKey(const Key('map_marker_centro_center-1')), findsOneWidget);
    expect(
      find.byKey(const Key('map_marker_recolector_collector-1')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('map_marker_publicacion_publication-1')),
      findsOneWidget,
    );

    await tester.tap(find.byIcon(Icons.warehouse).first);
    await tester.pump();
    expect(find.text('Centro Norte'), findsWidgets);
    expect(find.text('Dirección: Calle 1'), findsOneWidget);
    await tester.tap(find.byTooltip('Cerrar'));
    await tester.pump();

    await tester.tap(find.text('Material'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Vidrio').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const Key('map_marker_centro_center-1')), findsOneWidget);
    expect(
      find.byKey(const Key('map_marker_centro_center-2')),
      findsOneWidget,
    );
  });
}

CentroAcopioEntity _center() => const CentroAcopioEntity(
      id: 'center-1',
      nombre: 'Centro Norte',
      responsable: 'Responsable',
      telefono: '',
      direccion: 'Calle 1',
      materialesAceptados: ['plastico'],
      capacidadMaxima: 100,
      estadoActivo: true,
      kilosComprometidos: 10,
      totalOfertas: 2,
      horario: 'Lunes a viernes',
      zona: 'Zona Norte',
      latitud: 4.711,
      longitud: -74.0721,
    );

CentroAcopioEntity _glassCenter() => const CentroAcopioEntity(
      id: 'center-2',
      nombre: 'Centro Sur',
      responsable: 'Responsable',
      telefono: '',
      direccion: 'Calle 2',
      materialesAceptados: ['vidrio'],
      capacidadMaxima: 100,
      estadoActivo: true,
      kilosComprometidos: 10,
      totalOfertas: 2,
      horario: 'Lunes a viernes',
      zona: 'Zona Sur',
      latitud: 4.711,
      longitud: -74.0521,
    );

RecolectorEntity _collector() => RecolectorEntity(
      id: 'collector-1',
      userId: 'user-1',
      nombreCompleto: 'Recolector Uno',
      telefono: '',
      zona: 'Zona Norte',
      medioTransporte: 'bicicleta',
      aniosExperiencia: 3,
      estadoActivo: true,
      kilosOfertados: 0,
      totalOfertas: 0,
      vehiculoInfo: const {},
      fechaRegistro: DateTime(2026, 1, 1),
      latitud: 4.711,
      longitud: -74.0521,
    );

PublicacionEntity _publication() => PublicacionEntity(
      id: 'publication-1',
      userId: 'user-1',
      titulo: 'Material recuperable',
      descripcion: '',
      categoria: 'plastico',
      peso: 1.5,
      precioSugerido: 0,
      calidad: 'usado',
      estado: 'DISPONIBLE',
      fechaPublicacion: DateTime(2026, 11, 1),
      estadoActivo: true,
      latitud: 4.711,
      longitud: -74.0321,
    );
