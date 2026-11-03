import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../domain/entities/recycling_transaction.dart';

class RecyclingTransactionCard extends StatelessWidget {
  const RecyclingTransactionCard({
    super.key,
    required this.transaction,
    required this.userName,
    required this.collectorName,
    required this.onTap,
  });

  final RecyclingTransaction transaction;
  final String userName;
  final String collectorName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        key: Key('recycling_transaction_${transaction.id}'),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: const CircleAvatar(
          backgroundColor: AppColors.surfaceVariant,
          child: Icon(Icons.recycling, color: AppColors.primary),
        ),
        title: Text(
          transaction.materialCategory.isEmpty
              ? 'Material sin categoría'
              : transaction.materialCategory,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Wrap(
            spacing: 16,
            runSpacing: 6,
            children: [
              _InfoLabel(
                icon: Icons.person_outline,
                label: userName,
              ),
              _InfoLabel(
                icon: Icons.local_shipping_outlined,
                label: collectorName,
              ),
              _InfoLabel(
                icon: Icons.calendar_today_outlined,
                label: DateFormat.yMMMd().format(transaction.createdAt),
              ),
            ],
          ),
        ),
        trailing: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          children: [
            Text(
              '${transaction.weightKg.toStringAsFixed(1)} kg',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            _StatusChip(status: transaction.status),
            const Icon(Icons.chevron_right),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}

class _InfoLabel extends StatelessWidget {
  const _InfoLabel({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      );
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final RecyclingTransactionStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      RecyclingTransactionStatus.pending => ('Pendiente', AppColors.warning),
      RecyclingTransactionStatus.assigned => ('Asignada', AppColors.primary),
      RecyclingTransactionStatus.completed => ('Completada', AppColors.success),
      RecyclingTransactionStatus.cancelled => ('Cancelada', AppColors.error),
    };

    return Chip(
      label: Text(label),
      visualDensity: VisualDensity.compact,
      backgroundColor: color.withOpacity(0.12),
      side: BorderSide.none,
      labelStyle: TextStyle(color: color, fontSize: 12),
    );
  }
}
