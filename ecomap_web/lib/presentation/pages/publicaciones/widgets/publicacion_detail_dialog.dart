import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../domain/entities/oferta_entity.dart';
import '../../../../domain/entities/publicacion_entity.dart';
import '../../../../domain/entities/user_entity.dart';

class PublicacionDetailDialog extends StatelessWidget {
  const PublicacionDetailDialog({
    required this.publicacion,
    required this.onToggleActive,
    this.vendedor,
    this.ofertas = const [],
    super.key,
  });

  final PublicacionEntity publicacion;
  final VoidCallback onToggleActive;
  final UserEntity? vendedor;
  final List<OfertaEntity> ofertas;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(publicacion.titulo),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _row('Descripción', publicacion.descripcion),
              _row('Categoría', publicacion.categoria),
              _row('Peso', '${publicacion.peso} kg'),
              _row('Precio sugerido', '\$${publicacion.precioSugerido}'),
              _row('Calidad', publicacion.calidad),
              _row('Estado', publicacion.estado),
              _row('Activa', publicacion.estadoActivo ? 'Sí' : 'No'),
              _row('Publicada', _formatDate(publicacion.fechaPublicacion)),
              if (publicacion.estado == 'disponible')
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'La publicación se marcará como vendida al finalizar una oferta desde Ofertas.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              const Divider(height: 24),
              Text('Vendedor', style: Theme.of(context).textTheme.titleSmall),
              _row('Nombre', vendedor?.nombre ?? 'No disponible'),
              _row('Email', vendedor?.email ?? publicacion.userId),
              _row('Teléfono', vendedor?.telefono ?? 'No disponible'),
              const Divider(height: 24),
              Text('Historial de ofertas',
                  style: Theme.of(context).textTheme.titleSmall),
              if (ofertas.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text(
                    'No hay ofertas asociadas.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                )
              else
                ...ofertas.map(
                  (offer) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.local_offer_outlined),
                    title: Text('${offer.peso} kg · ${offer.estado}'),
                    subtitle: Text(_formatDate(offer.fechaOferta)),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        if (publicacion.estado == 'disponible')
          Tooltip(
            message:
                'La venta se confirma al finalizar una oferta desde Ofertas.',
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
          label: Text(publicacion.estadoActivo ? 'Desactivar' : 'Activar'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 130,
              child: Text(
                label,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ),
            Expanded(child: Text(value)),
          ],
        ),
      );
}

String _formatDate(DateTime date) => '${date.day.toString().padLeft(2, '0')}/'
    '${date.month.toString().padLeft(2, '0')}/'
    '${date.year.toString().padLeft(4, '0')}';
