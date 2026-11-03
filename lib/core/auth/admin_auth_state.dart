import 'package:flutter/foundation.dart';

enum AdminAuthStatus {
  loading,
  authenticated,
  unauthenticated,
  error,
}

@immutable
class AdminAuthState {
  const AdminAuthState({
    required this.userId,
    required this.email,
    required this.isAdmin,
    this.permissions = const AdminPermissions(),
    AdminAuthStatus? status,
    this.message,
  }) : status = status ??
            (isAdmin
                ? AdminAuthStatus.authenticated
                : AdminAuthStatus.unauthenticated);

  final String userId;
  final String email;
  final bool isAdmin;
  final AdminPermissions permissions;
  final AdminAuthStatus status;
  final String? message;

  bool get canAccessDashboard =>
      status == AdminAuthStatus.authenticated && isAdmin;

  const AdminAuthState.loading()
      : userId = '',
        email = '',
        isAdmin = false,
        permissions = const AdminPermissions.none(),
        status = AdminAuthStatus.loading,
        message = null;

  const AdminAuthState.authenticated({
    required String uid,
    required this.email,
    this.permissions = const AdminPermissions(),
  })  : userId = uid,
        isAdmin = true,
        status = AdminAuthStatus.authenticated,
        message = null;

  const AdminAuthState.unauthenticated({String? reason})
      : userId = '',
        email = '',
        isAdmin = false,
        permissions = const AdminPermissions.none(),
        status = AdminAuthStatus.unauthenticated,
        message = reason;

  const AdminAuthState.error({required this.message})
      : userId = '',
        email = '',
        isAdmin = false,
        permissions = const AdminPermissions.none(),
        status = AdminAuthStatus.error;

  const AdminAuthState.anonymous() : this.unauthenticated();
}

@immutable
class AdminPermissions {
  const AdminPermissions({
    bool? canManageUsers,
    bool? manageUsers,
    bool? canManageRecolectores,
    bool? manageRecolectores,
    bool? canManageCentros,
    bool? manageCentros,
    bool? canManageOffers,
    bool? manageOffers,
    this.viewTransactions = true,
    this.viewReports = true,
    bool? canSync,
    bool? forceSync,
    bool? canModerate,
    bool? moderateComplaints,
    this.viewStatistics = true,
    bool? canManageRoles,
    bool? manageRoles,
    bool? canViewAudit,
    bool? viewAudit,
  })  : manageUsers = canManageUsers ?? manageUsers ?? true,
        manageRecolectores =
            canManageRecolectores ?? manageRecolectores ?? true,
        manageCentros = canManageCentros ?? manageCentros ?? true,
        manageOffers = canManageOffers ?? manageOffers ?? true,
        forceSync = canSync ?? forceSync ?? true,
        moderateComplaints = canModerate ?? moderateComplaints ?? true,
        manageRoles = canManageRoles ?? manageRoles ?? true,
        viewAudit = canViewAudit ?? viewAudit ?? true;

  final bool manageUsers;
  final bool manageRecolectores;
  final bool manageCentros;
  final bool manageOffers;
  final bool viewTransactions;
  final bool viewReports;
  final bool forceSync;
  final bool moderateComplaints;
  final bool viewStatistics;
  final bool manageRoles;
  final bool viewAudit;

  bool get canManageUsers => manageUsers;
  bool get canManageRecolectores => manageRecolectores;
  bool get canManageCentros => manageCentros;
  bool get canManageOffers => manageOffers;
  bool get canModerate => moderateComplaints;
  bool get canViewAudit => viewAudit;
  bool get canSync => forceSync;
  bool get canManageRoles => manageRoles;

  const AdminPermissions.none()
      : manageUsers = false,
        manageRecolectores = false,
        manageCentros = false,
        manageOffers = false,
        viewTransactions = false,
        viewReports = false,
        forceSync = false,
        moderateComplaints = false,
        viewStatistics = false,
        manageRoles = false,
        viewAudit = false;

  Map<String, bool> toFirestoreMap() => <String, bool>{
        'manageUsers': manageUsers,
        'manageRecolectores': manageRecolectores,
        'manageCentros': manageCentros,
        'manageOffers': manageOffers,
        'viewTransactions': viewTransactions,
        'viewReports': viewReports,
        'forceSync': forceSync,
        'moderateComplaints': moderateComplaints,
        'viewStatistics': viewStatistics,
        'manageRoles': manageRoles,
        'viewAudit': viewAudit,
      };

  factory AdminPermissions.fromFirestore(Map<String, dynamic> data) {
    final permissions =
        data['permissions'] as Map<String, dynamic>? ?? const {};

    return AdminPermissions(
      canManageUsers: permissions['canManageUsers'] as bool? ??
          permissions['manageUsers'] as bool? ??
          true,
      canManageRecolectores: permissions['canManageRecolectores'] as bool? ??
          permissions['manageRecolectores'] as bool? ??
          true,
      canManageCentros: permissions['canManageCentros'] as bool? ??
          permissions['manageCentros'] as bool? ??
          true,
      canManageOffers: permissions['canManageOffers'] as bool? ??
          permissions['manageOffers'] as bool? ??
          true,
      viewTransactions: permissions['viewTransactions'] as bool? ?? true,
      viewReports: permissions['viewReports'] as bool? ?? true,
      canSync: permissions['canSync'] as bool? ??
          permissions['forceSync'] as bool? ??
          true,
      canModerate: permissions['canModerate'] as bool? ??
          permissions['moderateComplaints'] as bool? ??
          true,
      viewStatistics: permissions['viewStatistics'] as bool? ?? true,
      canManageRoles: permissions['canManageRoles'] as bool? ??
          permissions['manageRoles'] as bool? ??
          true,
      canViewAudit: permissions['canViewAudit'] as bool? ??
          permissions['viewAudit'] as bool? ??
          true,
    );
  }
}
