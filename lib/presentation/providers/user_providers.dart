import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/firestore_user_repository.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/user_repository.dart';
import 'audit_providers.dart';
import 'firestore_provider.dart';

typedef UserWatchFilter = ({String? zona, bool? estadoActivo});

final userRepositoryProvider = Provider<UserRepository>(
  (ref) => FirestoreUserRepository(
    firestore: ref.watch(firestoreProvider),
    auditService: ref.watch(auditServiceProvider),
  ),
);

final usersProvider =
    StreamProvider.family<List<UserEntity>, UserWatchFilter>((ref, filter) {
  return ref.watch(userRepositoryProvider).watchAll(
        zona: filter.zona,
        estadoActivo: filter.estadoActivo,
      );
});

final userByIdProvider = StreamProvider.family<UserEntity, String>((ref, id) {
  return ref.watch(userRepositoryProvider).watchById(id);
});

final userSearchProvider =
    FutureProvider.family<List<UserEntity>, String>((ref, query) {
  return ref.watch(userRepositoryProvider).search(query);
});
