import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/admin_auth_provider.dart';
import '../../../core/auth/admin_auth_state.dart';

class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(isAdminProvider);
    final state = authState.valueOrNull;
    if (!authState.isLoading && state?.status != AdminAuthStatus.loading) {
      final destination = state?.canAccessDashboard == true ? '/' : '/login';
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        final router = GoRouter.maybeOf(context);
        if (router != null &&
            router.routeInformationProvider.value.uri.path != destination) {
          context.go(destination);
        }
      });
    }

    return Scaffold(
      backgroundColor: const Color(0xFFE8F5E9),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.eco, size: 80, color: Color(0xFF2E7D32)),
            const SizedBox(height: 24),
            const Text(
              'ECOMAP Web',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2E7D32),
              ),
            ),
            const SizedBox(height: 32),
            const CircularProgressIndicator(
              color: Color(0xFF2E7D32),
            ),
            const SizedBox(height: 16),
            Text(
              'Cargando panel administrativo...',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
