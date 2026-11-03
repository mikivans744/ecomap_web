import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../presentation/pages/auth/splash_screen.dart';
import '../../presentation/pages/auth/login_page.dart';
import '../../presentation/pages/dashboard/dashboard_page.dart';
import '../../presentation/pages/usuarios/usuarios_page.dart';
import '../../presentation/pages/recolectores/recolectores_page.dart';
import '../../presentation/pages/centros/centros_page.dart';
import '../../presentation/pages/publicaciones/publicaciones_page.dart';
import '../../presentation/pages/ofertas/ofertas_page.dart';
import '../../presentation/pages/moderacion/moderacion_page.dart';
import '../../presentation/pages/soporte/soporte_page.dart';
import '../../presentation/pages/mapa/mapa_page.dart';
import '../../presentation/pages/estadisticas/estadisticas_page.dart';
import '../../presentation/pages/sync/sync_page.dart';
import '../../presentation/pages/auditoria/auditoria_page.dart';
import '../../presentation/pages/reciclaje/reciclaje_page.dart';
import '../auth/admin_auth_provider.dart';
import '../auth/admin_auth_state.dart';
import '../constants/route_names.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: RouteNames.splash,
    debugLogDiagnostics: true,
    redirect: (context, state) {
      final authAsync = ref.read(isAdminProvider);
      final location = state.uri.path;

      return authAsync.when(
        loading: () {
          debugPrint(
            '[Router] Auth cargando; '
            '${location == RouteNames.splash ? 'mantener splash' : 'ir a splash'}',
          );
          return location == RouteNames.splash ? null : RouteNames.splash;
        },
        data: (authState) {
          debugPrint(
            '[Router] Auth resuelto: '
            'status=${authState.status}, '
            'canAccessDashboard=${authState.canAccessDashboard}, path=$location',
          );

          if (authState.status == AdminAuthStatus.loading) {
            return location == RouteNames.splash ? null : RouteNames.splash;
          }

          if (authState.canAccessDashboard) {
            if (location == RouteNames.splash || location == RouteNames.login) {
              return RouteNames.home;
            }
            return null;
          }

          debugPrint('[Router] Auth resuelto sin acceso → /login');
          return location == RouteNames.login ? null : RouteNames.login;
        },
        error: (error, stackTrace) {
          debugPrint('[Router] Error de autenticación: $error → /login');
          return location == RouteNames.login ? null : RouteNames.login;
        },
      );
    },
    routes: [
      GoRoute(
        path: RouteNames.splash,
        builder: (_, __) => const SplashScreen(),
      ),
      GoRoute(path: RouteNames.login, builder: (_, __) => const LoginPage()),
      GoRoute(
        path: RouteNames.home,
        builder: (_, __) => DashboardPage(
          onSignOut: () => ref.read(adminAuthServiceProvider).signOut(),
        ),
      ),
      GoRoute(
          path: RouteNames.usuarios, builder: (_, __) => const UsuariosPage()),
      GoRoute(
        path: RouteNames.recolectores,
        builder: (_, __) => const RecolectoresPage(),
      ),
      GoRoute(
          path: RouteNames.centros, builder: (_, __) => const CentrosPage()),
      GoRoute(
        path: RouteNames.publicaciones,
        builder: (_, __) => const PublicacionesPage(),
      ),
      GoRoute(
          path: RouteNames.ofertas, builder: (_, __) => const OfertasPage()),
      GoRoute(
        path: RouteNames.moderacion,
        builder: (_, __) => const ModeracionPage(),
      ),
      GoRoute(
          path: RouteNames.soporte, builder: (_, __) => const SoportePage()),
      GoRoute(path: RouteNames.mapa, builder: (_, __) => const MapaPage()),
      GoRoute(
        path: RouteNames.estadisticas,
        builder: (_, __) => const EstadisticasPage(),
      ),
      GoRoute(path: RouteNames.sync, builder: (_, __) => const SyncPage()),
      GoRoute(
        path: RouteNames.auditoria,
        builder: (_, __) => const AuditoriaPage(),
      ),
      GoRoute(
        name: 'reciclaje',
        path: RouteNames.reciclaje,
        builder: (_, __) => const ReciclajePage(),
      ),
    ],
    errorPageBuilder: (context, state) => const MaterialPage(
      child: Scaffold(
        body: Center(child: Text('404 - Página no encontrada')),
      ),
    ),
  );

  ref.listen(isAdminProvider, (_, __) {
    debugPrint(
        '[Router] El estado de autenticación cambió; refrescando rutas.');
    router.refresh();
  });
  ref.onDispose(router.dispose);

  return router;
});
