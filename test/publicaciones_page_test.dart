import 'package:ecomap_web/core/auth/admin_auth_provider.dart';
import 'package:ecomap_web/core/auth/admin_auth_state.dart';
import 'package:ecomap_web/domain/entities/oferta_entity.dart';
import 'package:ecomap_web/domain/entities/publicacion_entity.dart';
import 'package:ecomap_web/domain/entities/user_entity.dart';
import 'package:ecomap_web/domain/repositories/publicacion_repository.dart';
import 'package:ecomap_web/presentation/pages/publicaciones/publicaciones_page.dart';
import 'package:ecomap_web/presentation/providers/oferta_providers.dart';
import 'package:ecomap_web/presentation/providers/publicacion_providers.dart';
import 'package:ecomap_web/presentation/providers/user_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('paginates publications in groups of twenty', (tester) async {
    tester.view.physicalSize = const Size(1440, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _FakePublicationRepository(
      List.generate(21, (index) => _publication(index)),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          adminPermissionsProvider.overrideWithValue(
            const AdminPermissions(canModerate: false),
          ),
          publicacionRepositoryProvider.overrideWithValue(repository),
          publicacionesProvider((
            estado: null,
            categoria: null,
            estadoActivo: null,
          )).overrideWith((ref) => Stream.value(repository.items)),
          usersProvider((zona: null, estadoActivo: null))
              .overrideWith((ref) => Stream.value(const <UserEntity>[])),
          ofertasProvider((
            estado: null,
            centroId: null,
            recolectorId: null,
            desde: null,
            hasta: null,
          )).overrideWith((ref) => Stream.value(const <OfertaEntity>[])),
        ],
        child: const MaterialApp(home: PublicacionesPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Publicación 0'), findsOneWidget);
    expect(find.text('Publicación 20'), findsNothing);
    expect(find.text('Página 1 de 2'), findsOneWidget);

    await tester.tap(find.byTooltip('Página siguiente'));
    await tester.pumpAndSettle();
    expect(find.text('Publicación 20'), findsOneWidget);
    expect(find.text('Página 2 de 2'), findsOneWidget);
  });
}

class _FakePublicationRepository implements PublicacionRepository {
  _FakePublicationRepository(this.items);

  final List<PublicacionEntity> items;

  @override
  Stream<List<PublicacionEntity>> watchAll({
    String? estado,
    String? categoria,
    bool? estadoActivo,
  }) =>
      Stream.value(items);

  @override
  Stream<PublicacionEntity> watchById(String id) =>
      Stream.value(items.singleWhere((item) => item.id == id));

  @override
  Future<void> create(PublicacionEntity entity) async {}

  @override
  Future<void> update(String id, Map<String, dynamic> data) async {}

  @override
  Future<void> toggleActive(String id, {String? adminId}) async {}

  @override
  Future<void> softDelete(String id, String adminId) async {}

  @override
  Future<void> markInactive(String id) async {}

  @override
  Future<List<PublicacionEntity>> search(String query) async => items
      .where((item) => item.titulo.toLowerCase().contains(query.toLowerCase()))
      .toList(growable: false);
}

PublicacionEntity _publication(int index) => PublicacionEntity(
      id: 'publication-$index',
      userId: 'seller-$index',
      titulo: 'Publicación $index',
      descripcion: 'Descripción $index',
      categoria: 'plastico',
      peso: 4,
      precioSugerido: 20,
      calidad: 'bueno',
      estado: 'disponible',
      fechaPublicacion: DateTime(2026, 8, 1),
      estadoActivo: true,
    );
