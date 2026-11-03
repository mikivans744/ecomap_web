import 'package:hive/hive.dart';

abstract interface class AdminStorage {
  Future<void> saveConfig(String key, dynamic value);

  T? readConfig<T>(String key);

  Future<void> deleteConfig(String key);
}

class HiveAdminStorage implements AdminStorage {
  HiveAdminStorage({Box<dynamic>? box})
      : _box = box ?? Hive.box('admin_panel_config');

  final Box<dynamic> _box;

  @override
  Future<void> saveConfig(String key, dynamic value) => _box.put(key, value);

  @override
  T? readConfig<T>(String key) => _box.get(key) as T?;

  @override
  Future<void> deleteConfig(String key) => _box.delete(key);
}
