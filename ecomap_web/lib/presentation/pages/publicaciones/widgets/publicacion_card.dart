import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../domain/entities/publicacion_entity.dart';

class PublicacionCard extends StatelessWidget {
  const PublicacionCard({
    required this.publicacion,
    required this.vendedorEmail,
    required this.onDetails,
    required this.onToggleActive,
    super.key,
  });

  final PublicacionEntity publicacion;
  final String vendedorEmail;
  final VoidCallback onDetails;
  final VoidCallback onToggleActive;

  @override
  Widget build(BuildContext context) {
    final status = _status(publicacion);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
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
                  visualDensity: VisualDensity.compact,
                  side: BorderSide.none,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              publicacion.descripcion,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Chip(
                  avatar: const Icon(Icons.recycling_outlined, size: 16),
                  label: Text(publicacion.categoria),
                  visualDensity: VisualDensity.compact,
                ),
                Text('Peso: ${_formatNumber(publicacion.peso)} kg'),
                Text('Precio: \$${_formatNumber(publicacion.precioSugerido)}'),
                Chip(
                  label: Text(_qualityLabel(publicacion.calidad)),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            Text(
              'Publicado por: ${vendedorEmail.isEmpty ? 'No disponible' : vendedorEmail} · '
              '${_formatDate(publicacion.fechaPublicacion)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
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
                if (publicacion.estado == 'disponible')
                  Tooltip(
                    message:
                        'La venta se confirma al finalizar una oferta en la página de Ofertas.',
                    child: OutlinedButton.icon(
                      onPressed: null,
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Marcar como vendida'),
                    ),
                  ),
                OutlinedButton.icon(
                  onPressed: onToggleActive,
                  icon: Icon(publicacion.estadoActivo
                      ? Icons.toggle_on_outlined
                      : Icons.toggle_off_outlined),
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

({String label, Color color}) _status(PublicacionEntity publication) {
  if (!publication.estadoActivo) {
    return (label: 'Inactiva', color: AppColors.error);
  }
  return switch (publication.estado) {
    'disponible' => (label: 'Disponible', color: AppColors.success),
    'reservado' => (label: 'Reservada', color: Colors.blue),
    'vendido' => (label: 'Vendida', color: AppColors.textSecondary),
    _ => (label: publication.estado, color: AppColors.warning),
  };
}

String _qualityLabel(String quality) => switch (quality.toLowerCase()) {
      'nuevo' => 'Nuevo',
      'usado' => 'Usado',
      _ => quality,
    };

String _formatNumber(double value) => value == value.roundToDouble()
    ? value.toStringAsFixed(0)
    : value.toStringAsFixed(1);

String _formatDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/'
    '${date.month.toString().padLeft(2, '0')}/'
    '${date.year}';