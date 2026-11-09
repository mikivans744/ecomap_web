import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../domain/entities/recycling_transaction.dart';

class RecyclingTransactionDetailDialog extends StatelessWidget {
  const RecyclingTransactionDetailDialog({
    super.key,
    required this.transaction,
    this.categoryLabel,
    required this.userName,
    required this.collectorName,
    required this.centerName,
    this.onOpenCollector,
    this.onOpenCenter,
  });

  final RecyclingTransaction transaction;
  final String? categoryLabel;
  final String userName;
  final String collectorName;
  final String centerName;
  final VoidCallback? onOpenCollector;
  final VoidCallback? onOpenCenter;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Detalle de reciclaje'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DetailRow(
                label: 'Transacción',
                value: transaction.isCenterOffer
                    ? transaction.id.replaceFirst('oferta_', '')
                    : transaction.id,
              ),
              _DetailRow(
                label: 'Material',
                value: categoryLabel ??
                    (transaction.materialCategory.isEmpty
                        ? 'Sin categoría'
                        : transaction.materialCategory),
              ),
              _DetailRow(label: 'Usuario', value: userName),
              if (transaction.userId.isNotEmpty)
                _DetailRow(label: 'ID de usuario', value: transaction.userId),
              _DetailRow(
                label: 'Recolector',
                value: collectorName,
                onTap: onOpenCollector,
              ),
              _DetailRow(
                label: 'ID de recolector',
                value: transaction.collectorId,
              ),
              _DetailRow(
                label: 'Centro',
                value: centerName,
                onTap: onOpenCenter,
              ),
              if (transaction.centerId.isNotEmpty)
                _DetailRow(label: 'ID de centro', value: transaction.centerId),
              _DetailRow(
                label: 'Peso',
                value: '${transaction.weightKg.toStringAsFixed(2)} kg',
              ),
              if (transaction.isCenterOffer)
                _DetailRow(
                  label: 'Peso confirmado',
                  value: '${transaction.weightKg.toStringAsFixed(2)} kg',
                ),
              _DetailRow(
                label: 'Puntos otorgados',
                value: transaction.pointsAwarded.toString(),
              ),
              _DetailRow(
                label: 'Estado',
                value: _statusLabel(transaction.status),
              ),
              _DetailRow(
                label: 'Fecha de creación',
                value: _formatRecyclingDate(transaction.createdAt),
              ),
              if (transaction.completedAt != null)
                _DetailRow(
                  label: 'Fecha de finalización',
                  value: _formatRecyclingDate(transaction.completedAt!),
                ),
              if (transaction.signatureUrl?.isNotEmpty == true)
                _DetailRow(
                  label: 'Firma',
                  value: transaction.signatureUrl!,
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }

  String _statusLabel(RecyclingTransactionStatus status) => switch (status) {
        RecyclingTransactionStatus.pending => 'Pendiente',
        RecyclingTransactionStatus.assigned => 'Asignada',
        RecyclingTransactionStatus.completed => 'Completada',
        RecyclingTransactionStatus.cancelled => 'Cancelada',
      };
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 145,
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            Expanded(
              child: onTap == null
                  ? SelectableText(value.isEmpty ? 'No disponible' : value)
                  : TextButton(
                      onPressed: onTap,
                      style: TextButton.styleFrom(
                        alignment: Alignment.centerLeft,
                        padding: EdgeInsets.zero,
                      ),
                      child: Text(value),
                    ),
            ),
          ],
        ),
      );
}

String _formatRecyclingDate(DateTime date) {
  if (date.millisecondsSinceEpoch <= 0) return 'Sin fecha';
  return DateFormat('dd/MM/yyyy HH:mm').format(date);
}
