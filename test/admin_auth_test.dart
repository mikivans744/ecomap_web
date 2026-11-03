import 'package:flutter_test/flutter_test.dart';

import 'package:ecomap_web/core/auth/admin_auth_state.dart';
import 'package:ecomap_web/core/auth/admin_auth_service.dart';
import 'package:ecomap_web/core/routing/auth_guard.dart';

void main() {
  test('auth state exposes loading, authenticated, unauthenticated, and error',
      () {
    const loading = AdminAuthState.loading();
    const authenticated = AdminAuthState.authenticated(
      uid: 'admin-1',
      email: 'admin@example.com',
    );
    const unauthenticated =
        AdminAuthState.unauthenticated(reason: 'No hay sesión');
    const error = AdminAuthState.error(message: 'Firestore no disponible');

    expect(loading.status, AdminAuthStatus.loading);
    expect(loading.canAccessDashboard, isFalse);
    expect(authenticated.status, AdminAuthStatus.authenticated);
    expect(authenticated.canAccessDashboard, isTrue);
    expect(unauthenticated.status, AdminAuthStatus.unauthenticated);
    expect(unauthenticated.message, 'No hay sesión');
    expect(unauthenticated.canAccessDashboard, isFalse);
    expect(error.status, AdminAuthStatus.error);
    expect(error.message, 'Firestore no disponible');
    expect(error.canAccessDashboard, isFalse);
  });

  test('accepts an active admin profile with canonical Firestore fields', () {
    expect(
      AdminAuthServiceImpl.isAdminProfile({
        'role': 'admin',
        'estadoActivo': true,
      }),
      isTrue,
    );
  });

  test('supports the legacy is_active field when estadoActivo is absent', () {
    expect(
      AdminAuthServiceImpl.isAdminProfile({
        'role': ' admin ',
        'is_active': true,
      }),
      isTrue,
    );
  });

  test('does not grant access for inactive or malformed admin profiles', () {
    expect(
      AdminAuthServiceImpl.isAdminProfile({
        'role': 'admin',
        'estadoActivo': false,
        'is_active': true,
      }),
      isFalse,
    );
    expect(
      AdminAuthServiceImpl.isAdminProfile({
        'role': 'user',
        'estadoActivo': true,
      }),
      isFalse,
    );
    expect(
      AdminAuthServiceImpl.isAdminProfile({
        'role': 'admin',
        'estadoActivo': 'true',
      }),
      isFalse,
    );
  });

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

  test('loads and exposes granular admin permissions', () {
    const permissions = AdminPermissions(
      canManageUsers: false,
      canManageRecolectores: false,
      canManageCentros: false,
      canManageOffers: false,
      canModerate: false,
      canViewAudit: false,
      canSync: false,
      canManageRoles: false,
    );
    final restored = AdminPermissions.fromFirestore({
      'permissions': permissions.toFirestoreMap(),
    });

    expect(restored.canManageUsers, isFalse);
    expect(restored.canManageRecolectores, isFalse);
    expect(restored.canManageCentros, isFalse);
    expect(restored.canManageOffers, isFalse);
    expect(restored.canModerate, isFalse);
    expect(restored.canViewAudit, isFalse);
    expect(restored.canSync, isFalse);
    expect(restored.canManageRoles, isFalse);
  });
}
