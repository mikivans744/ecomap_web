import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class EstadisticasFiltros {
  const EstadisticasFiltros({this.desde, this.hasta, this.estado = 'todos'});
  final DateTime? desde;
  final DateTime? hasta;
  final String estado;
  EstadisticasFiltros copyWith(
          {DateTime? desde, DateTime? hasta, String? estado}) =>
      EstadisticasFiltros(
          desde: desde ?? this.desde,
          hasta: hasta ?? this.hasta,
          estado: estado ?? this.estado);
}

class MaterialesMes {
  const MaterialesMes({required this.mes, required this.valores});
  final String mes;
  final Map<String, double> valores;
}

class CategoriaDistribucion {
  const CategoriaDistribucion({required this.categoria, required this.kilos});
  final String categoria;
  final double kilos;
}

class RecolectorStats {
  const RecolectorStats(
      {required this.nombre, required this.kilos, required this.ofertas});
  final String nombre;
  final double kilos;
  final int ofertas;
}

class UsuarioActivoMes {
  const UsuarioActivoMes(
      {required this.mes,
      required this.ciudadanos,
      required this.recolectores,
      required this.centros});
  final String mes;
  final int ciudadanos;
  final int recolectores;
  final int centros;
}

class CentroStats {
  const CentroStats(
      {required this.nombre, required this.maxima, required this.comprometida});
  final String nombre;
  final double maxima;
  final double comprometida;
}

class MetricasResumen {
  const MetricasResumen({
    required this.transacciones,
    required this.pesoPromedio,
    required this.recaudacion,
    required this.conversion,
    required this.usuariosActivos,
    required this.publicacionesActivas,
    required this.solicitudesPendientes,
  });
  final int transacciones;
  final double pesoPromedio;
  final double recaudacion;
  final double conversion;
  final int usuariosActivos;
  final int publicacionesActivas;
  final int solicitudesPendientes;
}

final estadisticasFiltrosProvider =
    StateProvider<EstadisticasFiltros>((ref) => const EstadisticasFiltros());

DateTime _date(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is num) return DateTime.fromMillisecondsSinceEpoch(value.toInt());
  if (value is String) return DateTime.tryParse(value) ?? DateTime(1970);
  return DateTime(1970);
}

bool _inRange(DateTime value, EstadisticasFiltros filters) =>
    (filters.desde == null || !value.isBefore(filters.desde!)) &&
    (filters.hasta == null || !value.isAfter(filters.hasta!));

double _number(dynamic value) => value is num ? value.toDouble() : 0;

Future<List<Map<String, dynamic>>> _collection(String name) async {
  final snapshot = await FirebaseFirestore.instance.collection(name).get();
  return snapshot.docs
      .map((document) => <String, dynamic>{...document.data(), 'id': document.id})
      .toList(growable: false);
}

Future<List<Map<String, dynamic>>> _offers(
    EstadisticasFiltros filters) async {
  final offers = await _collection('ofertas_centro');
  return offers
      .where((data) =>
          _inRange(_date(data['createdAt'] ?? 0), filters) &&
          (filters.estado == 'todos' ||
              (data['estado'] == 'OFERTADA' ||
                      data['estado'] == 'ACEPTADA') ==
                  (filters.estado == 'activos')))
      .toList(growable: false);
}

final materialesPorMesProvider =
    FutureProvider<List<MaterialesMes>>((ref) async {
  final filters = ref.watch(estadisticasFiltrosProvider);
  final offers = await _offers(filters);
  final grouped = <String, Map<String, double>>{};
  for (final offer in offers) {
    final date = _date(offer['createdAt'] ?? 0);
    final key = '${date.year}-${date.month.toString().padLeft(2, '0')}';
    final category = offer['categoria'] as String? ?? 'otro';
    grouped.putIfAbsent(key, () => {})[category] =
        (grouped[key]?[category] ?? 0) + _number(offer['pesoKg']);
  }
  final keys = grouped.keys.toList()..sort();
  return keys
      .map((key) => MaterialesMes(mes: key, valores: grouped[key]!))
      .toList(growable: false);
});

final distribucionCategoriasProvider =
    FutureProvider<List<CategoriaDistribucion>>((ref) async {
  final filters = ref.watch(estadisticasFiltrosProvider);
  final offers = await _offers(filters);
  final totals = <String, double>{};
  for (final offer in offers) {
    final key = offer['categoria'] as String? ?? 'otro';
    totals[key] = (totals[key] ?? 0) + _number(offer['pesoKg']);
  }
  return totals.entries
      .map((entry) =>
          CategoriaDistribucion(categoria: entry.key, kilos: entry.value))
      .toList(growable: false);
});

