import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/user_repository.dart';

class FirestoreUserRepository implements UserRepository {
  FirestoreUserRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  static const String _collection = 'users';

  @override
  Stream<List<UserEntity>> watchAll({String? zona, bool? estadoActivo}) {
    Query<Map<String, dynamic>> query = _firestore.collection(_collection);
    if (zona != null && zona.trim().isNotEmpty) {
      query = query.where('zona', isEqualTo: zona.trim());
    }
    if (estadoActivo != null) {
      query = query.where('estadoActivo', isEqualTo: estadoActivo);
    }
    return query.snapshots().map(
          (snapshot) => snapshot.docs
              .map(UserEntity.fromFirestore)
              .toList(growable: false),
        );
  }

  @override
  Stream<UserEntity> watchById(String id) {
    return _firestore.collection(_collection).doc(id).snapshots().map((doc) {
      if (!doc.exists) {
        throw StateError('No existe el usuario $id.');
      }
      return UserEntity.fromFirestore(doc);
    });
  }

  @override
  Future<void> create(UserEntity entity) {
    return _firestore
        .collection(_collection)
        .doc(entity.uid)
        .set(entity.toFirestore());
  }

  @override
  Future<void> update(String id, Map<String, dynamic> data) {
    return _firestore.collection(_collection).doc(id).update(data);
  }

  @override
  Future<void> toggleActive(String id) => _toggleActive(id);

  @override
  Future<List<UserEntity>> search(String query) async {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) {
      return const <UserEntity>[];
    }
    final snapshot = await _firestore.collection(_collection).get();
    return snapshot.docs
        .map(UserEntity.fromFirestore)
        .where((user) => <String>[
              user.uid,
              user.email,
              user.nombre,
              user.telefono,
            ].any((value) => value.toLowerCase().contains(normalizedQuery)))
        .toList(growable: false);
  }

  Future<void> _toggleActive(String id) async {
    final users = _firestore.collection(_collection);
    final reference = users.doc(id);
    final currentUser = await reference.get();
    if (!currentUser.exists) {
      throw StateError('No existe el usuario $id.');
    }
    final userData = currentUser.data()!;
    final shouldDeactivate = userData['estadoActivo'] == true;
    if (!shouldDeactivate && userData['publicationCascadePending'] == true) {
      throw StateError(
        'La desactivación de sus publicaciones todavía está en proceso.',
      );
    }

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(reference);
      if (!snapshot.exists) {
        throw StateError('No existe el usuario $id.');
      }
      if ((snapshot.data()?['estadoActivo'] == true) != shouldDeactivate) {
        throw StateError(
          'El estado del usuario cambió durante la operación. Intenta de nuevo.',
        );
      }

      transaction.update(reference, {
        'estadoActivo': !shouldDeactivate,
        if (shouldDeactivate) 'publicationCascadePending': true,
      });
    });
  }
}
