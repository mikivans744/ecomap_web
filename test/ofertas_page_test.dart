import 'package:ecomap_web/core/auth/admin_auth_provider.dart';
import 'package:ecomap_web/core/auth/admin_auth_state.dart';
import 'package:ecomap_web/domain/entities/negociacion_oferta_entity.dart';
import 'package:ecomap_web/domain/entities/oferta_entity.dart';
import 'package:ecomap_web/domain/repositories/oferta_repository.dart';
import 'package:ecomap_web/presentation/pages/ofertas/ofertas_page.dart';
import 'package:ecomap_web/presentation/providers/centro_acopio_providers.dart';
import 'package:ecomap_web/presentation/providers/oferta_providers.dart';
import 'package:ecomap_web/presentation/providers/recolector_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeOfertaRepository implements OfertaRepository {
  @override
  Future<void> accept(String id) async {}

  @override
  Future<void> cancel(String id, {String? reason}) async {}

  @override
  Future<void> create(OfertaEntity entity) async {}

  @override
  Future<void> createNegotiationOffer(NegociacionOfertaEntity entity) async {}

  @override
  Future<void> finalize(String id) async {}

  @override
  Future<void> markInTransit(String id) async {}

  @override
  Future<List<OfertaEntity>> search(String query) async => [_offer];

  @override
  Stream<List<NegociacionOfertaEntity>> watchNegotiationOffers({
    String? publicacionId,
    String? ciudadanoId,
    String? recolectorId,
  }) =>
      Stream.value([_negotiation]);

  @override
  Stream<List<OfertaEntity>> watchAll({
    String? estado,
    String? centroId,
    String? recolectorId,
    DateTime? desde,
    DateTime? hasta,
  }) =>
      Stream.value([_offer]);

  @override
  Stream<OfertaEntity> watchById(String id) => Stream.value(_offer);
}

final _offer = OfertaEntity(
  id: 'offer-1',
  recolectorId: 'collector-1',
  centroId: 'missing-center',
  categoria: 'plastico',
  peso: 2,
  precioSugerido: 10,
  estado: 'OFERTADA',
  fechaOferta: DateTime(2026, 11, 2, 14, 5),
  estadoActivo: true,
  createdAt: DateTime(2026, 11, 2, 14, 5),
);

final _negotiation = NegociacionOfertaEntity(
  id: 'negotiation-1',
  publicacionId: 'publication-1',
  ciudadanoId: 'citizen-1',
  recolectorId: 'collector-1',
  precio: 12.5,
  mensaje: 'Propongo este precio',
  estado: NegociacionOfertaEstado.pendiente,
  createdAt: DateTime(2026, 11, 2, 14, 5),
);

void main() {
  testWidgets('offers page displays center fallback and negotiations tab',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          adminPermissionsProvider.overrideWithValue(const AdminPermissions()),
          ofertaRepositoryProvider.overrideWithValue(_FakeOfertaRepository()),
          ofertasProvider((
            estado: null,
            centroId: null,
            recolectorId: null,
            desde: null,
            hasta: null,
          )).overrideWith((ref) => Stream.value([_offer])),
          negotiationOffersProvider((
            publicacionId: null,
            ciudadanoId: null,
            recolectorId: null,
          )).overrideWith((ref) => Stream.value([_negotiation])),
          centrosAcopioProvider((zona: null, estadoActivo: null))
              .overrideWith((ref) => Stream.value(const [])),
          recolectoresProvider((zona: null, estadoActivo: null))
              .overrideWith((ref) => Stream.value(const [])),
        ],
        child: const MaterialApp(home: OfertasPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ofertas a centros'), findsOneWidget);
    expect(find.text('Centro sin asignar'), findsOneWidget);
    expect(find.text('Oferta: 02/11/2026 14:05'), findsOneWidget);

    await tester.tap(find.text('Negociaciones'));
    await tester.pumpAndSettle();

    expect(find.text('Publicación publication-1'), findsOneWidget);
    expect(find.text('Ciudadano: citizen-1'), findsOneWidget);
    expect(find.text('Recolector: collector-1'), findsOneWidget);
    expect(find.text('Precio: \$12.50'), findsOneWidget);
    expect(find.text('Mensaje: Propongo este precio'), findsOneWidget);
    expect(find.text('PENDIENTE'), findsOneWidget);
    expect(find.text('Fecha: 02/11/2026 14:05'), findsOneWidget);
  });
}
