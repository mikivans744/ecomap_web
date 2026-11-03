import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'admin_auth_service.dart';
import 'admin_auth_state.dart';

final adminAuthServiceProvider = Provider<AdminAuthService>((ref) {
  return AdminAuthServiceImpl();
});

typedef AdminSignIn = Future<void> Function({
  required String email,
  required String password,
});

final adminSignInProvider = Provider<AdminSignIn>((ref) {
  return ({required email, required password}) async {
    await ref.read(adminAuthServiceProvider).signInWithEmailAndPassword(
          email: email,
          password: password,
        );
  };
});

final isAdminProvider = StreamProvider<AdminAuthState>((ref) {
  final service = ref.watch(adminAuthServiceProvider);
  return _authStateWithInitialTimeout(service.authStateChanges);
});

final adminAuthStateProvider = isAdminProvider;

Stream<AdminAuthState> _authStateWithInitialTimeout(
  Stream<AdminAuthState> states,
) {
  const timeoutMessage = 'No se pudo verificar la sesión, intenta de nuevo';

  return Stream<AdminAuthState>.multi((controller) {
    var hasResolved = false;
    var isClosed = false;
    late final Timer timer;
    StreamSubscription<AdminAuthState>? subscription;

    void closeWithError(String message) {
      if (isClosed) return;
      isClosed = true;
      controller.add(AdminAuthState.error(message: message));
      controller.close();
      subscription?.cancel();
    }

    timer = Timer(const Duration(seconds: 8), () {
      if (hasResolved) return;
      closeWithError(timeoutMessage);
    });

    subscription = states.listen(
      (state) {
        if (isClosed) return;
        controller.add(state);
        if (state.status != AdminAuthStatus.loading && !hasResolved) {
          hasResolved = true;
          timer.cancel();
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        timer.cancel();
        closeWithError(error.toString());
      },
      onDone: () {
        timer.cancel();
        if (!hasResolved) {
          closeWithError(timeoutMessage);
        } else if (!isClosed) {
          isClosed = true;
          controller.close();
        }
      },
    );

    controller.onCancel = () {
      timer.cancel();
      subscription?.cancel();
    };
  });
}

final adminPermissionsProvider = Provider<AdminPermissions>((ref) {
  final authAsync = ref.watch(isAdminProvider);
  return authAsync.when(
    data: (authState) => authState.canAccessDashboard
        ? authState.permissions
        : const AdminPermissions.none(),
    loading: () => const AdminPermissions.none(),
    error: (_, __) => const AdminPermissions.none(),
  );
});
