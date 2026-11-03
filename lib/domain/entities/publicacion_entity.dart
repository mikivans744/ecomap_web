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
    this.latitud,
    this.longitud,
    this.imagenUrl,
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
  final double? latitud;
  final double? longitud;
  final String? imagenUrl;

  factory PublicacionEntity.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? const <String, dynamic>{};
    final state = data['estado'] as String? ?? 'DISPONIBLE';
    return PublicacionEntity(
      id: snapshot.id,
      userId: data['usuarioId'] as String? ?? '',
      titulo: data['titulo'] as String? ?? '',
      descripcion: data['descripcion'] as String? ?? '',
      categoria: data['categoriaId'] as String? ?? '',
      peso: readFirestoreDouble(data['pesoKg']),
      precioSugerido: readFirestoreDouble(data['precioSugerido']),
      calidad: data['calidad'] as String? ?? 'Normal',
      estado: state,
      fechaPublicacion: readFirestoreDateTime(data['createdAt']),
      estadoActivo: state == 'DISPONIBLE' || state == 'RESERVADO',
      latitud: _readCoordinate(data['lat']),
      longitud: _readCoordinate(data['lon']),
      imagenUrl: data['imagenUrl'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() => <String, dynamic>{
        'usuarioId': userId,
        'titulo': titulo,
        'descripcion': descripcion,
        'pesoKg': peso,
        'categoriaId': categoria,
        'calidad': calidad,
        'precioSugerido': precioSugerido,
        'estado': _canonicalState(estado),
        if (imagenUrl != null) 'imagenUrl': imagenUrl,
        'lat': latitud ?? 0,
        'lon': longitud ?? 0,
        'createdAt': fechaPublicacion.millisecondsSinceEpoch,
      };

  static String _canonicalState(String state) => switch (state) {
        'disponible' => 'DISPONIBLE',
        'reservado' => 'RESERVADO',
        'entregado' || 'vendido' => 'ENTREGADO',
        'cancelado' || 'cancelada' => 'CANCELADO',
        _ => state,
      };

  static double? _readCoordinate(dynamic value) =>
      value is num ? value.toDouble() : null;
}
