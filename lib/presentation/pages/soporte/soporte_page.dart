import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../providers/support_providers.dart';
import '../../widgets/async_states.dart';
import '../../widgets/scaffold_with_navigation.dart';

class SoportePage extends ConsumerStatefulWidget {
  const SoportePage({super.key});

  @override
  ConsumerState<SoportePage> createState() => _SoportePageState();
}

class _SoportePageState extends ConsumerState<SoportePage> {
  static const _allStatuses = 'all';
  String _ticketStatus = _allStatuses;

  @override
  Widget build(BuildContext context) {
    return ScaffoldWithNavigation(
      title: 'Soporte',
      currentPath: '/soporte',
      body: DefaultTabController(
        length: 3,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Gestión de soporte'),
            bottom: const TabBar(
              isScrollable: true,
              tabs: [
                Tab(text: 'Tickets', icon: Icon(Icons.support_agent)),
                Tab(
                    text: 'Preguntas frecuentes',
                    icon: Icon(Icons.quiz_outlined)),
                Tab(
                    text: 'Notificaciones',
                    icon: Icon(Icons.notifications_outlined)),
              ],
            ),
          ),
          body: TabBarView(
            children: [
              _buildTicketsTab(),
              _buildFaqTab(),
              _buildNotificationsTab(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTicketsTab() {
    final ticketsAsync = ref.watch(supportTicketsProvider);
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 340,
                child: DropdownButtonFormField<String>(
                  key: const Key('support_ticket_status_filter'),
                  value: _ticketStatus,
                  decoration: const InputDecoration(
                    labelText: 'Estado',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: _allStatuses,
                      child: Text('Todos los estados'),
                    ),
                    DropdownMenuItem(
                      value: 'ABIERTO',
                      child: Text('Abiertos'),
                    ),
                    DropdownMenuItem(
                      value: 'EN_PROGRESO',
                      child: Text('En progreso'),
                    ),
                    DropdownMenuItem(
                      value: 'RESPONDIDO',
                      child: Text('Respondidos'),
                    ),
                    DropdownMenuItem(
                      value: 'RESUELTO',
                      child: Text('Resueltos'),
                    ),
                    DropdownMenuItem(
                      value: 'CERRADO',
                      child: Text('Cerrados'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _ticketStatus = value);
                  },
                ),
              ),
              FilledButton.icon(
                key: const Key('create_support_ticket'),
                onPressed: _createTicket,
                icon: const Icon(Icons.add),
                label: const Text('Crear ticket'),
              ),
              IconButton(
                tooltip: 'Actualizar tickets',
                onPressed: () => ref.invalidate(supportTicketsProvider),
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ticketsAsync.when(
              loading: () => const LoadingState(
                message: 'Cargando tickets...',
              ),
              error: (error, stackTrace) => ErrorState(
                message: 'No se pudieron cargar los tickets.',
                error: error,
                onRetry: () => ref.invalidate(supportTicketsProvider),
              ),
              data: (tickets) {
                final filtered = _ticketStatus == _allStatuses
                    ? tickets
                    : tickets
                        .where((ticket) => ticket.status == _ticketStatus)
                        .toList(growable: false);
                if (filtered.isEmpty) {
                  return EmptyState(
                    message: tickets.isEmpty
                        ? 'No hay tickets de soporte.'
                        : 'No hay tickets con este estado.',
                  );
                }
                return ListView.separated(
                  key: const Key('support_tickets_list'),
                  itemCount: filtered.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 10),
                  itemBuilder: (context, index) => _TicketCard(
                    ticket: filtered[index],
                    onTap: () => _showTicketDetails(filtered[index]),
                    onTake: () =>
                        _transitionTicket(filtered[index], 'EN_PROGRESO'),
                    onRespond: () => _respondToTicket(filtered[index]),
                    onResolve: () =>
                        _transitionTicket(filtered[index], 'RESUELTO'),
                    onClose: () =>
                        _transitionTicket(filtered[index], 'CERRADO'),
                    onReopen: () =>
                        _transitionTicket(filtered[index], 'ABIERTO'),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFaqTab() {
    final faqsAsync = ref.watch(supportFaqsProvider);
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              key: const Key('create_support_faq'),
              onPressed: () => _editFaq(),
              icon: const Icon(Icons.add),
              label: const Text('Nueva pregunta'),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: faqsAsync.when(
              loading: () => const LoadingState(
                message: 'Cargando preguntas frecuentes...',
              ),
              error: (error, stackTrace) => ErrorState(
                message: 'No se pudieron cargar las preguntas frecuentes.',
                error: error,
                onRetry: () => ref.invalidate(supportFaqsProvider),
              ),
              data: (faqs) {
                if (faqs.isEmpty) {
                  return const EmptyState(
                    message: 'Todavía no hay preguntas frecuentes.',
                  );
                }
                return ListView.separated(
                  key: const Key('support_faqs_list'),
                  itemCount: faqs.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final faq = faqs[index];
                    return Card(
                      child: ListTile(
                        title: Text(
                          faq.question,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            '${faq.answer}\n${faq.isActive ? 'Activa' : 'Inactiva'}',
                          ),
                        ),
                        isThreeLine: true,
                        trailing: Wrap(
                          children: [
                            IconButton(
                              key: Key('edit_faq_${faq.id}'),
                              tooltip: 'Editar pregunta',
                              onPressed: () => _editFaq(faq: faq),
                              icon: const Icon(Icons.edit_outlined),
                            ),
                            IconButton(
                              key: Key('delete_faq_${faq.id}'),
                              tooltip: 'Eliminar pregunta',
                              onPressed: () => _deleteFaq(faq),
                              icon: const Icon(
                                Icons.delete_outline,
                                color: AppColors.error,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationsTab() {
    final notificationsAsync = ref.watch(supportNotificationsProvider);
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Card(
            color: AppColors.surfaceVariant,
            child: Padding(
              padding: EdgeInsets.all(14),
              child: Text(
                'Las notificaciones se guardan en Firestore como solicitudes '
                'pendientes. Para entregarlas como push, debe estar activo un '
                'servicio backend que procese la colección notifications.',
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              key: const Key('create_support_notification'),
              onPressed: _composeNotification,
              icon: const Icon(Icons.send_outlined),
              label: const Text('Nueva notificación'),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: notificationsAsync.when(
              loading: () => const LoadingState(
                message: 'Cargando notificaciones...',
              ),
              error: (error, stackTrace) => ErrorState(
                message: 'No se pudieron cargar las notificaciones.',
                error: error,
                onRetry: () => ref.invalidate(supportNotificationsProvider),
              ),
              data: (notifications) {
                final securityAlerts = notifications
                    .where((notification) =>
                        notification.recipientUid.toUpperCase() == 'ADMIN' &&
                        notification.type.toUpperCase() == 'SEGURIDAD')
                    .toList(growable: false);
                final sentNotifications = notifications
                    .where((notification) =>
                        notification.recipientUid.toUpperCase() != 'ADMIN')
                    .toList(growable: false);
                return ListView(
                  key: const Key('support_notifications_list'),
                  children: [
                    Text(
                      'Alertas de seguridad del móvil',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    if (securityAlerts.isEmpty)
                      const Text('No hay alertas de seguridad.')
                    else
                      ...securityAlerts.map(
                        (notification) => Card(
                          child: ListTile(
                            leading: const CircleAvatar(
                              child: Icon(Icons.security_outlined),
                            ),
                            title: Text(notification.title),
                            subtitle: Text(
                              '${notification.body}\n'
                              '${_dateLabel(notification.createdAt)}',
                            ),
                            isThreeLine: true,
                            trailing: notification.isRead
                                ? const Chip(label: Text('Leída'))
                                : TextButton(
                                    key: Key(
                                      'mark_security_notification_${notification.id}',
                                    ),
                                    onPressed: () => _runAction(
                                      () => ref
                                          .read(supportRepositoryProvider)
                                          .markNotificationRead(
                                              notification.id),
                                      success: 'Alerta marcada como leída.',
                                    ),
                                    child: const Text('Marcar leída'),
                                  ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 20),
                    Text(
                      'Notificaciones enviadas a usuarios',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    if (sentNotifications.isEmpty)
                      const Text('No hay notificaciones enviadas.')
                    else
                      ...sentNotifications.map(
                        (notification) => Card(
                          child: ListTile(
                            leading: const CircleAvatar(
                              child: Icon(Icons.notifications_outlined),
                            ),
                            title: Text(notification.title),
                            subtitle: Text(
                              '${notification.body}\n'
                              '${notification.recipientUid.isEmpty ? 'Todos los usuarios' : notification.recipientUid} · '
                              '${_statusLabel(notification.status)} · '
                              '${_dateLabel(notification.createdAt)}',
                            ),
                            isThreeLine: true,
                            trailing: Chip(
                              label: Text(_statusLabel(notification.status)),
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _createTicket() async {
    final subjectController = TextEditingController();
    final descriptionController = TextEditingController();
    final userController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Crear ticket de soporte'),
        content: SizedBox(
          width: 460,
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    key: const Key('ticket_subject_field'),
                    controller: subjectController,
                    decoration: const InputDecoration(labelText: 'Asunto'),
                    validator: _requiredValidator,
                  ),
                  TextFormField(
                    key: const Key('ticket_user_field'),
                    controller: userController,
                    decoration:
                        const InputDecoration(labelText: 'Usuario o correo'),
                    validator: _requiredValidator,
                  ),
                  TextFormField(
                    key: const Key('ticket_description_field'),
                    controller: descriptionController,
                    decoration: const InputDecoration(labelText: 'Descripción'),
                    minLines: 3,
                    maxLines: 5,
                    validator: _requiredValidator,
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.pop(dialogContext, true);
              }
            },
            child: const Text('Crear'),
          ),
        ],
      ),
    );
    if (saved == true && mounted) {
      await _runAction(
        () => ref.read(supportRepositoryProvider).createTicket(
              subject: subjectController.text.trim(),
              description: descriptionController.text.trim(),
              userId: userController.text.trim(),
            ),
        success: 'Ticket creado.',
      );
    }
    await _disposeControllers([
      subjectController,
      descriptionController,
      userController,
    ]);
  }

  Future<void> _showTicketDetails(SupportTicket ticket) async {
    final history = ticket.history;
    final legacyResponse =
        ticket.data['respuestaAdmin'] ?? ticket.data['response'];
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(ticket.subject),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Usuario: ${ticket.userId}'),
                Text('Estado: ${_statusLabel(ticket.status)}'),
                Text('Creado: ${_dateLabel(ticket.createdAt)}'),
                const Divider(height: 24),
                Text(
                  'Consulta',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 6),
                SelectableText(ticket.description),
                const Divider(height: 24),
                Text(
                  'Conversación',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                if (history.isEmpty && legacyResponse is String) ...[
                  const SizedBox(height: 8),
                  _ConversationMessage(
                    author: 'ADMIN',
                    text: legacyResponse,
                    date: _dateFromMillis(ticket.data['respondidoAt']),
                  ),
                ] else if (history.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text('Todavía no hay respuestas.'),
                  )
                else
                  ...history.map(
                    (message) => _ConversationMessage(
                      author: message['autor'] as String? ??
                          message['author'] as String? ??
                          'Usuario',
                      text: message['texto'] as String? ??
                          message['text'] as String? ??
                          '',
                      date: _dateFromMillis(message['at']),
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Future<void> _transitionTicket(
    SupportTicket ticket,
    String status,
  ) async {
    await _runAction(
      () => ref.read(supportRepositoryProvider).updateTicket(
            ticket.id,
            status: status,
            response: '',
          ),
      success: 'Ticket actualizado a ${_statusLabel(status)}.',
    );
  }

  Future<void> _respondToTicket(SupportTicket ticket) async {
    final responseController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Responder: ${ticket.subject}'),
        content: SizedBox(
          width: 480,
          child: Form(
            key: formKey,
            child: TextFormField(
              key: const Key('ticket_response_field'),
              controller: responseController,
              decoration: const InputDecoration(
                labelText: 'Respuesta al usuario',
              ),
              minLines: 3,
              maxLines: 6,
              validator: _requiredValidator,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.pop(dialogContext, true);
              }
            },
            child: const Text('Enviar respuesta'),
          ),
        ],
      ),
    );
    if (saved == true && mounted) {
      await _runAction(
        () => ref.read(supportRepositoryProvider).updateTicket(
              ticket.id,
              status: 'RESPONDIDO',
              response: responseController.text.trim(),
            ),
        success: 'Respuesta enviada al usuario.',
      );
    }
    await _disposeControllers([responseController]);
  }

  Future<void> _editFaq({SupportFaq? faq}) async {
    final questionController = TextEditingController(text: faq?.question ?? '');
    final answerController = TextEditingController(text: faq?.answer ?? '');
    final formKey = GlobalKey<FormState>();
    var active = faq?.isActive ?? true;
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(faq == null ? 'Nueva pregunta frecuente' : 'Editar FAQ'),
          content: SizedBox(
            width: 480,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    key: const Key('faq_question_field'),
                    controller: questionController,
                    decoration: const InputDecoration(labelText: 'Pregunta'),
                    validator: _requiredValidator,
                  ),
                  TextFormField(
                    key: const Key('faq_answer_field'),
                    controller: answerController,
                    decoration: const InputDecoration(labelText: 'Respuesta'),
                    minLines: 3,
                    maxLines: 6,
                    validator: _requiredValidator,
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Activa'),
                    value: active,
                    onChanged: (value) => setDialogState(() => active = value),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  Navigator.pop(dialogContext, true);
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
    if (saved == true && mounted) {
      await _runAction(
        () => ref.read(supportRepositoryProvider).saveFaq(
              id: faq?.id,
              question: questionController.text.trim(),
              answer: answerController.text.trim(),
              active: active,
            ),
        success: 'Pregunta frecuente guardada.',
      );
    }
    await _disposeControllers([questionController, answerController]);
  }

  Future<void> _deleteFaq(SupportFaq faq) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar pregunta'),
        content: Text('¿Quieres eliminar "${faq.question}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await _runAction(
        () => ref.read(supportRepositoryProvider).deleteFaq(faq.id),
        success: 'Pregunta eliminada.',
      );
    }
  }

  Future<void> _composeNotification() async {
    final titleController = TextEditingController();
    final bodyController = TextEditingController();
    final userController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var sendToAll = true;
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Nueva notificación'),
          content: SizedBox(
            width: 480,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      key: const Key('notification_title_field'),
                      controller: titleController,
                      decoration: const InputDecoration(labelText: 'Título'),
                      validator: _requiredValidator,
                    ),
                    TextFormField(
                      key: const Key('notification_body_field'),
                      controller: bodyController,
                      decoration: const InputDecoration(labelText: 'Mensaje'),
                      minLines: 3,
                      maxLines: 5,
                      validator: _requiredValidator,
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Enviar a todos'),
                      value: sendToAll,
                      onChanged: (value) =>
                          setDialogState(() => sendToAll = value),
                    ),
                    if (!sendToAll)
                      TextFormField(
                        key: const Key('notification_user_field'),
                        controller: userController,
                        decoration: const InputDecoration(
                          labelText: 'ID de usuario',
                        ),
                        validator: _requiredValidator,
                      ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton.icon(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  Navigator.pop(dialogContext, true);
                }
              },
              icon: const Icon(Icons.send_outlined),
              label: const Text('Guardar solicitud'),
            ),
          ],
        ),
      ),
    );
    if (saved == true && mounted) {
      await _runAction(
        () => ref.read(supportRepositoryProvider).enqueueNotification(
              title: titleController.text.trim(),
              body: bodyController.text.trim(),
              userId: sendToAll ? null : userController.text.trim(),
            ),
        success: 'Solicitud guardada como pendiente de envío push.',
      );
    }
    await _disposeControllers([
      titleController,
      bodyController,
      userController,
    ]);
  }

  Future<void> _runAction(
    Future<void> Function() action, {
    required String success,
  }) async {
    try {
      await action();
      if (!mounted) return;
      ref
        ..invalidate(supportTicketsProvider)
        ..invalidate(supportFaqsProvider)
        ..invalidate(supportNotificationsProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(success)),
      );
    } catch (error, stackTrace) {
      debugPrint('Error en gestión de soporte: $error\n$stackTrace');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo completar la acción: $error'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  String? _requiredValidator(String? value) =>
      value == null || value.trim().isEmpty
          ? 'Este campo es obligatorio'
          : null;
}

String _statusLabel(String status) => switch (status.toLowerCase()) {
      'open' || 'abierto' || 'abierta' => 'Abierto',
      'pending' || 'pendiente' => 'Pendiente',
      'in_progress' ||
      'in progress' ||
      'en_progreso' ||
      'en progreso' =>
        'En progreso',
      'responded' || 'respondido' || 'respondida' => 'Respondido',
      'resolved' || 'resuelto' || 'resuelta' => 'Resuelto',
      'closed' || 'cerrado' || 'cerrada' => 'Cerrado',
      'sent' || 'delivered' => 'Enviado',
      'failed' => 'Fallido',
      _ => status,
    };

String _dateLabel(DateTime date) => date.year <= 1970
    ? 'Fecha no disponible'
    : DateFormat.yMd().add_jm().format(date);

DateTime _dateFromMillis(dynamic value) => value is num
    ? DateTime.fromMillisecondsSinceEpoch(value.toInt())
    : DateTime.fromMillisecondsSinceEpoch(0);

Future<void> _disposeControllers(
  Iterable<TextEditingController> controllers,
) async {
  await Future<void>.delayed(const Duration(milliseconds: 200));
  for (final controller in controllers) {
    controller.dispose();
  }
}

class _TicketCard extends StatelessWidget {
  const _TicketCard({
    required this.ticket,
    required this.onTap,
    required this.onTake,
    required this.onRespond,
    required this.onResolve,
    required this.onClose,
    required this.onReopen,
  });

  final SupportTicket ticket;
  final VoidCallback onTap;
  final VoidCallback onTake;
  final VoidCallback onRespond;
  final VoidCallback onResolve;
  final VoidCallback onClose;
  final VoidCallback onReopen;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              key: Key('support_ticket_${ticket.id}'),
              onTap: onTap,
              leading: const CircleAvatar(
                child: Icon(Icons.support_agent_outlined),
              ),
              title: Text(
                ticket.subject,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                '${ticket.userId} · ${_dateLabel(ticket.createdAt)}\n'
                '${ticket.description}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              isThreeLine: true,
              trailing: Chip(label: Text(_statusLabel(ticket.status))),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: switch (ticket.status) {
                  'ABIERTO' => [
                      OutlinedButton.icon(
                        key: Key('take_ticket_${ticket.id}'),
                        onPressed: onTake,
                        icon: const Icon(Icons.assignment_ind_outlined),
                        label: const Text('Tomar caso'),
                      ),
                      FilledButton.icon(
                        key: Key('respond_ticket_${ticket.id}'),
                        onPressed: onRespond,
                        icon: const Icon(Icons.reply_outlined),
                        label: const Text('Responder'),
                      ),
                    ],
                  'EN_PROGRESO' => [
                      FilledButton.icon(
                        key: Key('respond_ticket_${ticket.id}'),
                        onPressed: onRespond,
                        icon: const Icon(Icons.reply_outlined),
                        label: const Text('Responder'),
                      ),
                    ],
                  'RESPONDIDO' => [
                      FilledButton.icon(
                        key: Key('resolve_ticket_${ticket.id}'),
                        onPressed: onResolve,
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text('Resolver'),
                      ),
                      OutlinedButton.icon(
                        key: Key('respond_again_ticket_${ticket.id}'),
                        onPressed: onRespond,
                        icon: const Icon(Icons.reply_outlined),
                        label: const Text('Responder de nuevo'),
                      ),
                    ],
                  'RESUELTO' => [
                      FilledButton.icon(
                        key: Key('close_ticket_${ticket.id}'),
                        onPressed: onClose,
                        icon: const Icon(Icons.lock_outline),
                        label: const Text('Cerrar'),
                      ),
                      OutlinedButton.icon(
                        key: Key('reopen_ticket_${ticket.id}'),
                        onPressed: onReopen,
                        icon: const Icon(Icons.restart_alt),
                        label: const Text('Reabrir'),
                      ),
                    ],
                  'CERRADO' => [
                      OutlinedButton.icon(
                        key: Key('reopen_ticket_${ticket.id}'),
                        onPressed: onReopen,
                        icon: const Icon(Icons.restart_alt),
                        label: const Text('Reabrir'),
                      ),
                    ],
                  _ => const <Widget>[],
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConversationMessage extends StatelessWidget {
  const _ConversationMessage({
    required this.author,
    required this.text,
    required this.date,
  });

  final String author;
  final String text;
  final DateTime date;

  @override
  Widget build(BuildContext context) => Card(
        color: AppColors.surfaceVariant,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$author · ${_dateLabel(date)}',
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const SizedBox(height: 6),
              SelectableText(text),
            ],
          ),
        ),
      );
}
