import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/publicacion_entity.dart';
import '../../domain/repositories/publicacion_repository.dart';
import '../../domain/services/audit_service.dart';
import '../services/firestore_audit_service.dart';

class FirestorePublicacionRepository implements PublicacionRepository {
  FirestorePublicacionRepository(
    this._firestore, {
    AuditService? auditService,
  }) : _auditService =
            auditService ?? FirestoreAuditService(firestore: _firestore);

  final FirebaseFirestore _firestore;
  final AuditService _auditService;
  static const String _collection = 'publicaciones';

  @override
  Stream<List<PublicacionEntity>> watchAll({
    String? estado,
    String? categoria,
    bool? estadoActivo,
  }) {
    Query<Map<String, dynamic>> query = _firestore.collection(_collection);
    if (estado != null) {
      query = query.where('estado', isEqualTo: _canonicalState(estado));
    }
    if (categoria != null) {
      query = query.where('categoriaId', isEqualTo: categoria);
    }
    return query.snapshots().map((snapshot) => snapshot.docs
        .map(PublicacionEntity.fromFirestore)
        .where((publication) =>
            estadoActivo == null || publication.estadoActivo == estadoActivo)
        .toList(growable: false));
  }

  @override
  Stream<PublicacionEntity> watchById(String id) {
    return _firestore.collection(_collection).doc(id).snapshots().map((doc) {
      if (!doc.exists) throw StateError('No existe la publicación $id.');
      return PublicacionEntity.fromFirestore(doc);
    });
  }

  @override
  Future<void> create(PublicacionEntity entity) async {
    final reference = entity.id.isEmpty
        ? _firestore.collection(_collection).doc()
        : _firestore.collection(_collection).doc(entity.id);
    await reference.set(entity.toFirestore());
  }

  @override
  Future<void> update(String id, Map<String, dynamic> data) async {
    final reference = _firestore.collection(_collection).doc(id);
    final snapshot = await reference.get();
    if (!snapshot.exists) throw StateError('No existe la publicación $id.');
    final current = snapshot.data()!;
    if (current['estado'] == 'ENTREGADO') {
      throw const PublicacionAlreadySold();
    }
    final changes = _canonicalChanges(data);
    if (changes.isEmpty) return;
    if (changes['estado'] == 'ENTREGADO') {
      final userId =
          current['usuarioId'] as String? ?? current['userId'] as String? ?? '';
      if (userId.isEmpty) {
        throw StateError(
          'La publicación no tiene un usuario propietario válido.',
        );
      }
      final userReference = _firestore.collection('usuarios').doc(userId);
      final now = DateTime.now().millisecondsSinceEpoch;
      late int previousPoints;
      late int nextPoints;
      await _firestore.runTransaction((transaction) async {
        final publicationSnapshot = await transaction.get(reference);
        if (!publicationSnapshot.exists) {
          throw StateError('No existe la publicación $id.');
        }
        final publicationData =
            publicationSnapshot.data() ?? const <String, dynamic>{};
        if (publicationData['estado'] == 'ENTREGADO') {
          throw const PublicacionAlreadySold();
        }
        final userSnapshot = await transaction.get(userReference);
        if (!userSnapshot.exists) {
          throw StateError('No existe el usuario asociado: $userId.');
        }
        final userData = userSnapshot.data() ?? const <String, dynamic>{};
        final currentPoints =
            userData['puntos'] is num ? (userData['puntos'] as num).toInt() : 0;
        final weightValue =
            publicationData['pesoKg'] ?? publicationData['peso'];
        if (weightValue is! num ||
            !weightValue.isFinite ||
            weightValue < 0) {
          throw StateError(
            'La publicación no tiene un peso válido para otorgar puntos.',
          );
        }
        final weight = weightValue.toDouble();
        previousPoints = currentPoints;
        nextPoints = currentPoints + weight.round();
        transaction.update(reference, {...changes, 'updatedAt': now});
        transaction.update(userReference, {
          'puntos': nextPoints,
          'updatedAt': now,
        });
      });
      await _auditService.log(
        action: 'publication_sold',
        entityType: 'publicacion',
        entityId: id,
        before: {'estado': current['estado']},
        after: {
          ...changes,
          'puntosCiudadano': {
            'before': previousPoints,
            'after': nextPoints,
          },
        },
      );
    } else {
      await reference.update(changes);
    }
  }

