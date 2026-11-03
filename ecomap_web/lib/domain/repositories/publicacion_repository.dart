import '../entities/publicacion_entity.dart';

abstract interface class PublicacionRepository {
  Stream<List<PublicacionEntity>> watchAll({
    String? estado,
    String? categoria,
    bool? estadoActivo,
  });

  Stream<PublicacionEntity> watchById(String id);

  Future<void> create(PublicacionEntity entity);

  Future<void> update(String id, Map<String, dynamic> data);

  Future<void> toggleActive(String id, {String? adminId});

  Future<void> softDelete(String id, String adminId);

  Future<void> markInactive(String id);

  Future<List<PublicacionEntity>> search(String query);
}

class PublicacionAlreadySold implements Exception {
  const PublicacionAlreadySold();

  @override
  String toString() => 'Una publicación vendida no se puede editar.';
}

class PublicacionStateChangeRequiresOffer implements Exception {
  const PublicacionStateChangeRequiresOffer();

  @override
  String toString() =>
      'El estado de venta/reserva solo puede cambiarse desde el flujo de ofertas.';
}
