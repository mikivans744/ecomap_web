import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'firestore_entity_converters.dart';

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
    this.kilosPendientes = 0,
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
  final double kilosPendientes;
  final int totalOfertas;
  final String horario;

  /// Optional extension; `zona` is not part of the supplied center schema.
  final String? zona;

  factory CentroAcopioEntity.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? const <String, dynamic>{};
    return CentroAcopioEntity(
      id: snapshot.id,
      nombre: data['nombre'] as String? ?? '',
      responsable: data['responsable'] as String? ?? '',
      telefono: data['telefono'] as String? ?? '',
      direccion: data['direccion'] as String? ?? '',
      materialesAceptados:
          (data['materialesAceptados'] as List<dynamic>? ?? const <dynamic>[])
              .whereType<String>()
              .toList(growable: false),
      capacidadMaxima: readFirestoreDouble(data['capacidadMaxima']),
      estadoActivo: data['estadoActivo'] as bool? ?? false,
      kilosComprometidos: readFirestoreDouble(data['kilosComprometidos']),
      totalOfertas: readFirestoreInt(data['totalOfertas']),
      horario: data['horario'] as String? ?? '',
      zona: data['zona'] as String?,
      kilosPendientes: readFirestoreDouble(data['kilosPendientes']),
    );
  }

  Map<String, dynamic> toFirestore() {
    final data = <String, dynamic>{
      'nombre': nombre,
      'responsable': responsable,
      'telefono': telefono,
      'direccion': direccion,
      'materialesAceptados': List<String>.from(materialesAceptados),
      'capacidadMaxima': capacidadMaxima,
      'estadoActivo': estadoActivo,
      'kilosComprometidos': kilosComprometidos,
      'kilosPendientes': kilosPendientes,
      'totalOfertas': totalOfertas,
      'horario': horario,
    };
    if (zona != null) {
      data['zona'] = zona;
    }
    return data;
  }
}
