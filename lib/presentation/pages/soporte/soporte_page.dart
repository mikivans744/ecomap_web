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
                    DropdownMenuItem(value: 'open', child: Text('Abiertos')),
                    DropdownMenuItem(
                      value: 'in_progress',
                      child: Text('En progreso'),
                    ),
                    DropdownMenuItem(
                      value: 'resolved',
                      child: Text('Resueltos'),
                    ),
                    DropdownMenuItem(
                      value: 'closed',
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
                    onTap: () => _manageTicket(filtered[index]),
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
                if (notifications.isEmpty) {
                  return const EmptyState(
                    message: 'No hay notificaciones registradas.',
                  );
                }
                return ListView.separated(
                  key: const Key('support_notifications_list'),
                  itemCount: notifications.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final notification = notifications[index];
                    return Card(
                      child: ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.notifications_outlined),
                        ),
                        title: Text(notification.title),
                        subtitle: Text(
                          '${notification.body}\n'
                          '${_statusLabel(notification.status)} · '
                          '${_dateLabel(notification.createdAt)}',
                        ),
                        isThreeLine: true,
                        trailing: Chip(
                          label: Text(_statusLabel(notification.status)),
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

  Future<void> _manageTicket(SupportTicket ticket) async {
    var status = ticket.status;
    final responseController = TextEditingController(
      text: ticket.data['response'] as String? ?? '',
    );
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(ticket.subject),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Usuario: ${ticket.userId}'),
                  const SizedBox(height: 8),
                  Text('Creado: ${_dateLabel(ticket.createdAt)}'),
                  const SizedBox(height: 12),
                  SelectableText(ticket.description),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<String>(
                    key: const Key('ticket_status_editor'),
                    value: _ticketStatuses.contains(status) ? status : 'open',
                    decoration: const InputDecoration(labelText: 'Estado'),
                    items: _ticketStatuses
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(_statusLabel(value)),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => status = value);
                      }
                    },
                  ),
                  TextField(
                    key: const Key('ticket_response_field'),
                    controller: responseController,
                    decoration: const InputDecoration(
                      labelText: 'Respuesta o nota de resolución',
                    ),
                    minLines: 2,
                    maxLines: 4,
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
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
    if (saved == true && mounted) {
      await _runAction(
        () => ref.read(supportRepositoryProvider).updateTicket(
              ticket.id,
              status: status,
              response: responseController.text.trim(),
            ),
        success: 'Ticket actualizado.',
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

const _ticketStatuses = ['open', 'in_progress', 'resolved', 'closed'];

String _statusLabel(String status) => switch (status.toLowerCase()) {
      'open' || 'abierto' || 'abierta' => 'Abierto',
      'pending' || 'pendiente' => 'Pendiente',
      'in_progress' ||
      'in progress' ||
      'en_progreso' ||
      'en progreso' =>
        'En progreso',
      'resolved' || 'resuelto' || 'resuelta' => 'Resuelto',
      'closed' || 'cerrado' || 'cerrada' => 'Cerrado',
      'sent' || 'delivered' => 'Enviado',
      'failed' => 'Fallido',
      _ => status,
    };

String _dateLabel(DateTime date) => date.year <= 1970
    ? 'Fecha no disponible'
    : DateFormat.yMd().add_jm().format(date);

Future<void> _disposeControllers(
  Iterable<TextEditingController> controllers,
) async {
  await Future<void>.delayed(const Duration(milliseconds: 200));
  for (final controller in controllers) {
    controller.dispose();
  }
}

class _TicketCard extends StatelessWidget {
  const _TicketCard({required this.ticket, required this.onTap});

  final SupportTicket ticket;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
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
    );
  }
}
