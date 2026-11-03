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

  factory RecolectorEntity.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? const <String, dynamic>{};
    return RecolectorEntity(
      id: snapshot.id,
      userId: data['userId'] as String? ?? '',
      nombreCompleto: data['nombreCompleto'] as String? ?? '',
      telefono: data['telefono'] as String? ?? '',
      zona: data['zona'] as String? ?? '',
      medioTransporte: data['medioTransporte'] as String? ?? 'otro',
      aniosExperiencia: readFirestoreInt(data['aniosExperiencia']),
      estadoActivo: data['estadoActivo'] as bool? ?? false,
      kilosOfertados: readFirestoreDouble(data['kilosOfertados']),
      totalOfertas: readFirestoreInt(data['totalOfertas']),
      vehiculoInfo: readFirestoreMap(data['vehiculoInfo']),
      fechaRegistro: readFirestoreDateTime(data['fechaRegistro']),
    );
  }

  Map<String, dynamic> toFirestore() => <String, dynamic>{
        'userId': userId,
        'nombreCompleto': nombreCompleto,
        'telefono': telefono,
        'zona': zona,
        'medioTransporte': medioTransporte,
        'aniosExperiencia': aniosExperiencia,
        'estadoActivo': estadoActivo,
        'kilosOfertados': kilosOfertados,
        'totalOfertas': totalOfertas,
        'vehiculoInfo': Map<String, dynamic>.from(vehiculoInfo),
        'fechaRegistro': Timestamp.fromDate(fechaRegistro),
      };
}
