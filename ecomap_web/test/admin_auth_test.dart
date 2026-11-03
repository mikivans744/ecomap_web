import 'package:flutter_test/flutter_test.dart';

import 'package:ecomap_web/core/auth/admin_auth_state.dart';
import 'package:ecomap_web/core/routing/auth_guard.dart';

void main() {
  test('an unauthenticated user is redirected to login', () {
    const guard = AuthGuard(
      authState: AdminAuthState.anonymous(),
    );

    expect(guard.redirectForLocation('/dashboard'), '/login');
  });

  test('an authenticated admin can access the dashboard', () {
    const state = AdminAuthState(
      userId: 'admin-1',
      email: 'admin@example.com',
      isAdmin: true,
    );

    expect(state.canAccessDashboard, isTrue);
  });

  test('a signed-in non-admin cannot access the dashboard', () {
    const state = AdminAuthState(
      userId: 'user-1',
      email: 'user@example.com',
      isAdmin: false,
    );

    expect(state.canAccessDashboard, isFalse);
  });
}
