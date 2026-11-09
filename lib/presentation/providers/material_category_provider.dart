import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'firestore_provider.dart';

class MaterialCategory {
  const MaterialCategory({
    required this.id,
    required this.name,
    required this.displayName,
    required this.isActive,
  });

  final String id;
  final String name;
  final String displayName;
  final bool isActive;
}

class MaterialCategoryCatalog {
  const MaterialCategoryCatalog({
    required this.categories,
    required this.isSeeded,
  });

  final List<MaterialCategory> categories;
  final bool isSeeded;

  static const fallback = MaterialCategoryCatalog(
    categories: _officialCategories,
    isSeeded: false,
  );
}

const _officialCategories = <MaterialCategory>[
  MaterialCategory(
    id: 'PLASTICO',
    name: 'Plástico',
    displayName: 'Plástico',
    isActive: true,
  ),
  MaterialCategory(
    id: 'METAL',
    name: 'Metal',
    displayName: 'Metal',
    isActive: true,
  ),
  MaterialCategory(
    id: 'VIDRIO',
    name: 'Vidrio',
    displayName: 'Vidrio',
    isActive: true,
  ),
  MaterialCategory(
    id: 'PAPEL_CARTON',
    name: 'Papel y cartón',
    displayName: 'Papel y cartón',
    isActive: true,
  ),
  MaterialCategory(
    id: 'ELECTRONICO',
    name: 'Electrónico',
    displayName: 'Electrónico',
    isActive: true,
  ),
  MaterialCategory(
    id: 'TEXTIL',
    name: 'Textil',
    displayName: 'Textil',
    isActive: true,
  ),
  MaterialCategory(
    id: 'OTRO',
    name: 'Otros',
    displayName: 'Otros',
    isActive: true,
  ),
];

final materialCategoryRepositoryProvider = Provider<MaterialCategoryRepository>(
  (ref) => FirestoreMaterialCategoryRepository(ref.watch(firestoreProvider)),
);

final materialCategoryCatalogProvider =
    StreamProvider<MaterialCategoryCatalog>((ref) {
  return ref.watch(materialCategoryRepositoryProvider).watchCatalog();
});

abstract interface class MaterialCategoryRepository {
  Stream<MaterialCategoryCatalog> watchCatalog();
  Future<void> seedOfficialCatalog();
}

class FirestoreMaterialCategoryRepository
    implements MaterialCategoryRepository {
  FirestoreMaterialCategoryRepository(this._firestore);

  final FirebaseFirestore _firestore;

  @override
  Stream<MaterialCategoryCatalog> watchCatalog() {
    return _firestore.collection('categoria_material').snapshots().map(
      (snapshot) {
        final docs = {for (final doc in snapshot.docs) doc.id: doc.data()};
        final categories = _officialCategories
            .map((official) {
              final data = docs[official.id];
              if (data == null) return official;
              final displayName = _stringValue(data['nombreMostrar']);
              final name = _stringValue(data['nombre']);
              return MaterialCategory(
                id: official.id,
                name: name.isEmpty ? official.name : name,
                displayName:
                    displayName.isEmpty ? official.displayName : displayName,
                isActive: data['activo'] as bool? ?? true,
              );
            })
            .where((category) => category.isActive)
            .toList(growable: false);
        final isSeeded = _officialCategories.every((official) {
          final data = docs[official.id];
          return data != null &&
              data['id'] == official.id &&
              data['nombre'] == official.name &&
              data['nombreMostrar'] == official.displayName &&
              data['activo'] == true;
        });
        return MaterialCategoryCatalog(
          categories: categories,
          isSeeded: isSeeded,
        );
      },
    );
  }

  @override
  Future<void> seedOfficialCatalog() async {
    final batch = _firestore.batch();
    for (final category in _officialCategories) {
      batch.set(
        _firestore.collection('categoria_material').doc(category.id),
        {
          'id': category.id,
          'nombre': category.name,
          'nombreMostrar': category.displayName,
          'activo': true,
        },
        SetOptions(merge: true),
      );
    }
    await batch.commit();
  }
}

String displayMaterialCategory(
  String? value, [
  MaterialCategoryCatalog? catalog,
]) {
  final normalized = _normalizeCategoryValue(value ?? '');
  if (normalized.isEmpty) return 'Sin categoría';

  for (final category
      in (catalog ?? MaterialCategoryCatalog.fallback).categories) {
    if (normalized == _normalizeCategoryValue(category.id) ||
        normalized == _normalizeCategoryValue(category.name) ||
        normalized == _normalizeCategoryValue(category.displayName)) {
      return category.displayName;
    }
  }
  for (final category in _officialCategories) {
    if (normalized == _normalizeCategoryValue(category.id) ||
        normalized == _normalizeCategoryValue(category.name) ||
        normalized == _normalizeCategoryValue(category.displayName)) {
      return category.displayName;
    }
  }
  return 'Sin categoría';
}

String? materialCategoryId(
  String? value, [
  MaterialCategoryCatalog? catalog,
]) {
  final normalized = _normalizeCategoryValue(value ?? '');
  if (normalized.isEmpty) return null;
  for (final category
      in (catalog ?? MaterialCategoryCatalog.fallback).categories) {
    if (normalized == _normalizeCategoryValue(category.id) ||
        normalized == _normalizeCategoryValue(category.name) ||
        normalized == _normalizeCategoryValue(category.displayName)) {
      return category.id;
    }
  }
  for (final category in _officialCategories) {
    if (normalized == _normalizeCategoryValue(category.id) ||
        normalized == _normalizeCategoryValue(category.name) ||
        normalized == _normalizeCategoryValue(category.displayName)) {
      return category.id;
    }
  }
  return null;
}

String _normalizeCategoryValue(String value) {
  final normalized = value
      .trim()
      .toUpperCase()
      .replaceAll('Á', 'A')
      .replaceAll('É', 'E')
      .replaceAll('Í', 'I')
      .replaceAll('Ó', 'O')
      .replaceAll('Ú', 'U')
      .replaceAll(RegExp(r'[^A-Z0-9]'), '');
  return switch (normalized) {
    'PAPELYCARTON' || 'PAPEL' || 'CARTON' => 'PAPELCARTON',
    'OTROS' => 'OTRO',
    _ => normalized,
  };
}

String _stringValue(dynamic value) => value is String ? value.trim() : '';
