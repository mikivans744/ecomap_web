
import 'package:flutter/foundation.dart';

@immutable
class AdminAuthState {
  const AdminAuthState({
    required this.userId,
    required this.email,
    required this.isAdmin,
    this.permissions = const AdminPermissions(),
  });

  final String userId;
  final String email;
  final bool isAdmin;
  final AdminPermissions permissions;

  bool get canAccessDashboard => isAdmin;

  const factory AdminAuthState.anonymous() = AdminAuthState._anonymous;

  const AdminAuthState._anonymous()
      : userId = '',
        email = '',
        isAdmin = false,
        permissions = const AdminPermissions();
}

@immutable
class AdminPermissions {
  const AdminPermissions({
    this.manageUsers = true,
    this.viewTransactions = true,
    this.viewReports = true,
    this.forceSync = true,
    this.moderateComplaints = true,
    this.viewStatistics = true,
    this.manageRoles = true,
  });

  final bool manageUsers;
  final bool viewTransactions;
  final bool viewReports;
  final bool forceSync;
  final bool moderateComplaints;
  final bool viewStatistics;
  final bool manageRoles;

  Map<String, bool> toFirestoreMap() => <String, bool>{
        'manageUsers': manageUsers,
        'viewTransactions': viewTransactions,
        'viewReports': viewReports,
        'forceSync': forceSync,
        'moderateComplaints': moderateComplaints,
        'viewStatistics': viewStatistics,
        'manageRoles': manageRoles,
      };

  factory AdminPermissions.fromFirestore(Map<String, dynamic> data) {
    final permissions =
        data['permissions'] as Map<String, dynamic>? ?? const {};

    return AdminPermissions(
      manageUsers: permissions['manageUsers'] as bool? ?? true,
      viewTransactions: permissions['viewTransactions'] as bool? ?? true,
      viewReports: permissions['viewReports'] as bool? ?? true,
      forceSync: permissions['forceSync'] as bool? ?? true,
      moderateComplaints: permissions['moderateComplaints'] as bool? ?? true,
      viewStatistics: permissions['viewStatistics'] as bool? ?? true,
      manageRoles: permissions['manageRoles'] as bool? ?? true,
    );
  }
}
