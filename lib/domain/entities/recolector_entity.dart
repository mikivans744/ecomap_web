import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'firestore_entity_converters.dart';

@immutable
class RecolectorEntity {
  const RecolectorEntity({
    required this.id,
    required this.userId,
    required this.nombreCompleto,
    required this.telefono,
    required this.zona,
    required this.medioTransporte,
    required this.aniosExperiencia,
    required this.estadoActivo,
    required this.kilosOfertados,
    required this.totalOfertas,
    required this.vehiculoInfo,
    required this.fechaRegistro,
    this.latitud,
    this.longitud,
    this.email = '',
  });

  final String id;
  final String userId;
  final String nombreCompleto;
  final String telefono;
  final String zona;
  final String medioTransporte;
  final int aniosExperiencia;
  final bool estadoActivo;
  final double kilosOfertados;
  final int totalOfertas;
  final Map<String, dynamic> vehiculoInfo;
  final DateTime fechaRegistro;
  final double? latitud;
  final double? longitud;
  final String email;

  factory RecolectorEntity.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? const <String, dynamic>{};
    final vehicle = <String, dynamic>{
      if (data['placa_vehiculo'] is String)
        'placa': data['placa_vehiculo'],
      if (data['tipo_vehiculo'] is String)
        'tipo': data['tipo_vehiculo'],
      if (data['capacidad_kg'] is num)
        'capacidad': data['capacidad_kg'],
    };
    return RecolectorEntity(
      id: snapshot.id,
      userId: snapshot.id,
      nombreCompleto: data['nombre'] as String? ?? '',
      telefono: data['telefono'] as String? ?? '',
      zona: data['zona_cobertura'] as String? ?? '',
      medioTransporte: data['tipo_vehiculo'] as String? ?? '',
      aniosExperiencia: 0,
      estadoActivo: data['activo'] as bool? ?? true,
      kilosOfertados: 0,
      totalOfertas: 0,
      vehiculoInfo: vehicle,
      fechaRegistro:
          readFirestoreDateTime(data['createdAt'] ?? data['creado_at']),
      latitud: _readCoordinate(data['lat']),
      longitud: _readCoordinate(data['lon']),
      email: data['email'] as String? ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    final plate = vehiculoInfo['placa'];
    final capacity = vehiculoInfo['capacidad'];
    return <String, dynamic>{
      'uid': id,
      'email': email,
      'nombre': nombreCompleto,
      'telefono': telefono,
      'rol': 'RECOLECTOR',
      'reputacion': 0.0,
      'puntos': 0,
      'activo': estadoActivo,
      'zona_cobertura': zona,
      'tipo_vehiculo': medioTransporte,
      if (plate is String && plate.isNotEmpty) 'placa_vehiculo': plate,
      if (capacity is num) 'capacidad_kg': capacity.toDouble(),
      'lat': latitud ?? 0,
      'lon': longitud ?? 0,
      'createdAt': fechaRegistro.millisecondsSinceEpoch,
    };
  }

  static double? _readCoordinate(dynamic value) =>
      value is num ? value.toDouble() : null;
}
