import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../domain/entities/centro_acopio_entity.dart';
import '../../../../domain/entities/oferta_entity.dart';
import '../../../../domain/entities/recolector_entity.dart';
import 'oferta_status_timeline.dart';

class OfertaDetailDialog extends StatelessWidget {
  const OfertaDetailDialog({
    required this.oferta,
    this.recolector,
    this.centro,
    super.key,
  });

  final OfertaEntity oferta;
  final RecolectorEntity? recolector;
  final CentroAcopioEntity? centro;

  @override
  Widget build(BuildContext context) {
    final center = centro;
    final vehicle = recolector?.vehiculoInfo ?? const <String, dynamic>{};
    return AlertDialog(
      title: Text(
          'Oferta #${oferta.id.substring(0, oferta.id.length < 8 ? oferta.id.length : 8)}'),
      content: SizedBox(
        width: 540,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _row('Estado', oferta.estado),
              _row('Material', oferta.categoria),
              _row('Peso', '${oferta.peso} kg'),
              _row('Precio sugerido', '\$${oferta.precioSugerido}'),
              _row('Fecha de oferta', _formatDate(oferta.createdAt)),
              const Divider(height: 24),
              Text('Recolector', style: Theme.of(context).textTheme.titleSmall),
              _row('Nombre', recolector?.nombreCompleto ?? oferta.recolectorId),
              _row('Teléfono', recolector?.telefono ?? 'No disponible'),
              _row(
                  'Vehículo',
                  recolector?.medioTransporte == 'vehiculo'
                      ? '${vehicle['marca'] ?? ''} · ${vehicle['placa'] ?? ''}'
                      : recolector?.medioTransporte ?? 'No disponible'),
              const SizedBox(height: 12),
              Text('Centro', style: Theme.of(context).textTheme.titleSmall),
              _row('Nombre', center?.nombre ?? 'Centro sin asignar'),
              _row('Dirección', center?.direccion ?? 'No disponible'),
              _row(
                'Capacidad restante',
                center == null
                    ? 'No disponible'
                    : '${(center.capacidadMaxima - center.kilosComprometidos).clamp(0, double.infinity)} kg',
              ),
              const Divider(height: 24),
              Text('Flujo de la oferta',
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 12),
              OfertaStatusTimeline(oferta: oferta),
              if (oferta.cancelReason != null)
                Text(
                  'Motivo de cancelación: ${oferta.cancelReason}',
                  style: const TextStyle(color: AppColors.error),
                ),
            ],
          ),
        ),
      ),
      actions: [
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
              width: 140,
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

String _formatDate(DateTime? date) {
  if (date == null || date.millisecondsSinceEpoch <= 0 || date.year < 1970) {
    return 'Sin fecha';
  }
  return '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/'
      '${date.year} ${date.hour.toString().padLeft(2, '0')}:'
      '${date.minute.toString().padLeft(2, '0')}';
}
