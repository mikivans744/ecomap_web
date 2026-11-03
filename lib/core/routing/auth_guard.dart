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
    if (isLoading) {
      return location == RouteNames.splash ? null : RouteNames.splash;
    }

    if (hasError) {
      return location == RouteNames.login ? null : RouteNames.login;
    }

    if (isAdmin) {
      return location == RouteNames.login || location == RouteNames.splash
          ? RouteNames.home
          : null;
    }

    return location == RouteNames.login ? null : RouteNames.login;
  }

  String? call(BuildContext context, GoRouterState state) =>
      redirectForLocation(state.matchedLocation);
}
