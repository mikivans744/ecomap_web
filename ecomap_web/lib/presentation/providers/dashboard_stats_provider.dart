import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    required this.reportesPendientes,
    required this.publicacionesActivas,
    required this.publicacionesVendidas,
    required this.kilosComprometidos,
    required this.ofertasPendientes,
  });

  final int totalUsuariosActivos;
  final double materialRecicladoTotal;
  final double reputacionPromedio;
  final int reportesPendientes;

  // Fase 7 métricas
  final int publicacionesActivas;
  final int publicacionesVendidas;
  final double kilosComprometidos;
  final int ofertasPendientes;

  factory DashboardStats.fromData({
    required List<UserEntity> activeUsers,
    required int pendingReports,
    required int activePubs,
    required int soldPubs,
    required double committedKilos,
    required int pendingOffers,
  }) {
    final totalReputation = activeUsers.fold<double>(
      0,
      (total, user) => total + user.reputacion,
    );
    final totalRecycled = activeUsers.fold<double>(
      0,
      (total, user) => total + user.totalReciclado,
    );

    return DashboardStats(
      totalUsuariosActivos: activeUsers.length,
      materialRecicladoTotal: totalRecycled,
      reputacionPromedio:
          activeUsers.isEmpty ? 0 : totalReputation / activeUsers.length,
      reportesPendientes: pendingReports,
      publicacionesActivas: activePubs,
      publicacionesVendidas: soldPubs,
      kilosComprometidos: committedKilos,
      ofertasPendientes: pendingOffers,
    );
  }
}

final pendingReportsCountProvider = StreamProvider<int>((ref) {
  return ref
      .watch(firestoreProvider)
      .collection('reports')
      .where('estado', isEqualTo: 'pendiente')
      .snapshots()
      .map((snapshot) => snapshot.size);
});

final dashboardStatsProvider = Provider<AsyncValue<DashboardStats>>((ref) {
  final activeUsersAsync = ref.watch(
    usersProvider((zona: null, estadoActivo: true)),
  );
  final pendingReportsAsync = ref.watch(pendingReportsCountProvider);

  // Fase 7 providers
  final publicationsAsync = ref.watch(publicacionesProvider((
    estado: null,
    categoria: null,
    estadoActivo: null,
  )));

  final offersAsync = ref.watch(ofertasProvider((
    estado: null,
    centroId: null,
    recolectorId: null,
    desde: null,
    hasta: null,
  )));

  return activeUsersAsync.when(
    data: (users) => pendingReportsAsync.when(
      data: (reportsCount) => publicationsAsync.when(
        data: (pubs) => offersAsync.when(
          data: (offers) {
            final activePubs = pubs
                .where((p) => p.estadoActivo && p.estado != 'vendido')
                .length;
            final soldPubs = pubs.where((p) => p.estado == 'vendido').length;
            final pendingOffers =
                offers.where((o) => o.estado == 'pendiente').length;

            final committedStatuses = {'pendiente', 'aceptada', 'en_camino'};
            final committedKilos = offers
                .where((o) => committedStatuses.contains(o.estado))
                .fold<double>(0, (sum, o) => sum + o.peso);

            return AsyncData(
              DashboardStats.fromData(
                activeUsers: users,
                pendingReports: reportsCount,
                activePubs: activePubs,
                soldPubs: soldPubs,
                committedKilos: committedKilos,
                pendingOffers: pendingOffers,
              ),
            );
          },
          error: (e, s) => AsyncError(e, s),
          loading: () => const AsyncLoading(),
        ),
        error: (e, s) => AsyncError(e, s),
        loading: () => const AsyncLoading(),
      ),
      error: (e, s) => AsyncError(e, s),
      loading: () => const AsyncLoading(),
    ),
    error: (e, s) => AsyncError(e, s),
    loading: () => const AsyncLoading(),
  );
});
