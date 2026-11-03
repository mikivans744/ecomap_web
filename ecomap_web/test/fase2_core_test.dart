import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ecomap_web/core/auth/admin_auth_state.dart';
import 'package:ecomap_web/core/routing/app_router.dart';
import 'package:ecomap_web/core/routing/auth_guard.dart';
import 'package:ecomap_web/core/theme/app_colors.dart';
import 'package:ecomap_web/core/theme/app_theme.dart';
import 'package:ecomap_web/domain/entities/admin_user.dart';
import 'package:ecomap_web/domain/entities/recycling_transaction.dart';
import 'package:ecomap_web/domain/entities/report_complaint.dart';
import 'package:ecomap_web/domain/entities/sync_status.dart';
import 'package:ecomap_web/domain/entities/user_rating.dart';

void main() {
  group('domain entities', () {
    test('admin user preserves its identity and role', () {
      final user = AdminUser(
        id: 'admin-1',
        email: 'admin@ecomap.com',
        displayName: 'Administrador',
        role: AdminUserRole.admin,
        isActive: true,
        createdAt: DateTime.utc(2026, 1, 2),
      );

      expect(user.id, 'admin-1');
      expect(user.role, AdminUserRole.admin);
      expect(user.isActive, isTrue);
    });

    test('recycling transaction exposes normalized monetary values', () {
      final transaction = RecyclingTransaction(
        id: 'transaction-1',
        userId: 'user-1',
        collectorId: 'collector-1',
        materialCategory: 'Plástico',
        weightKg: 12.5,
        pointsAwarded: 35,
        status: RecyclingTransactionStatus.completed,
        createdAt: DateTime.utc(2026, 3, 15),
      );

      expect(transaction.weightKg, 12.5);
      expect(transaction.pointsAwarded, 35);
      expect(transaction.status, RecyclingTransactionStatus.completed);
    });

    test('report complaint keeps its moderation state', () {
      final report = ReportComplaint(
        id: 'report-1',
        reporterId: 'user-1',
        reportedUserId: 'user-2',
        category: 'Contenido inapropiado',
        description: 'Reporte de prueba',
        status: ReportComplaintStatus.pending,
        createdAt: DateTime.utc(2026, 4, 1),
      );

      expect(report.status, ReportComplaintStatus.pending);
      expect(report.isBlocked, isFalse);
    });

    test('sync status reports the latest synchronization result', () {
      final syncStatus = SyncStatus(
        deviceId: 'device-1',
        status: SyncStatusValue.synced,
        pendingCount: 0,
        lastSyncAt: DateTime.utc(2026, 5, 10, 20),
      );

      expect(syncStatus.pendingCount, 0);
      expect(syncStatus.status, SyncStatusValue.synced);
      expect(syncStatus.requiresSync, isFalse);
    });

    test('user rating can represent a disputed review', () {
      final rating = UserRating(
        id: 'rating-1',
        ratedUserId: 'user-2',
        fromUserId: 'user-1',
        score: 4,
        review: 'Muy buen trabajo',
        status: UserRatingStatus.disputed,
        createdAt: DateTime.utc(2026, 6, 9),
      );

      expect(rating.score, 4);
      expect(rating.status, UserRatingStatus.disputed);
      expect(rating.isDisputed, isTrue);
    });
  });

  group('theme', () {
    test('light theme uses the ECOMAP ecological palette', () {
      final theme = AppTheme.offlineTheme;

      expect(theme.colorScheme.primary, AppColors.primary);
      expect(theme.colorScheme.secondary, AppColors.secondary);
      expect(theme.useMaterial3, isTrue);
      expect(theme.scaffoldBackgroundColor, AppColors.background);
    });
  });

  group('routing', () {
    test('authenticated admin can access protected routes', () {
      const guard = AuthGuard(
        authState: AdminAuthState(
          userId: 'admin-1',
          email: 'admin@example.com',
          isAdmin: true,
        ),
      );

      expect(guard.redirectForLocation('/dashboard'), isNull);
    });

    test('unauthenticated user is redirected to login', () {
      const guard = AuthGuard(
        authState: AdminAuthState.anonymous(),
      );

      expect(guard.redirectForLocation('/dashboard'), '/login');
    });
  });

  testWidgets('login page resolves the admin authentication screen',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          routerConfig: AppRouter(
            authState: const AdminAuthState.anonymous(),
          ).router,
        ),
      ),
    );

    expect(find.text('Acceso administrador'), findsOneWidget);
  });
}
