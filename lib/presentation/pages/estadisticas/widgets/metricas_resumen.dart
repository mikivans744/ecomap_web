import 'package:flutter/material.dart';

import '../../../../presentation/providers/estadisticas_providers.dart';

class MetricasResumenGrid extends StatelessWidget {
  const MetricasResumenGrid({required this.metrics, super.key});
  final MetricasResumen metrics;
  @override
  Widget build(BuildContext context) => GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: MediaQuery.sizeOf(context).width > 900 ? 4 : 2,
          childAspectRatio: 2.2,
          children: [
            _card(
                'Transacciones', '${metrics.transacciones}', Icons.swap_horiz),
            _card('Peso promedio',
                '${metrics.pesoPromedio.toStringAsFixed(1)} kg', Icons.scale),
            _card(
                'Recaudación estimada',
                '\$${metrics.recaudacion.toStringAsFixed(2)}',
                Icons.attach_money),
            _card(
                'Conversión',
                '${(metrics.conversion * 100).toStringAsFixed(1)}%',
                Icons.trending_up),
            _card('Usuarios activos', '${metrics.usuariosActivos}',
                Icons.people_outline),
            _card('Publicaciones activas', '${metrics.publicacionesActivas}',
                Icons.inventory_2_outlined),
            _card('Solicitudes pendientes', '${metrics.solicitudesPendientes}',
                Icons.pending_actions_outlined),
          ]);
  Widget _card(String title, String value, IconData icon) => Card(
      child: ListTile(
          leading: Icon(icon, color: Colors.green),
          title: Text(title),
          subtitle: Text(value,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 18))));
}
