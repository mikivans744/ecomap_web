import 'package:ecomap_web/domain/entities/negociacion_oferta_entity.dart';
import 'package:ecomap_web/domain/entities/oferta_entity.dart';
import 'package:ecomap_web/domain/entities/publicacion_entity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final createdAt = DateTime.utc(2026, 11, 2, 14);

  test('publication writes only v1 fields and enum names', () {
    final data = PublicacionEntity(
      id: 'publication-1',
      userId: 'user-1',
      titulo: 'Cartón',
      descripcion: 'Limpio',
      categoria: 'carton',
      peso: 3.5,
      precioSugerido: 12,
      calidad: 'Normal',
      estado: 'disponible',
      fechaPublicacion: createdAt,
      estadoActivo: true,
      latitud: 4.7,
      longitud: -74.1,
    ).toFirestore();

    expect(data.keys.toSet(), {
      'usuarioId',
      'titulo',
      'descripcion',
      'pesoKg',
      'categoriaId',
      'calidad',
      'precioSugerido',
      'estado',
      'lat',
      'lon',
      'createdAt',
    });
    expect(data['estado'], 'DISPONIBLE');
    expect(data['createdAt'], createdAt.millisecondsSinceEpoch);
  });

  test('center offers use ofertas_centro fields and exact state names', () {
    final data = OfertaEntity(
      id: 'offer-1',
      recolectorId: 'collector-1',
      centroId: 'center-1',
      categoria: 'carton',
      peso: 3.5,
      precioSugerido: 12,
      estado: 'aceptada',
      fechaOferta: createdAt,
      createdAt: createdAt,
      estadoActivo: true,
    ).toFirestore();

    expect(data.keys.toSet(), {
      'recolectorId',
      'centroId',
      'categoria',
      'pesoKg',
      'precioSugerido',
      'estado',
      'lat',
      'lon',
      'createdAt',
    });
    expect(data['estado'], 'ACEPTADA');
    expect(data['createdAt'], createdAt.millisecondsSinceEpoch);
  });

  test('citizen-recolector offers serialize their independent contract', () {
    final data = NegociacionOfertaEntity(
      id: 'negotiation-1',
      publicacionId: 'publication-1',
      ciudadanoId: 'citizen-1',
      recolectorId: 'collector-1',
      precio: 25,
      mensaje: '',
      estado: NegociacionOfertaEstado.pendiente,
      createdAt: createdAt,
    ).toFirestore();

    expect(data.keys.toSet(), {
      'publicacionId',
      'ciudadanoId',
      'recolectorId',
      'precio',
      'mensaje',
      'estado',
      'createdAt',
    });
    expect(data['estado'], 'PENDIENTE');
    expect(data['createdAt'], createdAt.millisecondsSinceEpoch);
  });
}
