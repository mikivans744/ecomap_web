import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/admin_auth_provider.dart';
import '../../presentation/pages/auth/login_page.dart';
import '../../presentation/pages/centros/centros_page.dart';
import '../../presentation/pages/dashboard/dashboard_page.dart';
import '../../presentation/pages/ofertas/ofertas_page.dart';
import '../../presentation/pages/publicaciones/publicaciones_page.dart';
import '../../presentation/pages/recolectores/recolectores_page.dart';
import '../../presentation/pages/usuarios/usuarios_page.dart';
import '../auth/admin_auth_state.dart';
import '../constants/route_names.dart';
import 'auth_guard.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final refreshListenable = _RouterRefreshListenable();
  ref.listen<AsyncValue<bool>>(
    isAdminProvider,
    (previous, next) => refreshListenable.refresh(),
  );

  final router = AppRouter.forProvider(
    authStatus: () => ref.read(isAdminProvider),
    refreshListenable: refreshListenable,
    onSignOut: () => ref.read(adminAuthServiceProvider).signOut(),
  ).router;

  ref.onDispose(() {
    router.dispose();
    refreshListenable.dispose();
  });

  return router;
});

AsyncValue<bool> Function() _fixedAdminStatus(bool isAdmin) {
  return () => AsyncData<bool>(isAdmin);
}

final class AppRouter {
  AppRouter({required AdminAuthState authState})
      : _authStatus = _fixedAdminStatus(authState.canAccessDashboard),
        _refreshListenable = null,
        _onSignOut = null;

  AppRouter.forProvider({
    required AsyncValue<bool> Function() authStatus,
    required Listenable refreshListenable,
    required Future<void> Function() onSignOut,
  })  : _authStatus = authStatus,
        _refreshListenable = refreshListenable,
        _onSignOut = onSignOut;

  final AsyncValue<bool> Function() _authStatus;
  final Listenable? _refreshListenable;
  final Future<void> Function()? _onSignOut;

  GoRouter get router => GoRouter(
        initialLocation: '/${RouteNames.login}',
        refreshListenable: _refreshListenable,
        redirect: (context, state) {
          final status = _authStatus();
          return const AuthGuard(
            authState: AdminAuthState.anonymous(),
          ).redirectForStatus(
            location: state.matchedLocation,
            isAdmin: status.valueOrNull ?? false,
            isLoading: status.isLoading,
            hasError: status.hasError,
          );
        },
        routes: <RouteBase>[
          GoRoute(
            path: '/loading',
            builder: (context, state) => const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
          ),
          GoRoute(
            path: '/auth-error',
            builder: (context, state) => const _AuthVerificationErrorPage(),
          ),
          GoRoute(
            name: RouteNames.login,
            path: '/${RouteNames.login}',
            builder: (context, state) => const LoginPage(),
          ),
          GoRoute(
            name: RouteNames.dashboard,
            path: '/${RouteNames.dashboard}',
            builder: (context, state) => DashboardPage(onSignOut: _onSignOut),
          ),
          GoRoute(
            name: RouteNames.users,
            path: '/usuarios',
            builder: (context, state) => const UsuariosPage(),
          ),
          GoRoute(
            name: RouteNames.collectors,
            path: '/recolectores',
            builder: (context, state) => const RecolectoresPage(),
          ),
          GoRoute(
            name: RouteNames.centers,
            path: '/centros',
            builder: (context, state) => const CentrosPage(),
          ),
          GoRoute(
            name: RouteNames.publications,
            path: '/publicaciones',
            builder: (context, state) => const PublicacionesPage(),
          ),
          GoRoute(
            name: RouteNames.offers,
            path: '/ofertas',
            builder: (context, state) => const OfertasPage(),
          ),
        ],
      );
}

class _RouterRefreshListenable extends ChangeNotifier {
  void refresh() => notifyListeners();
}

class _AuthVerificationErrorPage extends ConsumerWidget {
  const _AuthVerificationErrorPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.admin_panel_settings_outlined, size: 48),
              const SizedBox(height: 16),
              const Text('No se pudo verificar el acceso de administrador.'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => ref.invalidate(adminAuthStateProvider),
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
