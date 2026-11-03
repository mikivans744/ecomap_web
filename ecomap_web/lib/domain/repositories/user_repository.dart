import '../entities/user_entity.dart';

abstract interface class UserRepository {
  Stream<List<UserEntity>> watchAll({String? zona, bool? estadoActivo});

  Stream<UserEntity> watchById(String id);

  Future<void> create(UserEntity entity);

  Future<void> update(String id, Map<String, dynamic> data);

  Future<void> toggleActive(String id);

  Future<List<UserEntity>> search(String query);
}
