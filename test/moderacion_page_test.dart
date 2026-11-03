import 'package:ecomap_web/core/auth/admin_auth_provider.dart';
import 'package:ecomap_web/core/auth/admin_auth_state.dart';
import 'package:ecomap_web/presentation/pages/moderacion/moderacion_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('resolves a pending report and records the admin note',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final report = ModerationReport(
      id: 'report-1',
      data: {
        'tipo': 'contenido',
        'estado': 'pendiente',
        'descripcion': 'Publicación sospechosa',
        'reportadoPor': 'user-1',
        'reportadoId': 'user-2',
        'createdAt': DateTime(2026, 8, 3),
      },
    );
    ModerationReport? updatedReport;
    String? updatedStatus;
    String? updatedNote;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          adminPermissionsProvider.overrideWithValue(
            const AdminPermissions(canModerate: true),
          ),
          moderationReportsProvider('pendiente')
              .overrideWith((ref) => Stream.value([report])),
          allModerationReportsProvider
              .overrideWith((ref) => Stream.value([report])),
          moderationReportUpdaterProvider.overrideWithValue(
            ({required report, required status, required note}) async {
              updatedReport = report;
              updatedStatus = status;
              updatedNote = note;
            },
          ),
        ],
        child: const MaterialApp(home: ModeracionPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Publicación sospechosa'), findsOneWidget);
    await tester.tap(find.text('Ver detalle'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Reportado por: user-1'), findsWidgets);
    await tester.tap(find.text('Cerrar'));
    await tester.pumpAndSettle();

    expect(find.text('Resolver'), findsOneWidget);
    await tester.ensureVisible(find.text('Resolver'));
    await tester.tap(find.text('Resolver'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('moderation_note_field')),
      'Revisado por el equipo',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.pumpAndSettle();

    expect(updatedReport?.id, 'report-1');
    expect(updatedStatus, 'resuelto');
    expect(updatedNote, 'Revisado por el equipo');
    expect(find.text('Reporte actualizado.'), findsOneWidget);

    await tester.pumpAndSettle();
    await tester.tap(find.text('Descartar'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('moderation_note_field')),
      'No incumple las normas',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.pumpAndSettle();
    expect(updatedStatus, 'descartado');
    expect(updatedNote, 'No incumple las normas');
  });
}
