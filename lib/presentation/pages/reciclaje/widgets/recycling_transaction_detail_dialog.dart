import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../domain/entities/recycling_transaction.dart';

class RecyclingTransactionDetailDialog extends StatelessWidget {
  const RecyclingTransactionDetailDialog({
    super.key,
    required this.transaction,
    required this.userName,
    required this.collectorName,
  });

  final RecyclingTransaction transaction;
  final String userName;
  final String collectorName;

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
              _DetailRow(label: 'Transacción', value: transaction.id),
              _DetailRow(
                label: 'Material',
                value: transaction.materialCategory.isEmpty
                    ? 'Sin categoría'
                    : transaction.materialCategory,
              ),
              _DetailRow(label: 'Usuario', value: userName),
              _DetailRow(label: 'ID de usuario', value: transaction.userId),
              _DetailRow(label: 'Recolector', value: collectorName),
              _DetailRow(
                label: 'ID de recolector',
                value: transaction.collectorId,
              ),
              _DetailRow(
                label: 'Peso',
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
                value:
                    DateFormat.yMMMd().add_jm().format(transaction.createdAt),
              ),
              if (transaction.completedAt != null)
                _DetailRow(
                  label: 'Fecha de finalización',
                  value: DateFormat.yMMMd()
                      .add_jm()
                      .format(transaction.completedAt!),
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
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

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
            Expanded(child: SelectableText(value)),
          ],
        ),
      );
}
