import 'package:hive/hive.dart';

class AdminCache {
  AdminCache({Box<dynamic>? box}) : _box = box ?? Hive.box(_boxName);

  static const String boxName = 'admin_cache';
  static const String _boxName = boxName;

  final Box<dynamic> _box;

  Future<void> save<T>(String key, T value) => _box.put(key, value);

  T? read<T>(String key) => _box.get(key) as T?;

  Future<void> delete(String key) => _box.delete(key);
}
