import '../entities/admin_user.dart';

abstract interface class AdminRepository {
  Stream<AdminUser?> watchCurrentAdmin();

  Future<AdminUser?> getAdmin(String id);

  Future<void> updateAdmin(
    String id, {
    bool? estadoActivo,
    AdminUserRole? role,
  });
}
