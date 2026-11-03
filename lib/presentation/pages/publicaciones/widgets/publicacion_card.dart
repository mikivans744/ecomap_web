import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../domain/entities/publicacion_entity.dart';

class PublicacionCard extends StatelessWidget {
  final PublicacionEntity publicacion;
  final VoidCallback? onTap;
  final VoidCallback? onToggleActive;
  final String? vendedorEmail;
  final VoidCallback? onDetails;
  final Function(String id, String adminId)? onSoftDelete;
  final VoidCallback? onMarkSold;

  const PublicacionCard({
    super.key,
    required this.publicacion,
    this.onTap,
    this.onToggleActive,
    this.vendedorEmail,
    this.onDetails,
    this.onSoftDelete,
    this.onMarkSold,
  });

  @override
  Widget build(BuildContext context) {
    final status = _status(publicacion.estado, publicacion.estadoActivo);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    publicacion.titulo,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                Chip(
                  label: Text(status.label),
                  backgroundColor: status.color.withOpacity(0.12),
                  labelStyle: TextStyle(color: status.color),
                  side: BorderSide.none,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              publicacion.descripcion,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                Chip(
                  avatar: const Icon(Icons.recycling_outlined, size: 16),
                  label: Text(publicacion.categoria),
                  visualDensity: VisualDensity.compact,
                ),
                Text('Peso: ${_number(publicacion.peso)} kg'),
                Text('Precio: ${_currency(publicacion.precioSugerido)}'),
                Chip(
                  label: Text(publicacion.calidad),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Publicado por: ${vendedorEmail?.isNotEmpty == true ? vendedorEmail : 'No disponible'} · ${_date(publicacion.fechaPublicacion)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            const Divider(height: 24),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: onDetails ?? onTap,
                  icon: const Icon(Icons.visibility_outlined),
                  label: const Text('Ver detalle'),
                ),
                if (publicacion.estado == 'DISPONIBLE' && onMarkSold != null)
                  FilledButton.icon(
                    onPressed: onMarkSold,
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Marcar como entregada'),
                  ),
                if (onToggleActive != null)
                  OutlinedButton.icon(
                    onPressed: onToggleActive,
                    icon: Icon(publicacion.estadoActivo
                        ? Icons.toggle_on
                        : Icons.toggle_off),
                    label: Text(
                        publicacion.estadoActivo ? 'Desactivar' : 'Activar'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

({String label, Color color}) _status(String state, bool active) {
  if (!active) return (label: 'Inactiva', color: AppColors.error);
  return switch (state) {
    'DISPONIBLE' => (label: 'Disponible', color: AppColors.success),
    'RESERVADO' => (label: 'Reservada', color: Colors.blue),
    'ENTREGADO' => (label: 'Entregada', color: AppColors.textSecondary),
    'CANCELADO' => (label: 'Cancelada', color: AppColors.error),
    _ => (label: state, color: AppColors.textSecondary),
  };
}

String _number(double value) => value == value.roundToDouble()
    ? value.toStringAsFixed(0)
    : value.toStringAsFixed(1);

String _currency(double value) => '\$${_number(value)}';

String _date(DateTime value) => '${value.day.toString().padLeft(2, '0')}/'
    '${value.month.toString().padLeft(2, '0')}/${value.year}';
