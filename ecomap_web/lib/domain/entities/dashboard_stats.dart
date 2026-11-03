class DashboardStats {
  const DashboardStats({
    required this.totalUsuariosActivos,
    this.materialRecicladoTotal = 0,
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
  final int publicacionesActivas;
  final int publicacionesVendidas;
  final double kilosComprometidos;
  final int ofertasPendientes;

  factory DashboardStats.fromData({
    required List<dynamic> activeUsers,
    required int pendingReports,
    required int activePubs,
    required int soldPubs,
    required double committedKilos,
    required int pendingOffers,
  }) {
    double totalReputation = 0;
    double totalRecycled = 0;

    for (final user in activeUsers) {
      final userData = user as dynamic;
      totalReputation += (userData.reputacion as num).toDouble();
      totalRecycled += (userData.totalReciclado as num).toDouble();
    }

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
