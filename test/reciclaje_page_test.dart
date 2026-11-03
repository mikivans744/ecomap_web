import 'package:ecomap_web/domain/entities/recolector_entity.dart';
import 'package:ecomap_web/domain/entities/recycling_transaction.dart';
import 'package:ecomap_web/domain/entities/user_entity.dart';
import 'package:ecomap_web/presentation/pages/reciclaje/reciclaje_page.dart';
import 'package:ecomap_web/presentation/providers/recolector_providers.dart';
import 'package:ecomap_web/presentation/providers/recycling_transaction_providers.dart';
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
          recyclingTransactionsProvider
              .overrideWith((ref) => Stream.value(transactions)),
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
    expect(find.text('6.5 kg'), findsOneWidget);
    expect(find.text('65'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('recycling_stat_Transacciones')),
        matching: find.text('2'),
      ),
      findsOneWidget,
    );

    await tester
        .tap(find.byKey(const Key('recycling_transaction_transaction-1')));
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
    expect(find.text('4.0 kg'), findsWidgets);
    expect(
      find.descendant(
        of: find.byKey(const Key('recycling_stat_Transacciones')),
        matching: find.text('1'),
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