  @override
  Future<void> toggleActive(String id, {String? adminId}) async {
    final reference = _firestore.collection(_collection).doc(id);
    final snapshot = await reference.get();
    if (!snapshot.exists) throw StateError('No existe la publicación $id.');
    final current = snapshot.data()!;
    if (current['estado'] == 'ENTREGADO') {
      throw const PublicacionAlreadySold();
    }
    final currentlyActive = const {'DISPONIBLE', 'RESERVADO'}
        .contains(current['estado'] ?? 'DISPONIBLE');
    final nextState = currentlyActive ? 'CANCELADO' : 'DISPONIBLE';
    await reference.update({'estado': nextState});
    await _auditService.log(
      action:
          currentlyActive ? 'publication_deactivated' : 'publication_activated',
      entityType: 'publicacion',
      entityId: id,
      before: {'estado': current['estado']},
      after: {'estado': nextState},
    );
  }

  @override
  Future<void> softDelete(String id, String adminId) async {
    final reference = _firestore.collection(_collection).doc(id);
    final snapshot = await reference.get();
    if (!snapshot.exists) throw StateError('No existe la publicación $id.');
    if (snapshot.data()?['estado'] == 'ENTREGADO') {
      throw const PublicacionAlreadySold();
    }
    await reference.update({'estado': 'CANCELADO'});
    await _auditService.log(
      action: 'publication_deleted',
      entityType: 'publicacion',
      entityId: id,
      before: {'estado': snapshot.data()?['estado']},
      after: {'estado': 'CANCELADO'},
    );
  }

  @override
  Future<List<PublicacionEntity>> search(String query) async {
    final snapshot = await _firestore.collection(_collection).get();
    return snapshot.docs
        .map(PublicacionEntity.fromFirestore)
        .where((publication) =>
            publication.titulo.toLowerCase().contains(query.toLowerCase()) ||
            publication.descripcion.toLowerCase().contains(query.toLowerCase()))
        .toList(growable: false);
  }

  @override
  Future<void> markInactive(String id) async {
    final reference = _firestore.collection(_collection).doc(id);
    final snapshot = await reference.get();
    if (!snapshot.exists) throw StateError('No existe la publicación $id.');
    await reference.update({'estado': 'CANCELADO'});
    await _auditService.log(
      action: 'publication_deactivated',
      entityType: 'publicacion',
      entityId: id,
      before: {'estado': snapshot.data()?['estado']},
      after: {'estado': 'CANCELADO'},
    );
  }

  Map<String, dynamic> _canonicalChanges(Map<String, dynamic> data) {
    final changes = <String, dynamic>{};
    for (final entry in data.entries) {
      switch (entry.key) {
        case 'estado':
          changes['estado'] = _canonicalState('${entry.value}');
        case 'estadoActivo':
          changes['estado'] = entry.value == true ? 'DISPONIBLE' : 'CANCELADO';
        case 'userId':
          changes['usuarioId'] = entry.value;
        case 'categoria':
          changes['categoriaId'] = entry.value;
        case 'peso':
          changes['pesoKg'] = entry.value;
        case 'fechaPublicacion':
          changes['createdAt'] = entry.value is DateTime
              ? (entry.value as DateTime).millisecondsSinceEpoch
              : entry.value;
        case 'usuarioId':
        case 'titulo':
        case 'descripcion':
        case 'pesoKg':
        case 'categoriaId':
        case 'calidad':
        case 'precioSugerido':
        case 'imagenUrl':
        case 'lat':
        case 'lon':
        case 'createdAt':
          changes[entry.key] = entry.value;
        default:
          throw ArgumentError.value(
            entry.key,
            'data',
            'No es un campo del diccionario oficial de publicaciones.',
          );
      }
    }
    return changes;
  }

  String _canonicalState(String state) => switch (state) {
        'disponible' => 'DISPONIBLE',
        'reservado' => 'RESERVADO',
        'vendido' || 'entregado' => 'ENTREGADO',
        'cancelado' || 'cancelada' => 'CANCELADO',
        _ => state,
      };
}
