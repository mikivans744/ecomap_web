import 'package:ecomap_web/domain/services/gemini_assistant_service.dart';
import 'package:ecomap_web/presentation/pages/dashboard/dashboard_page.dart';
import 'package:ecomap_web/presentation/providers/dashboard_stats_provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders Firestore-backed metrics and charts without demo AI',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final stats = DashboardStats(
      totalUsuariosActivos: 18,
      materialRecicladoTotal: 8,
      reputacionPromedio: 4.2,
      solicitudesPendientes: 2,
      publicacionesActivas: 6,
      publicacionesVendidas: 3,
      kilosComprometidos: 12,
      ofertasPendientes: 1,
      monthlyRecyclingTotals: [
        for (var month = 1; month <= 6; month++)
          MonthlyRecyclingTotal(
            month: DateTime(2025, month),
            kilograms: month.toDouble(),
          ),
      ],
      recyclingByMaterial: const [
        MaterialRecyclingTotal(material: 'Papel', kilograms: 5),
        MaterialRecyclingTotal(material: 'Plástico', kilograms: 3),
      ],
      completedTransactions: 2,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dashboardStatsProvider.overrideWithValue(AsyncData(stats)),
        ],
        child: const MaterialApp(home: DashboardPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('18'), findsOneWidget);
    expect(find.text('6'), findsOneWidget);
    expect(find.text('4.2 ★'), findsOneWidget);
    expect(find.byType(BarChart), findsOneWidget);
    expect(find.byType(PieChart), findsOneWidget);
    expect(find.byKey(const Key('ai_assistant_toggle')), findsNothing);
    expect(const NoopGeminiAssistantService().isConfigured, isFalse);
  });
}
