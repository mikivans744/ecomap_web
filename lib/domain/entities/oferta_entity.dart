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
    this.fotoUrl,
    this.lat = 0,
    this.lon = 0,
    this.weightConfirmed,
    this.signatureUrl,
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
  final String? fotoUrl;
  final double lat;
  final double lon;
  final double? weightConfirmed;
  final String? signatureUrl;

  factory OfertaEntity.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? const <String, dynamic>{};
    final state = data['estado'] as String? ?? 'OFERTADA';
    final createdAt = readFirestoreDateTime(data['createdAt']);
    return OfertaEntity(
      id: snapshot.id,
      recolectorId: data['recolectorId'] as String? ?? '',
      centroId: data['centroId'] as String? ?? '',
      categoria: data['categoria'] as String? ?? '',
      peso: readFirestoreDouble(data['pesoKg']),
      precioSugerido: readFirestoreDouble(data['precioSugerido']),
      estado: state,
      fechaOferta: createdAt,
      estadoActivo: state == 'OFERTADA' || state == 'ACEPTADA',
      createdAt: createdAt,
      fotoUrl: data['fotoUrl'] as String?,
      lat: readFirestoreDouble(data['lat']),
      lon: readFirestoreDouble(data['lon']),
      weightConfirmed: data['weightConfirmed'] == null
          ? null
          : readFirestoreDouble(data['weightConfirmed']),
      signatureUrl: data['signatureUrl'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() => <String, dynamic>{
        'recolectorId': recolectorId,
        'centroId': centroId,
        'categoria': categoria,
        'pesoKg': peso,
        'precioSugerido': precioSugerido,
        if (fotoUrl != null) 'fotoUrl': fotoUrl,
        'estado': _canonicalState(estado),
        'lat': lat,
        'lon': lon,
        if (weightConfirmed != null) 'weightConfirmed': weightConfirmed,
        if (signatureUrl != null) 'signatureUrl': signatureUrl,
        'createdAt': (createdAt ?? fechaOferta).millisecondsSinceEpoch,
      };

  static String _canonicalState(String state) => switch (state) {
        'ofertada' || 'pendiente' => 'OFERTADA',
        'aceptada' => 'ACEPTADA',
        'entregada' || 'finalizada' => 'ENTREGADA',
        'rechazada' || 'cancelada' => 'RECHAZADA',
        _ => state,
      };
}
