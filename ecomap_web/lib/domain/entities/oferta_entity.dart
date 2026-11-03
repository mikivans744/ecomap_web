import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'firestore_entity_converters.dart';

@immutable
class OfertaEntity {
  const OfertaEntity({
    required this.id,
    required this.recolectorId,
    required this.centroId,
    required this.categoria,
    required this.peso,
    required this.precioSugerido,
    required this.estado,
    required this.fechaOferta,
    required this.estadoActivo,
    this.publicacionId,
    this.createdAt,
    this.acceptedAt,
    this.inTransitAt,
    this.finalizedAt,
    this.cancelledAt,
    this.cancelReason,
  });

  final String id;
  final String recolectorId;
  final String centroId;
  final String categoria;
  final double peso;
  final double precioSugerido;
  final String estado;
  final DateTime fechaOferta;
  final bool estadoActivo;
  final String? publicacionId;
  final DateTime? createdAt;
  final DateTime? acceptedAt;
  final DateTime? inTransitAt;
  final DateTime? finalizedAt;
  final DateTime? cancelledAt;
  final String? cancelReason;

  factory OfertaEntity.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? const <String, dynamic>{};
    return OfertaEntity(
      id: snapshot.id,
      recolectorId: data['recolectorId'] as String? ?? '',
      centroId: data['centroId'] as String? ?? '',
      categoria: data['categoria'] as String? ?? '',
      peso: readFirestoreDouble(data['peso']),
      precioSugerido: readFirestoreDouble(data['precioSugerido']),
      estado: data['estado'] as String? ?? 'pendiente',
      fechaOferta: readFirestoreDateTime(data['fechaOferta']),
      estadoActivo: data['estadoActivo'] as bool? ?? false,
      publicacionId: data['publicacionId'] as String?,
      createdAt: data['createdAt'] == null
          ? null
          : readFirestoreDateTime(data['createdAt']),
      acceptedAt: data['acceptedAt'] == null
          ? null
          : readFirestoreDateTime(data['acceptedAt']),
      inTransitAt: data['inTransitAt'] == null
          ? null
          : readFirestoreDateTime(data['inTransitAt']),
      finalizedAt: data['finalizedAt'] == null
          ? null
          : readFirestoreDateTime(data['finalizedAt']),
      cancelledAt: data['cancelledAt'] == null
          ? null
          : readFirestoreDateTime(data['cancelledAt']),
      cancelReason: data['cancelReason'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() => <String, dynamic>{
        'recolectorId': recolectorId,
        'centroId': centroId,
        'categoria': categoria,
        'peso': peso,
        'precioSugerido': precioSugerido,
        'estado': estado,
        'fechaOferta': Timestamp.fromDate(fechaOferta),
        'estadoActivo': estadoActivo,
        if (publicacionId != null) 'publicacionId': publicacionId,
      };
}
