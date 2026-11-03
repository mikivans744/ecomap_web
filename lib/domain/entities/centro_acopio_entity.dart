import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

@immutable
class CentroAcopioEntity {
  const CentroAcopioEntity({
    required this.id,
    required this.nombre,
    required this.responsable,
    required this.telefono,
    required this.direccion,
    required this.materialesAceptados,
    required this.capacidadMaxima,
    required this.estadoActivo,
    required this.kilosComprometidos,
    required this.totalOfertas,
    required this.horario,
    this.zona,
    this.latitud,
    this.longitud,
    this.email = '',
  });

  final String id;
  final String nombre;
  final String responsable;
  final String telefono;
  final String direccion;
  final List<String> materialesAceptados;
  final double capacidadMaxima;
  final bool estadoActivo;
  final double kilosComprometidos;
  final int totalOfertas;
  final String horario;
  final String? zona;
  final double? latitud;
  final double? longitud;
  final String email;

  factory CentroAcopioEntity.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? const <String, dynamic>{};
    return CentroAcopioEntity(
      id: snapshot.id,
      nombre: data['nombre_empresa'] as String? ?? '',
      responsable: data['nombre'] as String? ?? '',
      telefono: data['telefono'] as String? ?? '',
      direccion: data['direccion_fija'] as String? ?? '',
      materialesAceptados: const <String>[],
      capacidadMaxima: 0,
      estadoActivo: data['activo'] as bool? ?? true,
      kilosComprometidos: 0,
      totalOfertas: 0,
      horario: '',
      latitud: _readCoordinate(data['lat']),
      longitud: _readCoordinate(data['lon']),
      email: data['email'] as String? ?? '',
    );
  }

  Map<String, dynamic> toFirestore() => <String, dynamic>{
        'uid': id,
        'email': email,
        'nombre': responsable,
        'telefono': telefono,
        'rol': 'CENTRO_ACOPIO',
        'reputacion': 0.0,
        'puntos': 0,
        'activo': estadoActivo,
        'nombre_empresa': nombre,
        'direccion_fija': direccion,
        'lat': latitud ?? 0,
        'lon': longitud ?? 0,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      };

  static double? _readCoordinate(dynamic value) =>
      value is num ? value.toDouble() : null;
}
