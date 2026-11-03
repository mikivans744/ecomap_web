import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'firestore_entity_converters.dart';

@immutable
class UserEntity {
  const UserEntity({
    required this.uid,
    required this.email,
    required this.nombre,
    required this.rol,
    required this.telefono,
    required this.zona,
    required this.estadoActivo,
    required this.reputacion,
    required this.totalReciclado,
    required this.fechaRegistro,
    this.puntos = 0,
    this.lat = 0,
    this.lon = 0,
  });

  final String uid;
  final String email;
  final String nombre;
  final String rol;
  final String telefono;
  final String zona;
  final bool estadoActivo;
  final double reputacion;
  final double totalReciclado;
  final DateTime fechaRegistro;
  final int puntos;
  final double lat;
  final double lon;

  factory UserEntity.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? const <String, dynamic>{};
    return UserEntity(
      uid: snapshot.id,
      email: data['email'] as String? ?? '',
      nombre: data['nombre'] as String? ?? '',
      rol: data['rol'] as String? ?? 'CIUDADANO',
      telefono: data['telefono'] as String? ?? '',
      zona: '',
      estadoActivo: data['activo'] as bool? ?? true,
      reputacion: readFirestoreDouble(data['reputacion']),
      totalReciclado: 0,
      fechaRegistro:
          readFirestoreDateTime(data['createdAt'] ?? data['creado_at']),
      puntos: readFirestoreInt(data['puntos']),
      lat: readFirestoreDouble(data['lat']),
      lon: readFirestoreDouble(data['lon']),
    );
  }

  Map<String, dynamic> toFirestore() => <String, dynamic>{
        'uid': uid,
        'email': email,
        'nombre': nombre,
        'rol': rol,
        'telefono': telefono,
        'reputacion': reputacion,
        'puntos': puntos,
        'lat': lat,
        'lon': lon,
        'createdAt': fechaRegistro.millisecondsSinceEpoch,
        'activo': estadoActivo,
      };
}
