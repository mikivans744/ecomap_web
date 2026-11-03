import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../auth/admin_auth_state.dart';
import '../constants/route_names.dart';

@immutable
class AuthGuard {
  const AuthGuard({required AdminAuthState authState}) : _authState = authState;

  final AdminAuthState _authState;

  String? redirectForLocation(String location) {
    return redirectForStatus(
      location: location,
      isAdmin: _authState.canAccessDashboard,
      isLoading: false,
      hasError: false,
    );
  }

  String? redirectForStatus({
    required String location,
    required bool isAdmin,
    required bool isLoading,
    required bool hasError,
  }) {
    const loginPath = '/${RouteNames.login}';

    if (isLoading) {
      return location == '/loading' ? null : '/loading';
    }

    if (hasError) {
      return location == '/auth-error' ? null : '/auth-error';
    }

    if (isAdmin) {
      return location == loginPath ||
              location == '/loading' ||
              location == '/auth-error'
          ? '/${RouteNames.dashboard}'
          : null;
    }

    return location == loginPath ? null : loginPath;
  }

  String? call(BuildContext context, GoRouterState state) =>
      redirectForLocation(state.matchedLocation);
}
