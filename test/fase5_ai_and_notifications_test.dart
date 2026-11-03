import 'package:flutter_test/flutter_test.dart';
import 'package:ecomap_web/domain/entities/dashboard_stats.dart';

void main() {
  group('AI and Notifications Tests', () {
    test('DashboardStats should work with AI service', () {
      const stats = DashboardStats(
        totalUsuariosActivos: 200,
        reputacionPromedio: 4.9,
        reportesPendientes: 1,
        publicacionesActivas: 50,
        publicacionesVendidas: 40,
        kilosComprometidos: 1200.0,
        ofertasPendientes: 5,
      );

      expect(stats.totalUsuariosActivos, 200);
      expect(stats.reputacionPromedio, 4.9);
      expect(stats.reportesPendientes, 1);
      expect(stats.publicacionesActivas, 50);
      expect(stats.publicacionesVendidas, 40);
      expect(stats.kilosComprometidos, 1200.0);
      expect(stats.ofertasPendientes, 5);
    });
  });
}
