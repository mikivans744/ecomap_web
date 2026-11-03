import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/firestore_centro_acopio_repository.dart';
import '../../domain/entities/centro_acopio_entity.dart';
import '../../domain/repositories/centro_acopio_repository.dart';
import 'firestore_provider.dart';

typedef CentroAcopioWatchFilter = ({String? zona, bool? estadoActivo});

final centroAcopioRepositoryProvider = Provider<CentroAcopioRepository>(
  (ref) => FirestoreCentroAcopioRepository(
    firestore: ref.watch(firestoreProvider),
  ),
);

final centrosAcopioProvider =
    StreamProvider.family<List<CentroAcopioEntity>, CentroAcopioWatchFilter>(
        (ref, filter) {
  return ref.watch(centroAcopioRepositoryProvider).watchAll(
        zona: filter.zona,
        estadoActivo: filter.estadoActivo,
      );
});

final centroAcopioByIdProvider =
    StreamProvider.family<CentroAcopioEntity, String>((ref, id) {
  return ref.watch(centroAcopioRepositoryProvider).watchById(id);
});

final centroAcopioSearchProvider =
    FutureProvider.family<List<CentroAcopioEntity>, String>((ref, query) {
  return ref.watch(centroAcopioRepositoryProvider).search(query);
});
