import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'admin_auth_service.dart';
import 'admin_auth_state.dart';

final adminAuthServiceProvider = Provider<AdminAuthService>(
  (ref) => AdminAuthServiceImpl(),
);

final adminAuthStateProvider = StreamProvider<AdminAuthState>((ref) {
  final service = ref.watch(adminAuthServiceProvider);
  return service.authStateChanges;
});

final isAdminProvider = Provider<AsyncValue<bool>>((ref) {
  return ref
      .watch(adminAuthStateProvider)
      .whenData((authState) => authState.canAccessDashboard);
});
