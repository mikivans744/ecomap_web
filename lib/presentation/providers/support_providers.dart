import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'firestore_provider.dart';

class SupportTicket {
  const SupportTicket({required this.id, required this.data});

  final String id;
  final Map<String, dynamic> data;

  String get subject =>
      _readString(data, ['subject', 'title', 'asunto'], 'Ticket sin asunto');
  String get description =>
      _readString(data, ['description', 'message', 'descripcion'], '');
  String get userId =>
      _readString(data, ['userId', 'uid', 'email'], 'Usuario no especificado');
  String get status => _canonicalTicketStatus(
        _readString(data, ['estado', 'status'], 'ABIERTO'),
      );
  DateTime get createdAt =>
      _readDate(data['createdAt'] ?? data['fechaCreacion']);
  List<Map<String, dynamic>> get history {
    final value = data['historial'];
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((entry) => Map<String, dynamic>.from(entry))
        .toList(growable: false);
  }

  static SupportTicket fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) =>
      SupportTicket(id: document.id, data: document.data());
}

class SupportFaq {
  const SupportFaq({required this.id, required this.data});

  final String id;
  final Map<String, dynamic> data;

  String get question => _readString(
      data, ['question', 'pregunta', 'title'], 'Pregunta sin título');
  String get answer =>
      _readString(data, ['answer', 'respuesta', 'content'], '');
  bool get isActive =>
      data['active'] as bool? ?? data['estadoActivo'] as bool? ?? true;

  static SupportFaq fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) =>
      SupportFaq(id: document.id, data: document.data());
}

class SupportNotification {
  const SupportNotification({required this.id, required this.data});

  final String id;
  final Map<String, dynamic> data;

  String get title => _readString(data, ['title', 'titulo'], '');
  String get body =>
      _readString(data, ['cuerpo', 'body', 'message', 'mensaje'], '');
  String get status =>
      _readString(data, ['deliveryStatus', 'status', 'estado'], 'pending');
  String get type => _readString(data, ['tipo', 'type'], '');
  String get recipientUid => _readString(data, ['paraUid', 'userId'], '');
  bool get isRead => data['leido'] as bool? ?? data['read'] as bool? ?? false;
  DateTime get createdAt =>
      _readDate(data['createdAt'] ?? data['fechaCreacion']);

  static SupportNotification fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) =>
      SupportNotification(id: document.id, data: document.data());
}

final supportRepositoryProvider = Provider<SupportRepository>(
  (ref) => FirestoreSupportRepository(ref.watch(firestoreProvider)),
);

final supportTicketsProvider = StreamProvider<List<SupportTicket>>((ref) {
  return ref.watch(supportRepositoryProvider).watchTickets();
});

final supportFaqsProvider = StreamProvider<List<SupportFaq>>((ref) {
  return ref.watch(supportRepositoryProvider).watchFaqs();
});

final supportNotificationsProvider =
    StreamProvider<List<SupportNotification>>((ref) {
  return ref.watch(supportRepositoryProvider).watchNotifications();
});

abstract interface class SupportRepository {
  Stream<List<SupportTicket>> watchTickets();
  Stream<List<SupportFaq>> watchFaqs();
  Stream<List<SupportNotification>> watchNotifications();
  Future<void> createTicket({
    required String subject,
    required String description,
    required String userId,
  });
  Future<void> updateTicket(
    String id, {
    required String status,
    required String response,
  });
  Future<void> markNotificationRead(String id);
  Future<void> saveFaq({
    String? id,
    required String question,
    required String answer,
    required bool active,
  });
  Future<void> deleteFaq(String id);
  Future<void> enqueueNotification({
    required String title,
    required String body,
    String? userId,
  });
}

class FirestoreSupportRepository implements SupportRepository {
  FirestoreSupportRepository(this._firestore);

  final FirebaseFirestore _firestore;

  @override
  Stream<List<SupportTicket>> watchTickets() =>
      _firestore.collection('support_tickets').snapshots().map((snapshot) {
        final tickets = snapshot.docs.map(SupportTicket.fromDocument).toList();
        tickets.sort(
            (first, second) => second.createdAt.compareTo(first.createdAt));
        return tickets;
      });

  @override
  Stream<List<SupportFaq>> watchFaqs() => _firestore
      .collection('faqs')
      .snapshots()
      .map((snapshot) => snapshot.docs.map(SupportFaq.fromDocument).toList());

