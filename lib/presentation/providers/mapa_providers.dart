import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/centro_acopio_entity.dart';
import '../../domain/entities/publicacion_entity.dart';
import '../../domain/entities/recolector_entity.dart';
import 'material_category_provider.dart';

class MapaFiltros {
  const MapaFiltros({
    this.mostrarRecolectores = true,
    this.mostrarCentros = true,
    this.mostrarPublicaciones = true,
    this.zona,
    this.material,
  });

  final bool mostrarRecolectores;
  final bool mostrarCentros;
  final bool mostrarPublicaciones;
  final String? zona;
  final String? material;

  MapaFiltros copyWith({
    bool? mostrarRecolectores,
    bool? mostrarCentros,
    bool? mostrarPublicaciones,
    String? zona,
    String? material,
  }) {
    return MapaFiltros(
      mostrarRecolectores: mostrarRecolectores ?? this.mostrarRecolectores,
      mostrarCentros: mostrarCentros ?? this.mostrarCentros,
      mostrarPublicaciones: mostrarPublicaciones ?? this.mostrarPublicaciones,
      zona: zona ?? this.zona,
      material: material ?? this.material,
    );
  }
}

final mapaFiltrosProvider =
    StateProvider<MapaFiltros>((ref) => const MapaFiltros());

final recolectoresMapaProvider = StreamProvider<List<RecolectorEntity>>((ref) {
  final filtros = ref.watch(mapaFiltrosProvider);
  return FirebaseFirestore.instance
      .collection('usuarios')
      .where('rol', isEqualTo: 'RECOLECTOR')
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map(RecolectorEntity.fromFirestore)
          .where((item) =>
              item.latitud != null &&
              item.longitud != null &&
              item.latitud != 0 &&
              item.longitud != 0)
          .where((item) => filtros.zona == null || item.zona == filtros.zona)
          .toList(growable: false));
});

final centrosMapaProvider = StreamProvider<List<CentroAcopioEntity>>((ref) {
  return FirebaseFirestore.instance
      .collection('usuarios')
      .where('rol', isEqualTo: 'CENTRO_ACOPIO')
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map(CentroAcopioEntity.fromFirestore)
          .where((item) =>
              item.latitud != null &&
              item.longitud != null &&
              item.latitud != 0 &&
              item.longitud != 0)
          .toList(growable: false));
});

final publicacionesMapaProvider =
    StreamProvider<List<PublicacionEntity>>((ref) {
  final filtros = ref.watch(mapaFiltrosProvider);
  final selectedMaterial = materialCategoryId(filtros.material);
  return FirebaseFirestore.instance
      .collection('publicaciones')
      .where('estado', isEqualTo: 'DISPONIBLE')
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map(PublicacionEntity.fromFirestore)
          .where((item) =>
              item.latitud != null &&
              item.longitud != null &&
              item.latitud != 0 &&
              item.longitud != 0 &&
              (selectedMaterial == null ||
                  materialCategoryId(item.categoria) == selectedMaterial))
          .toList(growable: false));
});