final topRecolectoresProvider =
    FutureProvider<List<RecolectorStats>>((ref) async {
  final filters = ref.watch(estadisticasFiltrosProvider);
  final offers = await _offers(filters);
  final stats = <String, RecolectorStats>{};
  final users = await _collection('usuarios');
  final nameById = {
    for (final user in users)
      if (user['rol'] == 'RECOLECTOR')
        user['uid'] as String? ?? user['id'] as String:
            user['nombre'] as String? ?? user['id'] as String
  };
  for (final offer in offers) {
    final id = offer['recolectorId'] as String? ?? '';
    final old = stats[id];
    stats[id] = RecolectorStats(
        nombre: nameById[id] ?? id,
        kilos: (old?.kilos ?? 0) + _number(offer['pesoKg']),
        ofertas: (old?.ofertas ?? 0) + 1);
  }
  final result = stats.values.toList()
    ..sort((a, b) => b.kilos.compareTo(a.kilos));
  return result.take(10).toList(growable: false);
});

final usuariosActivosTendenciaProvider =
    FutureProvider<List<UsuarioActivoMes>>((ref) async {
  final filters = ref.watch(estadisticasFiltrosProvider);
  final users = await _collection('usuarios');
  final counts = <String, Map<String, int>>{};
  for (final user in users) {
    if (user['activo'] == false) continue;
    final createdAt = user['createdAt'] ?? user['creado_at'];
    final date = _date(createdAt);
    if (!_inRange(date, filters)) continue;
    final key = '${date.year}-${date.month.toString().padLeft(2, '0')}';
    final roles = counts.putIfAbsent(
        key, () => {'CIUDADANO': 0, 'RECOLECTOR': 0, 'CENTRO_ACOPIO': 0});
    final role = user['rol'] as String?;
    if (roles.containsKey(role)) roles[role!] = roles[role]! + 1;
  }
  final keys = counts.keys.toList()..sort();
  return keys
      .map((key) => UsuarioActivoMes(
          mes: key,
          ciudadanos: counts[key]?['CIUDADANO'] ?? 0,
          recolectores: counts[key]?['RECOLECTOR'] ?? 0,
          centros: counts[key]?['CENTRO_ACOPIO'] ?? 0))
      .toList(growable: false);
});

final comparativoCentrosProvider =
    FutureProvider<List<CentroStats>>((ref) async {
  final filters = ref.watch(estadisticasFiltrosProvider);
  final centers = (await _collection('usuarios'))
      .where((user) => user['rol'] == 'CENTRO_ACOPIO')
      .toList(growable: false);
  final offers = await _offers(filters);
  final committed = <String, double>{};
  for (final offer in offers.where((data) => data['estado'] == 'ACEPTADA')) {
    final centerId = offer['centroId'] as String? ?? '';
    committed[centerId] =
        (committed[centerId] ?? 0) + _number(offer['pesoKg']);
  }
  return centers
      .map((user) => CentroStats(
            nombre: user['nombre_empresa'] as String? ?? user['id'] as String,
            maxima: 0,
            comprometida: committed[user['uid'] as String? ??
                    user['id'] as String] ??
                0,
          ))
      .toList(growable: false);
});

final metricasResumenProvider = FutureProvider<MetricasResumen>((ref) async {
  final filters = ref.watch(estadisticasFiltrosProvider);
  final results = await Future.wait([
    _offers(filters),
    _collection('usuarios'),
    _collection('publicaciones'),
    _collection('solicitudes'),
  ]);
  final offers = results[0];
  final users = results[1];
  final publications = results[2];
  final requests = results[3];
  final delivered =
      offers.where((offer) => offer['estado'] == 'ENTREGADA').toList();
  final totalWeight = offers.fold<double>(
      0, (total, item) => total + _number(item['pesoKg']));
  final completedRequests =
      requests.where((request) => request['estado'] == 'COMPLETADA').length;
  final consideredRequests = requests
      .where((request) => request['estado'] != 'CANCELADA')
      .length;
  final revenue = delivered.fold<double>(
      0, (total, item) => total + _number(item['precioSugerido']));
  final activeUsers = users.where((user) => user['activo'] != false).length;
  final activePublications = publications
      .where((publication) =>
          publication['estado'] == 'DISPONIBLE' ||
          publication['estado'] == 'RESERVADO')
      .length;
  final pendingRequests =
      requests.where((request) => request['estado'] == 'SOLICITADA').length;

  return MetricasResumen(
    transacciones: completedRequests,
    pesoPromedio: offers.isEmpty ? 0 : totalWeight / offers.length,
    recaudacion: revenue,
    conversion:
        consideredRequests == 0 ? 0 : completedRequests / consideredRequests,
    usuariosActivos: activeUsers,
    publicacionesActivas: activePublications,
    solicitudesPendientes: pendingRequests,
  );
});
