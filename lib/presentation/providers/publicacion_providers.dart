import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/firestore_publicacion_repository.dart';
import '../../domain/entities/publicacion_entity.dart';
import '../../domain/repositories/publicacion_repository.dart';
import 'audit_providers.dart';
import 'firestore_provider.dart';

typedef PublicacionWatchFilter = ({
  String? estado,
  String? categoria,
  bool? estadoActivo,
});

final publicacionRepositoryProvider = Provider<PublicacionRepository>(
  (ref) => FirestorePublicacionRepository(
    ref.watch(firestoreProvider),
    auditService: ref.watch(auditServiceProvider),
  ),
);

final publicacionesProvider =
    StreamProvider.family<List<PublicacionEntity>, PublicacionWatchFilter>(
        (ref, filter) {
  return ref.watch(publicacionRepositoryProvider).watchAll(
        estado: filter.estado,
        categoria: filter.categoria,
        estadoActivo: filter.estadoActivo,
      );
});

final publicacionByIdProvider =
    StreamProvider.family<PublicacionEntity, String>((ref, id) {
  return ref.watch(publicacionRepositoryProvider).watchById(id);
});

final publicacionSearchProvider =
    FutureProvider.family<List<PublicacionEntity>, String>((ref, query) {
  return ref.watch(publicacionRepositoryProvider).search(query);
});
