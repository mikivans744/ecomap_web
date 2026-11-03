import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../domain/entities/oferta_entity.dart';

class OfertaCard extends StatelessWidget {
  const OfertaCard({
    required this.oferta,
    required this.recolectorNombre,
    required this.centroNombre,
    required this.placa,
    required this.onDetails,
    required this.actions,
    super.key,
  });

  final OfertaEntity oferta;
  final String recolectorNombre;
  final String centroNombre;
  final String? placa;
  final VoidCallback onDetails;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final status = _status(oferta.estado);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Oferta #${oferta.id.substring(0, oferta.id.length < 8 ? oferta.id.length : 8)}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                Chip(
                  label: Text(status.label),
                  backgroundColor: status.color.withOpacity(0.12),
                  labelStyle: TextStyle(color: status.color),
                  visualDensity: VisualDensity.compact,
                  side: BorderSide.none,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 24,
              runSpacing: 8,
              children: [
                _info(Icons.local_shipping_outlined, recolectorNombre),
                _info(Icons.warehouse_outlined, centroNombre),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Chip(
                  avatar: const Icon(Icons.recycling_outlined, size: 16),
                  label: Text(oferta.categoria),
                  visualDensity: VisualDensity.compact,
                ),
                Text('Peso: ${_formatNumber(oferta.peso)} kg'),
                Text('Precio: ${_formatCurrency(oferta.precioSugerido)}'),
              ],
            ),
            Text(
              'Oferta: ${_formatDate(oferta.createdAt)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            if ((oferta.estado == 'ACEPTADA' || oferta.estado == 'ENTREGADA') &&
                placa != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('Vehículo: $placa'),
              ),
            const Divider(height: 20),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: onDetails,
                  icon: const Icon(Icons.visibility_outlined),
                  label: const Text('Ver detalle'),
                ),
                ...actions,
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _info(IconData icon, String label) => ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: AppColors.textSecondary),
            const SizedBox(width: 8),
            Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
          ],
        ),
      );
}

({String label, Color color}) _status(String state) => switch (state) {
      'OFERTADA' => (label: 'Ofertada', color: AppColors.warning),
      'ACEPTADA' => (label: 'Aceptada', color: Colors.blue),
      'ENTREGADA' => (label: 'Entregada', color: AppColors.success),
      'RECHAZADA' => (label: 'Rechazada', color: AppColors.error),
      _ => (label: state, color: AppColors.textSecondary),
    };

String _formatDate(DateTime? date) {
  if (date == null || date.millisecondsSinceEpoch <= 0 || date.year < 1970) {
    return 'Sin fecha';
  }
  return '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/'
      '${date.year} ${date.hour.toString().padLeft(2, '0')}:'
      '${date.minute.toString().padLeft(2, '0')}';
}

String _formatNumber(double value) => value == value.roundToDouble()
    ? value.toStringAsFixed(0)
    : value.toStringAsFixed(1);

String _formatCurrency(double value) => '\$${_formatNumber(value)}';
