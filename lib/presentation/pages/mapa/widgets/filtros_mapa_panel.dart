import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../providers/mapa_providers.dart';

class FiltrosMapaPanel extends ConsumerWidget {
  const FiltrosMapaPanel({super.key});

  static const zones = [
    null,
    'Zona Norte',
    'Zona Sur',
    'Zona Este',
    'Zona Oeste',
    'Centro'
  ];
  static const materials = [
    null,
    'plastico',
    'vidrio',
    'metal',
    'papel',
    'organico',
    'textil',
    'electronico'
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = ref.watch(mapaFiltrosProvider);
    final notifier = ref.read(mapaFiltrosProvider.notifier);
    return Card(
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Filtros del mapa',
              style: TextStyle(fontWeight: FontWeight.bold)),
          CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text('Recolectores'),
              value: filters.mostrarRecolectores,
              onChanged: (value) => notifier.state =
                  filters.copyWith(mostrarRecolectores: value)),
          CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text('Centros'),
              value: filters.mostrarCentros,
              onChanged: (value) =>
                  notifier.state = filters.copyWith(mostrarCentros: value)),
          CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text('Publicaciones'),
              value: filters.mostrarPublicaciones,
              onChanged: (value) => notifier.state =
                  filters.copyWith(mostrarPublicaciones: value)),
          DropdownButtonFormField<String?>(
              value: filters.zona,
              decoration: const InputDecoration(labelText: 'Zona'),
              items: zones
                  .map((zone) => DropdownMenuItem(
                      value: zone, child: Text(zone ?? 'Todas')))
                  .toList(),
              onChanged: (value) => notifier.state = MapaFiltros(
                  mostrarRecolectores: filters.mostrarRecolectores,
                  mostrarCentros: filters.mostrarCentros,
                  mostrarPublicaciones: filters.mostrarPublicaciones,
                  zona: value,
                  material: filters.material)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String?>(
              value: filters.material,
              decoration: const InputDecoration(labelText: 'Material'),
              items: materials
                  .map((material) => DropdownMenuItem(
                      value: material, child: Text(material ?? 'Todos')))
                  .toList(),
              onChanged: (value) => notifier.state = MapaFiltros(
                  mostrarRecolectores: filters.mostrarRecolectores,
                  mostrarCentros: filters.mostrarCentros,
                  mostrarPublicaciones: filters.mostrarPublicaciones,
                  zona: filters.zona,
                  material: value)),
        ]),
      ),
    );
  }
}
