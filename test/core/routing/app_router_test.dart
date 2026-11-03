import 'dart:async';

import 'package:ecomap_web/core/auth/admin_auth_provider.dart';
import 'package:ecomap_web/core/auth/admin_auth_state.dart';
import 'package:ecomap_web/core/constants/route_names.dart';
import 'package:ecomap_web/core/routing/app_router.dart';
import 'package:ecomap_web/presentation/providers/centro_acopio_providers.dart';
import 'package:ecomap_web/presentation/providers/dashboard_stats_provider.dart';
import 'package:ecomap_web/presentation/providers/user_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

import 'package:ecomap_web/core/auth/admin_auth_service.dart';

void main() {
  testWidgets('successful login redirects to the dashboard', (tester) async {
    final signedIn = StateProvider<bool>((ref) => false);
    String? submittedEmail;
    late GoRouter router;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          signedIn.overrideWith((ref) => false),
          isAdminProvider.overrideWith(
            (ref) => Stream.value(
              ref.watch(signedIn)
                  ? const AdminAuthState.authenticated(
                      uid: 'admin-1',
                      email: 'admin@example.com',
                    )
                  : const AdminAuthState.unauthenticated(),
            ),
          ),
          adminSignInProvider.overrideWith(
            (ref) => ({required email, required password}) async {
              submittedEmail = email;
              ref.read(signedIn.notifier).state = true;
            },
          ),
          dashboardStatsProvider.overrideWithValue(const AsyncLoading()),
        ],
        child: Consumer(
          builder: (context, ref, _) {
            router = ref.watch(appRouterProvider);
            return MaterialApp.router(routerConfig: router);
          },
        ),
      ),
    );
    router.go(RouteNames.login);
    await tester.pumpAndSettle();
    expect(find.text('Acceso administrador'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('login_email_field')),
      '  Admin@Example.com ',
    );
    await tester.enterText(
      find.byKey(const Key('login_password_field')),
      'valid-password',
    );
    await tester.tap(find.byKey(const Key('login_submit_button')));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();
    await tester.pump();

    expect(router.routeInformationProvider.value.uri.path, RouteNames.home);
    expect(find.text('Panel administrativo'), findsOneWidget);
    expect(submittedEmail, 'admin@example.com');
  });

  testWidgets('resolved unauthenticated state leaves splash for login',
      (tester) async {
    late GoRouter router;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isAdminProvider.overrideWith(
            (ref) => Stream.value(
              const AdminAuthState.unauthenticated(
                reason: 'No hay sesión',
              ),
            ),
          ),
        ],
        child: Consumer(
          builder: (context, ref, _) {
            router = ref.watch(appRouterProvider);
            return MaterialApp.router(routerConfig: router);
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, RouteNames.login);
    expect(find.text('Acceso administrador'), findsOneWidget);
  });

  testWidgets('bare root redirects an unauthenticated session to login',
      (tester) async {
    late GoRouter router;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isAdminProvider.overrideWith(
            (ref) => Stream.value(const AdminAuthState.unauthenticated()),
          ),
        ],
        child: Consumer(
          builder: (context, ref, _) {
            router = ref.watch(appRouterProvider);
            return MaterialApp.router(routerConfig: router);
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    router.go('/');
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, RouteNames.login);
  });

  testWidgets('dashboard logout redirects to login', (tester) async {
    tester.view.physicalSize = const Size(1440, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final signedIn = StateProvider<bool>((ref) => true);
    final authService = _FakeAdminAuthService();
    late GoRouter router;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isAdminProvider.overrideWith(
            (ref) => Stream.value(
              ref.watch(signedIn)
                  ? const AdminAuthState.authenticated(
                      uid: 'admin-1',
                      email: 'admin@example.com',
                    )
                  : const AdminAuthState.unauthenticated(),
            ),
          ),
          adminAuthServiceProvider.overrideWithValue(authService),
          dashboardStatsProvider.overrideWithValue(const AsyncLoading()),
        ],
        child: Consumer(
          builder: (context, ref, _) {
            authService.onSignOut = () {
              ref.read(signedIn.notifier).state = false;
            };
            router = ref.watch(appRouterProvider);
            return MaterialApp.router(routerConfig: router);
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();

    await tester.ensureVisible(find.byKey(const Key('logout_button')));
    await tester.tap(find.byKey(const Key('logout_button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();

    expect(authService.wasSignedOut, isTrue);
    expect(router.routeInformationProvider.value.uri.path, RouteNames.login);
    expect(find.text('Acceso administrador'), findsOneWidget);
  });

  testWidgets('auth verification timeout redirects and shows a SnackBar',
      (tester) async {
    final pendingStates = StreamController<AdminAuthState>();
    final authService = _FakeAdminAuthService()
      ..authStates = pendingStates.stream;
    late GoRouter router;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          adminAuthServiceProvider.overrideWithValue(authService),
        ],
        child: Consumer(
          builder: (context, ref, _) {
            router = ref.watch(appRouterProvider);
            return MaterialApp.router(routerConfig: router);
          },
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(router.routeInformationProvider.value.uri.path, RouteNames.splash);

    await tester.pump(const Duration(seconds: 7));
    expect(router.routeInformationProvider.value.uri.path, RouteNames.splash);

    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

    expect(router.routeInformationProvider.value.uri.path, RouteNames.login);
    expect(
      find.text('No se pudo verificar la sesión, intenta de nuevo'),
      findsWidgets,
    );
  });

  testWidgets('authentication validation errors redirect to login',
      (tester) async {
    late GoRouter router;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isAdminProvider.overrideWith(
            (ref) => Stream.error(
              FirebaseException(
                plugin: 'cloud_firestore',
                code: 'permission-denied',
              ),
              StackTrace.current,
            ),
          ),
        ],
        child: Consumer(
          builder: (context, ref, _) {
            router = ref.watch(appRouterProvider);
            return MaterialApp.router(routerConfig: router);
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, RouteNames.login);
    expect(find.text('Acceso administrador'), findsOneWidget);
  });

  testWidgets('router navigates between protected modules', (tester) async {
    tester.view.physicalSize = const Size(1440, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    late GoRouter router;
    await tester.pumpWidget(_adminApp(
      (value) => router = value,
      extraOverrides: [
        for (final active in <bool?>[null, true, false])
          usersProvider((zona: null, estadoActivo: active))
              .overrideWith((ref) => Stream.value(const [])),
        centrosAcopioProvider((zona: null, estadoActivo: null))
            .overrideWith((ref) => Stream.value(const [])),
      ],
    ));
    await tester.pumpAndSettle();

    router.go(RouteNames.usuarios);
    expect(router.routeInformationProvider.value.uri.path, RouteNames.usuarios);

    router.go(RouteNames.centros);
    expect(router.routeInformationProvider.value.uri.path, RouteNames.centros);
  });

  testWidgets('registers and displays the recycling route', (tester) async {
    tester.view.physicalSize = const Size(1280, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    late GoRouter router;
    await tester.pumpWidget(_adminApp((value) => router = value));
    await tester.pumpAndSettle();

    expect(router.namedLocation('reciclaje'), RouteNames.reciclaje);

    router.go(RouteNames.reciclaje);
    await tester.pumpAndSettle();

    expect(find.text('Transacciones de reciclaje'), findsOneWidget);
  });

  testWidgets('the navigation menu opens recycling', (tester) async {
    tester.view.physicalSize = const Size(1280, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_adminApp((_) {}));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Reciclaje'));
    await tester.pumpAndSettle();

    expect(find.text('Transacciones de reciclaje'), findsOneWidget);
  });
}

class _FakeAdminAuthService implements AdminAuthService {
  void Function()? onSignOut;
  bool wasSignedOut = false;
  Stream<AdminAuthState> authStates = const Stream.empty();

  @override
  User? get currentUser => null;

  @override
  Stream<AdminAuthState> get authStateChanges => authStates;

  @override
  Future<bool> isAdminUser(User user) async => false;

  @override
  Future<void> signOut() async {
    wasSignedOut = true;
    onSignOut?.call();
  }

  @override
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) =>
      throw UnimplementedError();
}

Widget _adminApp(
  void Function(GoRouter) onRouterCreated, {
  List<Override> extraOverrides = const [],
}) =>
    ProviderScope(
      overrides: [
        isAdminProvider.overrideWith(
          (ref) => Stream.value(
            const AdminAuthState.authenticated(
              uid: 'admin-1',
              email: 'admin@example.com',
            ),
          ),
        ),
        ...extraOverrides,
      ],
      child: Consumer(
        builder: (context, ref, _) {
          final router = ref.watch(appRouterProvider);
          onRouterCreated(router);
          return MaterialApp.router(routerConfig: router);
        },
      ),
    );
