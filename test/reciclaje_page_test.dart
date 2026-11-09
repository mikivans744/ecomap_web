import 'package:ecomap_web/domain/entities/centro_acopio_entity.dart';
import 'package:ecomap_web/domain/entities/negociacion_oferta_entity.dart';
import 'package:ecomap_web/domain/entities/oferta_entity.dart';
import 'package:ecomap_web/domain/repositories/oferta_repository.dart';
import 'package:ecomap_web/domain/entities/recolector_entity.dart';
import 'package:ecomap_web/domain/entities/recycling_transaction.dart';
import 'package:ecomap_web/domain/entities/user_entity.dart';
import 'package:ecomap_web/presentation/pages/reciclaje/reciclaje_page.dart';
import 'package:ecomap_web/presentation/providers/centro_acopio_providers.dart';
import 'package:ecomap_web/presentation/providers/oferta_providers.dart';
import 'package:ecomap_web/presentation/providers/recolector_providers.dart';
import 'package:ecomap_web/presentation/providers/recycling_transaction_providers.dart';
import 'package:ecomap_web/presentation/providers/material_category_provider.dart';
import 'package:ecomap_web/presentation/providers/user_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows Firestore transactions, details, and material filters',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final transactions = [
      RecyclingTransaction(
        id: 'transaction-1',
        userId: 'user-1',
        collectorId: 'collector-1',
        materialCategory: 'Plástico',
        weightKg: 2.5,
        pointsAwarded: 25,
        status: RecyclingTransactionStatus.completed,
        createdAt: DateTime(2026, 6, 1),
      ),
      RecyclingTransaction(
        id: 'transaction-2',
        userId: 'user-2',
        collectorId: 'collector-2',
        materialCategory: 'Vidrio',
        weightKg: 4,
        pointsAwarded: 40,
        status: RecyclingTransactionStatus.pending,
        createdAt: DateTime(2026, 6, 2),
      ),
    ];
    final users = [
      _user('user-1', 'Usuario Uno'),
      _user('user-2', 'Usuario Dos'),
    ];
    final collectors = [
      _collector('collector-1', 'Recolector Uno'),
      _collector('collector-2', 'Recolector Dos'),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          materialCategoryCatalogProvider.overrideWith(
            (ref) => Stream.value(MaterialCategoryCatalog.fallback),
          ),
          recyclingTransactionsProvider
              .overrideWith((ref) => Stream.value(transactions)),
          completedRequestPointsProvider.overrideWith(
            (ref) => Stream.value(0),
          ),
          ofertasProvider((
            estado: null,
            centroId: null,
            recolectorId: null,
            desde: null,
            hasta: null,
          )).overrideWith((ref) => Stream.value(const <OfertaEntity>[])),
          ofertaRepositoryProvider.overrideWithValue(_FakeOfertaRepository()),
          centrosAcopioProvider((zona: null, estadoActivo: null)).overrideWith(
              (ref) => Stream.value(const <CentroAcopioEntity>[])),
          usersProvider((zona: null, estadoActivo: null))
              .overrideWith((ref) => Stream.value(users)),
          recolectoresProvider((zona: null, estadoActivo: null))
              .overrideWith((ref) => Stream.value(collectors)),
        ],
        child: const MaterialApp(home: ReciclajePage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Plástico'), findsOneWidget);
    expect(find.text('Vidrio'), findsOneWidget);
    expect(find.text('2.5 kg'), findsOneWidget);
    expect(find.text('3.8 kg'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('recycling_stat_Entregas')),
        matching: find.text('1'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('recycling_details_transaction-1')));
    await tester.pumpAndSettle();
    expect(find.text('Detalle de reciclaje'), findsOneWidget);
    expect(find.text('Usuario Uno'), findsWidgets);
    expect(find.text('Recolector Uno'), findsWidgets);
    await tester.tap(find.text('Cerrar'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('recycling_filter_Material')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vidrio').last);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('recycling_transaction_transaction-2')),
      findsOneWidget,
    );
    expect(find.text('Plástico'), findsNothing);
    expect(find.text('4.00 kg'), findsWidgets);
    expect(
      find.descendant(
        of: find.byKey(const Key('recycling_stat_Entregas')),
        matching: find.text('0'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Limpiar filtros'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('recycling_filter_Usuario')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Usuario Dos').last);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('recycling_transaction_transaction-2')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('recycling_transaction_transaction-1')),
      findsNothing,
    );

    await tester.tap(find.text('Limpiar filtros'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('recycling_filter_Recolector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Recolector Uno').last);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('recycling_transaction_transaction-1')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('recycling_transaction_transaction-2')),
      findsNothing,
    );
  });

  testWidgets('confirms accepted center-offer delivery with its actual weight',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _FakeOfertaRepository();
    final offer = OfertaEntity(
      id: 'offer-accepted',
      recolectorId: 'collector-1',
      centroId: 'center-1',
      categoria: 'PLASTICO',
      peso: 4,
      precioSugerido: 0,
      estado: 'ACEPTADA',
      fechaOferta: DateTime(2026, 11, 1),
      estadoActivo: true,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          materialCategoryCatalogProvider.overrideWith(
            (ref) => Stream.value(MaterialCategoryCatalog.fallback),
          ),
          recyclingTransactionsProvider.overrideWith(
            (ref) => Stream.value(const <RecyclingTransaction>[]),
          ),
          completedRequestPointsProvider.overrideWith(
            (ref) => Stream.value(0),
          ),
          ofertasProvider((
            estado: null,
            centroId: null,
            recolectorId: null,
            desde: null,
            hasta: null,
          )).overrideWith((ref) => Stream.value([offer])),
          ofertaRepositoryProvider.overrideWithValue(repository),
          usersProvider((zona: null, estadoActivo: null))
              .overrideWith((ref) => Stream.value(const <UserEntity>[])),
          recolectoresProvider((zona: null, estadoActivo: null))
              .overrideWith((ref) => Stream.value(const <RecolectorEntity>[])),
          centrosAcopioProvider((zona: null, estadoActivo: null))
              .overrideWith((ref) => Stream.value(const <CentroAcopioEntity>[])),
        ],
        child: const MaterialApp(home: ReciclajePage()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Entregas pendientes de confirmar (1)'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('recycling_finalize_offer_offer-accepted')),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('recycling_confirmed_weight')),
      '3.2',
    );
    await tester.tap(find.text('Confirmar').last);
    await tester.pumpAndSettle();

    expect(repository.finalizedId, 'offer-accepted');
    expect(repository.finalizedWeight, 3.2);
  });
}

