import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'firestore_entity_converters.dart';

enum NegociacionOfertaEstado { pendiente, aceptada, rechazada }

@immutable
class NegociacionOfertaEntity {
  const NegociacionOfertaEntity({
    required this.id,
    required this.publicacionId,
    required this.ciudadanoId,
    required this.recolectorId,
    required this.precio,
    required this.mensaje,
    required this.estado,
    required this.createdAt,
  });

  final String id;
  final String publicacionId;
  final String ciudadanoId;
  final String recolectorId;
  final double precio;
  final String mensaje;
  final NegociacionOfertaEstado estado;
  final DateTime createdAt;

  factory NegociacionOfertaEntity.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? const <String, dynamic>{};
    return NegociacionOfertaEntity(
      id: snapshot.id,
      publicacionId: data['publicacionId'] as String? ?? '',
      ciudadanoId: data['ciudadanoId'] as String? ?? '',
      recolectorId: data['recolectorId'] as String? ?? '',
      precio: readFirestoreDouble(data['precio']),
      mensaje: data['mensaje'] as String? ?? '',
      estado: _parseState(data['estado']),
      createdAt: readFirestoreDateTime(data['createdAt'] ?? 0),
    );
  }

  Map<String, dynamic> toFirestore() => <String, dynamic>{
        'publicacionId': publicacionId,
        'ciudadanoId': ciudadanoId,
        'recolectorId': recolectorId,
        'precio': precio,
        'mensaje': mensaje,
        'estado': estado.name.toUpperCase(),
        'createdAt': createdAt.millisecondsSinceEpoch,
      };

  static NegociacionOfertaEstado _parseState(dynamic value) {
    try {
      return NegociacionOfertaEstado.values.firstWhere(
        (state) => state.name.toUpperCase() == value,
      );
    } on StateError {
      return NegociacionOfertaEstado.pendiente;
    }
  }
}
