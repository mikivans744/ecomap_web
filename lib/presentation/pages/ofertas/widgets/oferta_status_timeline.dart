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
        state: 'OFERTADA',
        label: 'Oferta enviada al centro',
        at: _validTimestamp(oferta.createdAt),
      ),
      (state: 'ACEPTADA', label: 'Aceptada por el centro', at: null),
      (state: 'ENTREGADA', label: 'Recepción confirmada', at: null),
    ];
    final activeIndex =
        events.indexWhere((event) => event.state == oferta.estado);
    final isCancelled = oferta.estado == 'RECHAZADA';
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
          const _TimelineRow(
            label: 'Oferta rechazada',
            timestamp: null,
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

DateTime? _validTimestamp(DateTime? date) {
  if (date == null || date.millisecondsSinceEpoch <= 0 || date.year < 1970) {
    return null;
  }
  return date;
}

String _formatDateTime(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/'
    '${date.month.toString().padLeft(2, '0')}/'
    '${date.year} ${date.hour.toString().padLeft(2, '0')}:'
    '${date.minute.toString().padLeft(2, '0')}';
