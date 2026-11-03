import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/oferta_entity.dart';
import '../../domain/entities/publicacion_entity.dart';
import '../../domain/entities/user_entity.dart';
import 'firestore_provider.dart';
import 'oferta_providers.dart';
import 'publicacion_providers.dart';
import 'user_providers.dart';

class DashboardStats {
  const DashboardStats({
    required this.totalUsuariosActivos,
    required this.materialRecicladoTotal,
    required this.reputacionPromedio,
    required this.solicitudesPendientes,
    required this.publicacionesActivas,
    required this.publicacionesVendidas,
    required this.kilosComprometidos,
    required this.ofertasPendientes,
    required this.monthlyRecyclingTotals,
    required this.recyclingByMaterial,
    required this.completedTransactions,
  });

  final int totalUsuariosActivos;
  final double materialRecicladoTotal;
  final double reputacionPromedio;
  final int solicitudesPendientes;
  final int publicacionesActivas;
  final int publicacionesVendidas;
  final double kilosComprometidos;
  final int ofertasPendientes;
  final List<MonthlyRecyclingTotal> monthlyRecyclingTotals;
  final List<MaterialRecyclingTotal> recyclingByMaterial;
  final int completedTransactions;

  factory DashboardStats.fromData({
    required List<UserEntity> activeUsers,
    required List<PublicacionEntity> publications,
    required List<OfertaEntity> centerOffers,
    required List<Map<String, dynamic>> requests,
    DateTime? now,
  }) {
    final totalReputation = activeUsers.fold<double>(
      0,
      (total, user) => total + user.reputacion,
    );
    final deliveredOffers =
        centerOffers.where((offer) => offer.estado == 'ENTREGADA').toList();
    final recycled = deliveredOffers.fold<double>(
      0,
      (total, offer) => total + (offer.weightConfirmed ?? offer.peso),
    );
    final currentDate = now ?? DateTime.now();
    final months = List.generate(
      6,
      (index) => DateTime(currentDate.year, currentDate.month - 5 + index),
    );
    final monthlyWeights = List<double>.filled(months.length, 0);
    final weightsByMaterial = <String, double>{};

    for (final offer in deliveredOffers) {
      final date = offer.createdAt ?? offer.fechaOferta;
      final monthIndex = (date.year - months.first.year) * 12 +
          date.month -
          months.first.month;
      if (monthIndex >= 0 && monthIndex < monthlyWeights.length) {
        monthlyWeights[monthIndex] += offer.weightConfirmed ?? offer.peso;
      }
      final material = offer.categoria.trim().isEmpty
          ? 'Sin categoría'
          : offer.categoria.trim();
      weightsByMaterial.update(
        material,
        (weight) => weight + (offer.weightConfirmed ?? offer.peso),
        ifAbsent: () => offer.weightConfirmed ?? offer.peso,
      );
    }

    return DashboardStats(
      totalUsuariosActivos: activeUsers.length,
      materialRecicladoTotal: recycled,
      reputacionPromedio:
          activeUsers.isEmpty ? 0 : totalReputation / activeUsers.length,
      solicitudesPendientes:
          requests.where((request) => request['estado'] == 'SOLICITADA').length,
      publicacionesActivas: publications
          .where((publication) => publication.estadoActivo)
          .length,
      publicacionesVendidas: publications
          .where((publication) => publication.estado == 'ENTREGADO')
          .length,
      kilosComprometidos: centerOffers
          .where((offer) => offer.estado == 'ACEPTADA')
          .fold<double>(
            0,
            (total, offer) => total + (offer.weightConfirmed ?? offer.peso),
          ),
      ofertasPendientes:
          centerOffers.where((offer) => offer.estado == 'OFERTADA').length,
      monthlyRecyclingTotals: [
        for (var index = 0; index < months.length; index++)
          MonthlyRecyclingTotal(
            month: months[index],
            kilograms: monthlyWeights[index],
          ),
      ],
      recyclingByMaterial: weightsByMaterial.entries
          .map(
            (entry) => MaterialRecyclingTotal(
              material: entry.key,
              kilograms: entry.value,
            ),
          )
          .toList()
        ..sort((first, second) => second.kilograms.compareTo(first.kilograms)),
      completedTransactions: deliveredOffers.length,
    );
  }
}

class MonthlyRecyclingTotal {
  const MonthlyRecyclingTotal({required this.month, required this.kilograms});

  final DateTime month;
  final double kilograms;
}

class MaterialRecyclingTotal {
  const MaterialRecyclingTotal({
    required this.material,
    required this.kilograms,
  });

  final String material;
  final double kilograms;
}

final dashboardSolicitudesProvider =
    StreamProvider<List<Map<String, dynamic>>>((ref) {
  return ref
      .watch(firestoreProvider)
      .collection('solicitudes')
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((document) => document.data())
          .toList(growable: false));
});

final dashboardStatsProvider = Provider<AsyncValue<DashboardStats>>((ref) {
  final activeUsersAsync = ref.watch(
    usersProvider((zona: null, estadoActivo: true)),
  );
  final publicationsAsync = ref.watch(publicacionesProvider((
    estado: null,
    categoria: null,
    estadoActivo: null,
  )));
  final centerOffersAsync = ref.watch(ofertasProvider((
    estado: null,
    centroId: null,
    recolectorId: null,
    desde: null,
    hasta: null,
  )));
  final requestsAsync = ref.watch(dashboardSolicitudesProvider);

  if (activeUsersAsync.hasError) {
    return AsyncError(activeUsersAsync.error!, activeUsersAsync.stackTrace!);
  }
  if (publicationsAsync.hasError) {
    return AsyncError(publicationsAsync.error!, publicationsAsync.stackTrace!);
  }
  if (centerOffersAsync.hasError) {
    return AsyncError(centerOffersAsync.error!, centerOffersAsync.stackTrace!);
  }
  if (requestsAsync.hasError) {
    return AsyncError(requestsAsync.error!, requestsAsync.stackTrace!);
  }
  if (!activeUsersAsync.hasValue ||
      !publicationsAsync.hasValue ||
      !centerOffersAsync.hasValue ||
      !requestsAsync.hasValue) {
    return const AsyncLoading();
  }

  return AsyncData(
    DashboardStats.fromData(
      activeUsers: activeUsersAsync.requireValue,
      publications: publicationsAsync.requireValue,
      centerOffers: centerOffersAsync.requireValue,
      requests: requestsAsync.requireValue,
    ),
  );
});
