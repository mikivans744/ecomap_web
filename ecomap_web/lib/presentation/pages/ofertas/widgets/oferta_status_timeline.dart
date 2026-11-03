import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../domain/entities/oferta_entity.dart';

class OfertaStatusTimeline extends StatelessWidget {
  const OfertaStatusTimeline({required this.oferta, super.key});

  final OfertaEntity oferta;

  @override
  Widget build(BuildContext context) {
    final events = <({String state, String label, DateTime? at})>[
      (
        state: 'pendiente',
        label: 'Oferta enviada',
        at: oferta.createdAt ?? oferta.fechaOferta
      ),
      (
        state: 'aceptada',
        label: 'Aceptada por el centro',
        at: oferta.acceptedAt
      ),
      (
        state: 'en_camino',
        label: 'Recolector en camino',
        at: oferta.inTransitAt
      ),
      (
        state: 'finalizada',
        label: 'Recepción confirmada',
        at: oferta.finalizedAt
      ),
    ];
    final activeIndex =
        events.indexWhere((event) => event.state == oferta.estado);
    final isCancelled = oferta.estado == 'cancelada';
    return Column(
      children: [
        for (var index = 0; index < events.length; index++)
          _TimelineRow(
            label: events[index].label,
            timestamp: events[index].at,
            isComplete: events[index].at != null ||
                (!isCancelled && activeIndex >= index),
            isLast: index == events.length - 1 && !isCancelled,
          ),
        if (isCancelled)
          _TimelineRow(
            label:
                'Oferta cancelada${oferta.cancelReason == null ? '' : ': ${oferta.cancelReason}'}',
            timestamp: oferta.cancelledAt,
            isComplete: true,
            isLast: true,
            color: AppColors.error,
          ),
      ],
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.label,
    required this.timestamp,
    required this.isComplete,
    required this.isLast,
    this.color,
  });

  final String label;
  final DateTime? timestamp;
  final bool isComplete;
  final bool isLast;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final activeColor = color ?? AppColors.primary;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 24,
            child: Column(
              children: [
                Icon(
                  isComplete
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  size: 18,
                  color: isComplete ? activeColor : AppColors.textSecondary,
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: isComplete
                          ? activeColor.withOpacity(0.45)
                          : AppColors.border,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label),
                  if (timestamp != null)
                    Text(
                      _formatDateTime(timestamp!),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatDateTime(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/'
    '${date.month.toString().padLeft(2, '0')}/'
    '${date.year} ${date.hour.toString().padLeft(2, '0')}:'
    '${date.minute.toString().padLeft(2, '0')}';
