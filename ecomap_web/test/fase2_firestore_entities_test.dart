import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ecomap_web/domain/entities/centro_acopio_entity.dart';
import 'package:ecomap_web/domain/entities/firestore_entity_converters.dart';
import 'package:ecomap_web/domain/entities/recolector_entity.dart';
import 'package:ecomap_web/domain/entities/user_entity.dart';

void main() {
  final registeredAt = DateTime.utc(2026, 10, 15, 12);

  group('Firestore entity serialization', () {
    test('serializes user fields and dates using the app schema', () {
      final user = UserEntity(
        uid: 'user-1',
        email: 'user@example.com',
        nombre: 'Usuario Uno',
        rol: 'ciudadano',
        telefono: '+521234567890',
        zona: 'Norte',
        estadoActivo: true,
        reputacion: 4.5,
        totalReciclado: 12.75,
        fechaRegistro: registeredAt,
      );

      final data = user.toFirestore();

      expect(data['uid'], 'user-1');
      expect(data['rol'], 'ciudadano');
      expect(data['estadoActivo'], isTrue);
      expect(data['fechaRegistro'], Timestamp.fromDate(registeredAt));
      expect(
          readFirestoreDateTime(data['fechaRegistro']).toUtc(), registeredAt);
    });

    test('serializes recolector vehicle details and numeric fields', () {
      final recolector = RecolectorEntity(
        id: 'collector-1',
        userId: 'user-1',
        nombreCompleto: 'Recolector Uno',
        telefono: '+521234567890',
        zona: 'Centro',
        medioTransporte: 'vehículo',
        aniosExperiencia: 4,
        estadoActivo: true,
        kilosOfertados: 35.5,
        totalOfertas: 8,
        vehiculoInfo: const {
          'placa': 'ABC123',
          'marca': 'Marca',
          'capacidad': 100,
        },
        fechaRegistro: registeredAt,
      );

      final data = recolector.toFirestore();

      expect(data['userId'], 'user-1');
      expect(data['vehiculoInfo'], containsPair('placa', 'ABC123'));
      expect(data['fechaRegistro'], Timestamp.fromDate(registeredAt));
      expect(readFirestoreDouble(data['kilosOfertados']), 35.5);
    });

    test('serializes center materials and optional zone extension', () {
      const center = CentroAcopioEntity(
        id: 'center-1',
        nombre: 'Centro Norte',
        responsable: 'Responsable',
        telefono: '+521234567890',
        direccion: 'Calle 1',
        materialesAceptados: ['Plástico', 'Vidrio'],
        capacidadMaxima: 500,
        estadoActivo: true,
        kilosComprometidos: 120.5,
        totalOfertas: 3,
        horario: 'Lunes a viernes',
        zona: 'Norte',
      );

      final data = center.toFirestore();

      expect(data['materialesAceptados'], ['Plástico', 'Vidrio']);
      expect(data['zona'], 'Norte');
      expect(data['capacidadMaxima'], 500);
    });
  });
}
