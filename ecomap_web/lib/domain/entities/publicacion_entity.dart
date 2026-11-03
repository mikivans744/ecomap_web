import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'firestore_entity_converters.dart';

@immutable
class PublicacionEntity {
  const PublicacionEntity({
    required this.id,
    required this.userId,
    required this.titulo,
    required this.descripcion,
    required this.categoria,
    required this.peso,
    required this.precioSugerido,
    required this.calidad,
    required this.estado,
    required this.fechaPublicacion,
    required this.estadoActivo,
  });

  final String id;
  final String userId;
  final String titulo;
  final String descripcion;
  final String categoria;
  final double peso;
  final double precioSugerido;
  final String calidad;
  final String estado;
  final DateTime fechaPublicacion;
  final bool estadoActivo;

  factory PublicacionEntity.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? const <String, dynamic>{};
    return PublicacionEntity(
      id: snapshot.id,
      userId: data['userId'] as String? ?? '',
      titulo: data['titulo'] as String? ?? '',
      descripcion: data['descripcion'] as String? ?? '',
      categoria: data['categoria'] as String? ?? '',
      peso: readFirestoreDouble(data['peso']),
      precioSugerido: readFirestoreDouble(data['precioSugerido']),
      calidad: data['calidad'] as String? ?? 'usado',
      estado: data['estado'] as String? ?? 'disponible',
      fechaPublicacion: readFirestoreDateTime(data['fechaPublicacion']),
      estadoActivo: data['estadoActivo'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toFirestore() => <String, dynamic>{
        'userId': userId,
        'titulo': titulo,
        'descripcion': descripcion,
        'categoria': categoria,
        'peso': peso,
        'precioSugerido': precioSugerido,
        'calidad': calidad,
        'estado': estado,
        'fechaPublicacion': Timestamp.fromDate(fechaPublicacion),
        'estadoActivo': estadoActivo,
      };
}
