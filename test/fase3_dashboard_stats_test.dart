import 'package:flutter_test/flutter_test.dart';
import 'package:ecomap_web/domain/entities/dashboard_stats.dart';

void main() {
  group('DashboardStats', () {
    test('should create instance with all fields', () {
      const stats = DashboardStats(
        totalUsuariosActivos: 10,
        reputacionPromedio: 4.5,
        reportesPendientes: 2,
        publicacionesActivas: 0,
        publicacionesVendidas: 0,
        kilosComprometidos: 0.0,
        ofertasPendientes: 0,
      );

      expect(stats.totalUsuariosActivos, 10);
      expect(stats.reputacionPromedio, 4.5);
      expect(stats.reportesPendientes, 2);
      expect(stats.publicacionesActivas, 0);
      expect(stats.publicacionesVendidas, 0);
      expect(stats.kilosComprometidos, 0.0);
      expect(stats.ofertasPendientes, 0);
    });

    test('should create instance with custom values', () {
      const stats = DashboardStats(
        totalUsuariosActivos: 50,
        reputacionPromedio: 4.8,
        reportesPendientes: 5,
        publicacionesActivas: 20,
        publicacionesVendidas: 15,
        kilosComprometidos: 500.0,
        ofertasPendientes: 10,
      );

      expect(stats.totalUsuariosActivos, 50);
      expect(stats.reputacionPromedio, 4.8);
      expect(stats.reportesPendientes, 5);
      expect(stats.publicacionesActivas, 20);
      expect(stats.publicacionesVendidas, 15);
      expect(stats.kilosComprometidos, 500.0);
      expect(stats.ofertasPendientes, 10);
    });
  });
}
