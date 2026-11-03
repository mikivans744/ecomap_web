import 'package:ecomap_web/domain/entities/oferta_entity.dart';
import 'package:ecomap_web/domain/entities/publicacion_entity.dart';
import 'package:ecomap_web/domain/entities/user_entity.dart';
import 'package:ecomap_web/presentation/providers/dashboard_stats_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('aggregates dashboard metrics from official v1 collection shapes', () {
    final stats = DashboardStats.fromData(
      activeUsers: [
        UserEntity(
          uid: 'user-1',
          email: 'user@example.test',
          nombre: 'Usuario',
          rol: 'CIUDADANO',
          telefono: '',
          zona: '',
          estadoActivo: true,
          reputacion: 4.5,
          totalReciclado: 0,
          fechaRegistro: DateTime(2025, 6),
        ),
      ],
      publications: [
        _publication('available', 'DISPONIBLE'),
        _publication('delivered', 'ENTREGADO'),
      ],
      centerOffers: [
        _offer(
          id: 'paper-may',
          category: 'Papel',
          kilograms: 5,
          state: 'ENTREGADA',
          createdAt: DateTime(2025, 5, 4),
        ),
        _offer(
          id: 'plastic-june',
          category: 'Plástico',
          kilograms: 3,
          state: 'ENTREGADA',
          createdAt: DateTime(2025, 6, 3),
        ),
        _offer(
          id: 'rejected',
          category: 'Vidrio',
          kilograms: 50,
          state: 'RECHAZADA',
          createdAt: DateTime(2025, 6, 4),
        ),
        _offer(
          id: 'accepted',
          category: 'Cartón',
          kilograms: 12,
          state: 'ACEPTADA',
          createdAt: DateTime(2025, 6, 6),
        ),
        _offer(
          id: 'old-delivered',
          category: 'Papel',
          kilograms: 2,
          state: 'ENTREGADA',
          createdAt: DateTime(2024, 12, 5),
        ),
      ],
      requests: const [
        {'estado': 'SOLICITADA'},
        {'estado': 'SOLICITADA'},
        {'estado': 'ACEPTADA'},
      ],
      now: DateTime(2025, 6, 15),
    );

    expect(stats.totalUsuariosActivos, 1);
    expect(stats.reputacionPromedio, 4.5);
    expect(stats.materialRecicladoTotal, 10);
    expect(stats.completedTransactions, 3);
    expect(stats.monthlyRecyclingTotals, hasLength(6));
    expect(stats.monthlyRecyclingTotals[4].kilograms, 5);
    expect(stats.monthlyRecyclingTotals[5].kilograms, 3);
    expect(stats.recyclingByMaterial, hasLength(2));
    expect(stats.recyclingByMaterial.first.material, 'Papel');
    expect(stats.recyclingByMaterial.first.kilograms, 7);
    expect(stats.solicitudesPendientes, 2);
    expect(stats.publicacionesActivas, 1);
    expect(stats.publicacionesVendidas, 1);
    expect(stats.ofertasPendientes, 0);
    expect(stats.kilosComprometidos, 12);
  });
}

PublicacionEntity _publication(String id, String state) => PublicacionEntity(
      id: id,
      userId: 'user-1',
      titulo: id,
      descripcion: '',
      categoria: 'material',
      peso: 1,
      precioSugerido: 0,
      calidad: 'Normal',
      estado: state,
      fechaPublicacion: DateTime(2025),
      estadoActivo: state == 'DISPONIBLE' || state == 'RESERVADO',
    );

OfertaEntity _offer({
  required String id,
  required String category,
  required double kilograms,
  required String state,
  required DateTime createdAt,
}) =>
    OfertaEntity(
      id: id,
      recolectorId: 'collector-1',
      centroId: 'center-1',
      categoria: category,
      peso: kilograms,
      precioSugerido: 10,
      estado: state,
      fechaOferta: createdAt,
      createdAt: createdAt,
      estadoActivo: state == 'OFERTADA' || state == 'ACEPTADA',
    );
