import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/theme/app_colors.dart';
import '../../../domain/entities/centro_acopio_entity.dart';
import '../../../domain/entities/publicacion_entity.dart';
import '../../../domain/entities/recolector_entity.dart';
import '../../providers/mapa_providers.dart';
import '../../widgets/scaffold_with_navigation.dart';
import 'widgets/filtros_mapa_panel.dart';
import 'widgets/marcador_centro.dart';
import 'widgets/marcador_publicacion.dart';
import 'widgets/marcador_recolector.dart';
import 'widgets/popup_info.dart';

class MapaPage extends ConsumerWidget {
  const MapaPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final centersAsync = ref.watch(centrosMapaProvider);
    final collectorsAsync = ref.watch(recolectoresMapaProvider);
    final publicationsAsync = ref.watch(publicacionesMapaProvider);
    final filters = ref.watch(mapaFiltrosProvider);
    final centers = centersAsync.valueOrNull ?? const <CentroAcopioEntity>[];
    final collectors =
        collectorsAsync.valueOrNull ?? const <RecolectorEntity>[];
    final publications =
        publicationsAsync.valueOrNull ?? const <PublicacionEntity>[];
    final markers = _buildMarkers(
      context,
      filters: filters,
      centers: centers,
      collectors: collectors,
      publications: publications,
    );
    final error =
        centersAsync.error ?? collectorsAsync.error ?? publicationsAsync.error;
    final loading = centersAsync.isLoading ||
        collectorsAsync.isLoading ||
        publicationsAsync.isLoading;
    final recordsWithLocation =
        _countRecordsWithLocation(centers, collectors, publications);
    final totalRecords =
        centers.length + collectors.length + publications.length;
    final firstPoint = _firstPoint(
      filters: filters,
      centers: centers,
      collectors: collectors,
      publications: publications,
    );

