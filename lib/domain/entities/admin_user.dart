import 'package:flutter/foundation.dart';

@immutable
class AdminUser {
  const AdminUser({
    required this.id,
    required this.email,
    required this.displayName,
    required this.role,
    required this.estadoActivo,
    required this.createdAt,
    this.lastLoginAt,
  });

  final String id;
  final String email;
  final String displayName;
  final AdminUserRole role;
  final bool estadoActivo;
  final DateTime createdAt;
  final DateTime? lastLoginAt;
}

enum AdminUserRole {
  admin,
  moderator,
  auditor,
}
