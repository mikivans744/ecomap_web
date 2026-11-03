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

  factory UserEntity.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? const <String, dynamic>{};
    return UserEntity(
      uid: data['uid'] as String? ?? snapshot.id,
      email: data['email'] as String? ?? '',
      nombre: data['nombre'] as String? ?? '',
      rol: data['rol'] as String? ?? 'ciudadano',
      telefono: data['telefono'] as String? ?? '',
      zona: data['zona'] as String? ?? '',
      estadoActivo: data['estadoActivo'] as bool? ?? false,
      reputacion: readFirestoreDouble(data['reputacion']),
      totalReciclado: readFirestoreDouble(data['totalReciclado']),
      fechaRegistro: readFirestoreDateTime(data['fechaRegistro']),
    );
  }

  Map<String, dynamic> toFirestore() => <String, dynamic>{
        'uid': uid,
        'email': email,
        'nombre': nombre,
        'rol': rol,
        'telefono': telefono,
        'zona': zona,
        'estadoActivo': estadoActivo,
        'reputacion': reputacion,
        'totalReciclado': totalReciclado,
        'fechaRegistro': Timestamp.fromDate(fechaRegistro),
      };
}