  @override
  Stream<List<SupportNotification>> watchNotifications() =>
      _firestore.collection('notifications').snapshots().map((snapshot) {
        final notifications =
            snapshot.docs.map(SupportNotification.fromDocument).toList();
        notifications.sort(
            (first, second) => second.createdAt.compareTo(first.createdAt));
        return notifications;
      });

  @override
  Future<void> createTicket({
    required String subject,
    required String description,
    required String userId,
  }) async {
    await _firestore.collection('support_tickets').add({
      'subject': subject,
      'description': description,
      'userId': userId,
      'status': 'ABIERTO',
      'estado': 'ABIERTO',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> updateTicket(
    String id, {
    required String status,
    required String response,
  }) async {
    final canonicalStatus = _canonicalTicketStatus(status);
    final now = DateTime.now().millisecondsSinceEpoch;
    final ticketRef = _firestore.collection('support_tickets').doc(id);
    final notificationRef = _firestore.collection('notifications').doc();
    final responseText = response.trim();
    final ticket = await ticketRef.get();
    final recipientUid = _readString(
      ticket.data() ?? const <String, dynamic>{},
      ['uid', 'userId', 'paraUid'],
      '',
    );
    final update = <String, dynamic>{
      'status': canonicalStatus,
      'estado': canonicalStatus,
      'updatedAt': FieldValue.serverTimestamp(),
      if (canonicalStatus == 'RESUELTO') 'resolvedAt': now,
      if (responseText.isNotEmpty) ...{
        'respuestaAdmin': responseText,
        'response': responseText,
        'respondidoAt': now,
        'historial': FieldValue.arrayUnion([
          {'autor': 'ADMIN', 'texto': responseText, 'at': now},
        ]),
      },
    };
    final batch = _firestore.batch();
    batch.update(ticketRef, update);
    batch.set(notificationRef, {
      'paraUid': recipientUid,
      'titulo': 'Soporte: $canonicalStatus',
      'cuerpo': responseText.isNotEmpty
          ? responseText
          : 'El estado de tu solicitud cambió a $canonicalStatus.',
      'tipo': 'SOPORTE',
      'createdAt': now,
      'leido': false,
    });
    await batch.commit();
  }

  @override
  Future<void> markNotificationRead(String id) =>
      _firestore.collection('notifications').doc(id).update({'leido': true});

  @override
  Future<void> saveFaq({
    String? id,
    required String question,
    required String answer,
    required bool active,
  }) async {
    final data = <String, dynamic>{
      'question': question,
      'answer': answer,
      'pregunta': question,
      'respuesta': answer,
      'active': active,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (id == null) {
      data['createdAt'] = FieldValue.serverTimestamp();
      await _firestore.collection('faqs').add(data);
    } else {
      await _firestore.collection('faqs').doc(id).update(data);
    }
  }

  @override
  Future<void> deleteFaq(String id) =>
      _firestore.collection('faqs').doc(id).delete();

  @override
  Future<void> enqueueNotification({
    required String title,
    required String body,
    String? userId,
  }) async {
    await _firestore.collection('notifications').add({
      'title': title,
      'body': body,
      'userId': userId,
      'audience': userId == null ? 'all' : 'user',
      'type': 'push',
      'deliveryStatus': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}

String _readString(
  Map<String, dynamic> data,
  List<String> keys,
  String fallback,
) {
  for (final key in keys) {
    final value = data[key];
    if (value is String && value.trim().isNotEmpty) return value.trim();
  }
  return fallback;
}

String _canonicalTicketStatus(String status) {
  final normalized = status.trim().toLowerCase().replaceAll(' ', '_');
  return switch (normalized) {
    'open' || 'abierto' || 'abierta' || 'pending' || 'pendiente' => 'ABIERTO',
    'in_progress' || 'en_progreso' => 'EN_PROGRESO',
    'responded' || 'respondido' || 'respondida' => 'RESPONDIDO',
    'resolved' || 'resuelto' || 'resuelta' => 'RESUELTO',
    'closed' || 'cerrado' || 'cerrada' => 'CERRADO',
    _ => status.trim().toUpperCase(),
  };
}

DateTime _readDate(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is num) {
    return DateTime.fromMillisecondsSinceEpoch(value.toInt());
  }
  if (value is String) return DateTime.tryParse(value) ?? DateTime(1970);
  return DateTime(1970);
}
