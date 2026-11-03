import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/publicacion_entity.dart';
import '../../domain/repositories/publicacion_repository.dart';

class FirestorePublicacionRepository implements PublicacionRepository {
  FirestorePublicacionRepository(this._firestore);

  final FirebaseFirestore _firestore;

  @override
  Stream<List<PublicacionEntity>> watchAll({
    String? estado,
    String? categoria,
    bool? estadoActivo,
  }) {
    Query query = _firestore.collection('publicaciones');

    if (estado != null) {
      query = query.where('estado', isEqualTo: estado);
    }
    if (categoria != null) {
      query = query.where('categoria', isEqualTo: categoria);
    }
    if (estadoActivo != null) {
      query = query.where('estadoActivo', isEqualTo: estadoActivo);
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs.map<PublicacionEntity>((doc) {
        return PublicacionEntity.fromFirestore(
          doc as DocumentSnapshot<Map<String, dynamic>>,
        );
      }).toList();
    });
  }

  @override
  Stream<PublicacionEntity> watchById(String id) {
    return _firestore.collection('publicaciones').doc(id).snapshots().map((doc) {
      return PublicacionEntity.fromFirestore(
        doc,
      );
    });
  }

  @override
  Future<void> create(PublicacionEntity entity) async {
    await _firestore.collection('publicaciones').doc(entity.id).set(entity.toFirestore());
  }

  @override
  Future<void> update(String id, Map<String, dynamic> data) async {
    await _firestore.collection('publicaciones').doc(id).update(data);
  }

  @override
  Future<void> toggleActive(String id, {String? adminId}) async {
    final doc = await _firestore.collection('publicaciones').doc(id).get();
    final currentStatus = doc.data()?['estadoActivo'] ?? true;
    await _firestore.collection('publicaciones').doc(id).update({
      'estadoActivo': !currentStatus,
      if (adminId != null) 'updatedBy': adminId,
    });
  }

  @override
  Future<void> softDelete(String id, String adminId) async {
    await _firestore.collection('publicaciones').doc(id).update({
      'estadoActivo': false,
      'deletedBy': adminId,
      'deletedAt': Timestamp.now(),
    });
  }

  @override
  Future<void> markInactive(String id) async {
    await _firestore.collection('publicaciones').doc(id).update({
      'estadoActivo': false,
    });
  }

  @override
  Future<List<PublicacionEntity>> search(String query) async {
    final snapshot = await _firestore.collection('publicaciones').get();
    final lowerQuery = query.toLowerCase();
    return snapshot.docs
        .map((doc) => PublicacionEntity.fromFirestore(
              doc as DocumentSnapshot<Map<String, dynamic>>,
            ))
        .where((pub) =>
            pub.titulo.toLowerCase().contains(lowerQuery) ||
            pub.descripcion.toLowerCase().contains(lowerQuery))
        .toList();
  }
}