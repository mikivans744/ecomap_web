import 'package:ecomap_web/presentation/pages/soporte/soporte_page.dart';
import 'package:ecomap_web/presentation/providers/support_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('filters tickets by status and shows FAQs and notifications',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          supportTicketsProvider.overrideWith(
            (ref) => Stream.value([
              SupportTicket(
                id: 'ticket-open',
                data: {
                  'subject': 'Problema con la cuenta',
                  'description': 'No puedo ingresar',
                  'userId': 'user-1',
                  'status': 'open',
                  'createdAt': DateTime(2026, 11, 1),
                },
              ),
              SupportTicket(
                id: 'ticket-resolved',
                data: {
                  'subject': 'Consulta resuelta',
                  'description': 'Se restableció el acceso',
                  'userId': 'user-2',
                  'status': 'resolved',
                  'createdAt': DateTime(2026, 11, 2),
                },
              ),
            ]),
          ),
          supportFaqsProvider.overrideWith(
            (ref) => Stream.value([
              const SupportFaq(
                id: 'faq-1',
                data: {
                  'question': '¿Cómo reciclo?',
                  'answer': 'Separa los materiales.',
                  'active': true,
                },
              ),
            ]),
          ),
          supportNotificationsProvider.overrideWith(
            (ref) => Stream.value([
              SupportNotification(
                id: 'notification-1',
                data: {
                  'title': 'Aviso general',
                  'body': 'Hay novedades.',
                  'deliveryStatus': 'pending',
                  'createdAt': DateTime(2026, 11, 2),
                },
              ),
            ]),
          ),
        ],
        child: const MaterialApp(home: SoportePage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Problema con la cuenta'), findsOneWidget);
    expect(find.text('Consulta resuelta'), findsOneWidget);

    await tester.tap(find.byKey(const Key('support_ticket_status_filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Resueltos').last);
    await tester.pumpAndSettle();

    expect(find.text('Consulta resuelta'), findsOneWidget);
    expect(find.text('Problema con la cuenta'), findsNothing);

    await tester.tap(find.text('Preguntas frecuentes'));
    await tester.pumpAndSettle();
    expect(find.text('¿Cómo reciclo?'), findsOneWidget);
    expect(find.byKey(const Key('edit_faq_faq-1')), findsOneWidget);

    await tester.tap(find.text('Notificaciones'));
    await tester.pumpAndSettle();
    expect(find.text('Aviso general'), findsOneWidget);
    expect(
      find.textContaining('solicitudes pendientes'),
      findsOneWidget,
    );
  });

  testWidgets('resolves tickets, edits FAQs, and queues push requests',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _FakeSupportRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          supportRepositoryProvider.overrideWithValue(repository),
          supportTicketsProvider.overrideWith(
            (ref) => repository.watchTickets(),
          ),
          supportFaqsProvider.overrideWith((ref) => repository.watchFaqs()),
          supportNotificationsProvider.overrideWith(
            (ref) => repository.watchNotifications(),
          ),
        ],
        child: const MaterialApp(home: SoportePage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('support_ticket_ticket-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ticket_status_editor')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Resuelto').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('ticket_response_field')),
      'Acceso restablecido',
    );
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(repository.updatedTicketStatus, 'resolved');
    expect(repository.updatedTicketResponse, 'Acceso restablecido');

    await tester.tap(find.byKey(const Key('create_support_ticket')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('ticket_subject_field')),
      'Consulta nueva',
    );
    await tester.enterText(
      find.byKey(const Key('ticket_user_field')),
      'user-3',
    );
    await tester.enterText(
      find.byKey(const Key('ticket_description_field')),
      'Necesito ayuda',
    );
    await tester.tap(find.text('Crear'));
    await tester.pumpAndSettle();
    expect(repository.createdTicketSubject, 'Consulta nueva');
    expect(repository.createdTicketUserId, 'user-3');

    await tester.tap(find.text('Preguntas frecuentes'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('edit_faq_faq-1')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('faq_question_field')),
      '¿Dónde reciclar?',
    );
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(repository.savedFaqQuestion, '¿Dónde reciclar?');
    expect(repository.savedFaqId, 'faq-1');

    await tester.tap(find.text('Notificaciones'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('create_support_notification')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('notification_title_field')),
      'Aviso importante',
    );
    await tester.enterText(
      find.byKey(const Key('notification_body_field')),
      'Mensaje para los usuarios',
    );
    await tester.tap(find.text('Guardar solicitud'));
    await tester.pumpAndSettle();
    expect(repository.queuedNotificationTitle, 'Aviso importante');
    expect(repository.queuedNotificationUserId, isNull);
  });
}

class _FakeSupportRepository implements SupportRepository {
  final tickets = [
    const SupportTicket(
      id: 'ticket-1',
      data: {
        'subject': 'Ayuda con la cuenta',
        'description': 'No puedo ingresar',
        'userId': 'user-1',
        'status': 'open',
      },
    ),
  ];
  final faqs = [
    const SupportFaq(
      id: 'faq-1',
      data: {
        'question': '¿Cómo reciclo?',
        'answer': 'Separa los materiales.',
        'active': true,
      },
    ),
  ];
  String? updatedTicketStatus;
  String? updatedTicketResponse;
  String? createdTicketSubject;
  String? createdTicketUserId;
  String? savedFaqId;
  String? savedFaqQuestion;
  String? queuedNotificationTitle;
  String? queuedNotificationUserId;

  @override
  Stream<List<SupportTicket>> watchTickets() => Stream.value(tickets);

  @override
  Stream<List<SupportFaq>> watchFaqs() => Stream.value(faqs);

  @override
  Stream<List<SupportNotification>> watchNotifications() =>
      Stream.value(const []);

  @override
  Future<void> createTicket({
    required String subject,
    required String description,
    required String userId,
  }) async {
    createdTicketSubject = subject;
    createdTicketUserId = userId;
  }

  @override
  Future<void> updateTicket(
    String id, {
    required String status,
    required String response,
  }) async {
    updatedTicketStatus = status;
    updatedTicketResponse = response;
  }

  @override
  Future<void> saveFaq({
    String? id,
    required String question,
    required String answer,
    required bool active,
  }) async {
    savedFaqId = id;
    savedFaqQuestion = question;
  }

  @override
  Future<void> deleteFaq(String id) async {}

  @override
  Future<void> enqueueNotification({
    required String title,
    required String body,
    String? userId,
  }) async {
    queuedNotificationTitle = title;
    queuedNotificationUserId = userId;
  }
}