    return ScaffoldWithNavigation(
      title: 'Mapa',
      currentPath: '/mapa',
      body: LayoutBuilder(
        builder: (context, constraints) {
          final panelWidth = (constraints.maxWidth - 32).clamp(0.0, 300.0);
          return Stack(
            children: [
              FlutterMap(
                key: ValueKey('mapa_flutter_map_${firstPoint ?? 'empty'}'),
                options: MapOptions(
                  initialCenter: firstPoint ?? const LatLng(0, 0),
                  initialZoom: firstPoint == null ? 2 : 12,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.ecomap.web',
                    errorTileCallback: (_, error, stackTrace) {
                      if (error.toString().contains('abortTrigger')) return;
                      debugPrint(
                        'No se pudo cargar un tile del mapa: $error'
                        '${stackTrace == null ? '' : '\n$stackTrace'}',
                      );
                    },
                  ),
                  MarkerLayer(markers: markers),
                  const RichAttributionWidget(
                    attributions: [
                      TextSourceAttribution(
                        'OpenStreetMap contributors',
                        prependCopyright: false,
                      ),
                    ],
                  ),
                ],
              ),
              Positioned(
                top: 16,
                left: 16,
                width: panelWidth,
                child: const SingleChildScrollView(
                  child: FiltrosMapaPanel(),
                ),
              ),
              if (loading)
                const Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  child: LinearProgressIndicator(),
                ),
              if (error != null)
                Positioned(
                  right: 16,
                  top: 16,
                  width: (constraints.maxWidth - 32).clamp(0.0, 360.0),
                  child: _MapError(
                    error: error,
                    onRetry: () {
                      ref.invalidate(centrosMapaProvider);
                      ref.invalidate(recolectoresMapaProvider);
                      ref.invalidate(publicacionesMapaProvider);
                    },
                  ),
                ),
              if (!loading && error == null && markers.isEmpty)
                Positioned(
                  left: panelWidth + 32,
                  right: 16,
                  bottom: 24,
                  child: Center(
                    child: _EmptyMapMessage(
                      hasRecords: totalRecords > 0,
                      hasCoordinates: recordsWithLocation > 0,
                    ),
                  ),
                ),
              if (error == null && recordsWithLocation > 0)
                Positioned(
                  right: 16,
                  bottom: 16,
                  child: _MapLegend(
                    markerCount: markers.length,
                    recordsWithoutLocation: totalRecords - recordsWithLocation,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  List<Marker> _buildMarkers(
    BuildContext context, {
    required MapaFiltros filters,
    required List<CentroAcopioEntity> centers,
    required List<RecolectorEntity> collectors,
    required List<PublicacionEntity> publications,
  }) {
    final markers = <Marker>[];

    if (filters.mostrarCentros) {
      for (final center in centers) {
        final point = _point(center.latitud, center.longitud);
        if (point == null) continue;
        markers.add(
          Marker(
            key: ValueKey('centro-${center.id}'),
            point: point,
            width: 44,
            height: 44,
            child: Tooltip(
              key: Key('map_marker_centro_${center.id}'),
              message: center.nombre,
              child: MarcadorCentro(
                centro: center,
                onTap: () => _showInfo(
                  context,
                  title: center.nombre,
                  rows: [
                    (label: 'Dirección', value: _orDash(center.direccion)),
                    (label: 'Zona', value: _orDash(center.zona)),
                    (
                      label: 'Materiales',
                      value: center.materialesAceptados.isEmpty
                          ? 'No especificados'
                          : center.materialesAceptados.join(', '),
                    ),
                    (
                      label: 'Capacidad',
                      value: '${center.capacidadMaxima.toStringAsFixed(1)} kg',
                    ),
                    (label: 'Horario', value: _orDash(center.horario)),
                  ],
                ),
              ),
            ),
          ),
        );
      }
    }

    if (filters.mostrarRecolectores) {
      for (final collector in collectors) {
        final point = _point(collector.latitud, collector.longitud);
        if (point == null) continue;
        markers.add(
          Marker(
            key: ValueKey('recolector-${collector.id}'),
            point: point,
            width: 44,
            height: 44,
            child: Tooltip(
              key: Key('map_marker_recolector_${collector.id}'),
              message: collector.nombreCompleto,
              child: MarcadorRecolector(
                recolector: collector,
                onTap: () => _showInfo(
                  context,
                  title: collector.nombreCompleto,
                  rows: [
                    (label: 'Zona', value: _orDash(collector.zona)),
                    (
                      label: 'Transporte',
                      value: _orDash(collector.medioTransporte),
                    ),
                    (label: 'Estado', value: 'Activo'),
                    (
                      label: 'Experiencia',
                      value: '${collector.aniosExperiencia} años',
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }
    }

    if (filters.mostrarPublicaciones) {
      for (final publication in publications) {
        final point = _point(publication.latitud, publication.longitud);
        if (point == null) continue;
        markers.add(
          Marker(
            key: ValueKey('publicacion-${publication.id}'),
            point: point,
            width: 44,
            height: 44,
            child: Tooltip(
              key: Key('map_marker_publicacion_${publication.id}'),
              message: publication.titulo,
              child: MarcadorPublicacion(
                publicacion: publication,
                onTap: () => _showInfo(
                  context,
                  title: publication.titulo,
                  rows: [
                    (label: 'Categoría', value: _orDash(publication.categoria)),
                    (label: 'Estado', value: publication.estado),
                    (
                      label: 'Peso',
                      value: '${publication.peso.toStringAsFixed(1)} kg',
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }
    }

    return markers;
  }

  void _showInfo(
    BuildContext context, {
    required String title,
    required List<({String label, String value})> rows,
  }) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  tooltip: 'Cerrar',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ),
              PopupInfo(title: title, rows: rows),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  LatLng? _point(double? latitude, double? longitude) {
    if (latitude == null ||
        longitude == null ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      return null;
    }
    return LatLng(latitude, longitude);
  }

  LatLng? _firstPoint({
    required MapaFiltros filters,
    required List<CentroAcopioEntity> centers,
    required List<RecolectorEntity> collectors,
    required List<PublicacionEntity> publications,
  }) {
    if (filters.mostrarCentros) {
      for (final center in centers) {
        final point = _point(center.latitud, center.longitud);
        if (point != null) return point;
      }
    }
    if (filters.mostrarRecolectores) {
      for (final collector in collectors) {
        final point = _point(collector.latitud, collector.longitud);
        if (point != null) return point;
      }
    }
    if (filters.mostrarPublicaciones) {
      for (final publication in publications) {
        final point = _point(publication.latitud, publication.longitud);
        if (point != null) return point;
      }
    }
    return null;
  }

  int _countRecordsWithLocation(
    List<CentroAcopioEntity> centers,
    List<RecolectorEntity> collectors,
    List<PublicacionEntity> publications,
  ) {
    final centersWithLocation = centers
        .where((item) => _point(item.latitud, item.longitud) != null)
        .length;
    final collectorsWithLocation = collectors
        .where((item) => _point(item.latitud, item.longitud) != null)
        .length;
    final publicationsWithLocation = publications
        .where((item) => _point(item.latitud, item.longitud) != null)
        .length;
    return centersWithLocation +
        collectorsWithLocation +
        publicationsWithLocation;
  }

  String _orDash(String? value) =>
      value == null || value.trim().isEmpty ? 'No especificado' : value;
}

class _MapLegend extends StatelessWidget {
  const _MapLegend({
    required this.markerCount,
    required this.recordsWithoutLocation,
  });

  final int markerCount;
  final int recordsWithoutLocation;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Marcadores: $markerCount'),
            if (recordsWithoutLocation > 0)
              Text(
                'Sin coordenadas: $recordsWithoutLocation',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
          ],
        ),
      ),
    );
  }
}

class _EmptyMapMessage extends StatelessWidget {
  const _EmptyMapMessage({
    required this.hasRecords,
    required this.hasCoordinates,
  });

  final bool hasRecords;
  final bool hasCoordinates;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.location_off_outlined),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                hasRecords && !hasCoordinates
                    ? 'Los registros no tienen coordenadas válidas (latitud y longitud) para mostrarse.'
                    : hasRecords
                        ? 'No hay ubicaciones visibles con estos filtros.'
                        : 'No hay ubicaciones disponibles con estos filtros.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapError extends StatelessWidget {
  const _MapError({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('No se pudieron cargar los datos del mapa.'),
            const SizedBox(height: 4),
            SelectableText(
              '$error',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