class _FakeOfertaRepository implements OfertaRepository {
  String? finalizedId;
  double? finalizedWeight;

  @override
  Future<void> accept(String id) async {}

  @override
  Future<void> cancel(String id, {String? reason}) async {}

  @override
  Future<void> create(OfertaEntity entity) async {}

  @override
  Future<void> createNegotiationOffer(NegociacionOfertaEntity entity) async {}

  @override
  Future<void> finalize(String id, {double? weightConfirmed}) async {
    finalizedId = id;
    finalizedWeight = weightConfirmed;
  }

  @override
  Future<void> markInTransit(String id) async {}

  @override
  Future<List<OfertaEntity>> search(String query) async => const [];

  @override
  Stream<List<NegociacionOfertaEntity>> watchNegotiationOffers({
    String? publicacionId,
    String? ciudadanoId,
    String? recolectorId,
  }) =>
      Stream.value(const []);

  @override
  Stream<List<OfertaEntity>> watchAll({
    String? estado,
    String? centroId,
    String? recolectorId,
    DateTime? desde,
    DateTime? hasta,
  }) =>
      Stream.value(const []);

  @override
  Stream<OfertaEntity> watchById(String id) =>
      const Stream<OfertaEntity>.empty();
}

UserEntity _user(String uid, String name) => UserEntity(
      uid: uid,
      email: '$uid@example.com',
      nombre: name,
      rol: 'ciudadano',
      telefono: '',
      zona: '',
      estadoActivo: true,
      reputacion: 0,
      totalReciclado: 0,
      fechaRegistro: DateTime(2026, 1, 1),
    );

RecolectorEntity _collector(String id, String name) => RecolectorEntity(
      id: id,
      userId: 'user-$id',
      nombreCompleto: name,
      telefono: '',
      zona: '',
      medioTransporte: 'otro',
      aniosExperiencia: 0,
      estadoActivo: true,
      kilosOfertados: 0,
      totalOfertas: 0,
      vehiculoInfo: const {},
      fechaRegistro: DateTime(2026, 1, 1),
    );
