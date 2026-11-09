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

final completedRequestPointsProvider = StreamProvider<int>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return firestore
      .collection('solicitudes')
      .where('estado', isEqualTo: 'COMPLETADA')
      .snapshots()
      .asyncMap((snapshot) async {
    var awardedCount = 0;
    for (final request in snapshot.docs) {
      final requestReference = request.reference;
      var wasAwarded = false;
      await firestore.runTransaction((transaction) async {
        final currentRequest = await transaction.get(requestReference);
        final data = currentRequest.data() ?? const <String, dynamic>{};
        if (data['estado'] != 'COMPLETADA' || data['puntosOtorgados'] == true) {
          return;
        }
        final userId = _readFirstString(
          data,
          const ['usuarioId', 'userId', 'uid', 'ciudadanoId'],
        );
        if (userId.isEmpty) {
          throw StateError(
            'La solicitud ${request.id} no tiene un usuario válido.',
          );
        }
        final userReference = firestore.collection('usuarios').doc(userId);
        final userSnapshot = await transaction.get(userReference);
        if (!userSnapshot.exists) {
          throw StateError('No existe el usuario asociado: $userId.');
        }
        final userData = userSnapshot.data() ?? const <String, dynamic>{};
        final currentPoints =
            userData['puntos'] is num ? (userData['puntos'] as num).toInt() : 0;
        final weightValue = data['pesoKg'] ?? data['weightKg'] ?? data['peso'];
        if (weightValue is! num ||
            !weightValue.isFinite ||
            weightValue < 0) {
          throw StateError(
            'La solicitud ${request.id} no tiene un peso válido.',
          );
        }
        final weight = weightValue.toDouble();
        final now = DateTime.now().millisecondsSinceEpoch;
        transaction.update(userReference, {
          'puntos': currentPoints + weight.round(),
          'updatedAt': now,
        });
        transaction.update(requestReference, {
          'puntosOtorgados': true,
          'puntosOtorgadosValor': weight.round(),
          'updatedAt': now,
        });
        wasAwarded = true;
      });
      if (wasAwarded) awardedCount++;
    }
    return awardedCount;
  });
});

String _readFirstString(Map<String, dynamic> data, List<String> fields) {
  for (final field in fields) {
    final value = data[field];
    if (value is String && value.trim().isNotEmpty) return value.trim();
  }
  return '';
}
