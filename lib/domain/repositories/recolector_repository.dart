import '../entities/recolector_entity.dart';

abstract interface class RecolectorRepository {
  Stream<List<RecolectorEntity>> watchAll({String? zona, bool? estadoActivo});

  Stream<RecolectorEntity> watchById(String id);

  Future<void> create(RecolectorEntity entity);

  Future<void> update(String id, Map<String, dynamic> data);

  Future<void> toggleActive(String id);

  Future<bool> isPlateAvailable(String plate, {String? excludingId});

  Future<List<RecolectorEntity>> search(String query);
}

class RecolectorPlateAlreadyInUse implements Exception {
  const RecolectorPlateAlreadyInUse(this.plate);

  final String plate;

  @override
  String toString() =>
      'La placa $plate ya está registrada en otro recolector activo.';
}
