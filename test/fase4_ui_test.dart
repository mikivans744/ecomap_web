import 'package:flutter_test/flutter_test.dart';
import 'package:ecomap_web/domain/entities/dashboard_stats.dart';

void main() {
  group('UI Tests', () {
    test('DashboardStats should be created correctly', () {
      const stats = DashboardStats(
        totalUsuariosActivos: 100,
        reputacionPromedio: 4.7,
        reportesPendientes: 3,
        publicacionesActivas: 25,
        publicacionesVendidas: 18,
        kilosComprometidos: 750.0,
        ofertasPendientes: 12,
      );

      expect(stats.totalUsuariosActivos, 100);
      expect(stats.reputacionPromedio, 4.7);
      expect(stats.reportesPendientes, 3);
      expect(stats.publicacionesActivas, 25);
      expect(stats.publicacionesVendidas, 18);
      expect(stats.kilosComprometidos, 750.0);
      expect(stats.ofertasPendientes, 12);
    });
  });
}
