import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/firestore_recolector_repository.dart';
import '../../domain/entities/recolector_entity.dart';
import '../../domain/repositories/recolector_repository.dart';
import 'firestore_provider.dart';

typedef RecolectorWatchFilter = ({String? zona, bool? estadoActivo});

final recolectorRepositoryProvider = Provider<RecolectorRepository>(
  (ref) => FirestoreRecolectorRepository(
    firestore: ref.watch(firestoreProvider),
  ),
);

final recolectoresProvider =
    StreamProvider.family<List<RecolectorEntity>, RecolectorWatchFilter>(
        (ref, filter) {
  return ref.watch(recolectorRepositoryProvider).watchAll(
        zona: filter.zona,
        estadoActivo: filter.estadoActivo,
      );
});

final recolectorByIdProvider =
    StreamProvider.family<RecolectorEntity, String>((ref, id) {
  return ref.watch(recolectorRepositoryProvider).watchById(id);
});

final recolectorSearchProvider =
    FutureProvider.family<List<RecolectorEntity>, String>((ref, query) {
  return ref.watch(recolectorRepositoryProvider).search(query);
});
