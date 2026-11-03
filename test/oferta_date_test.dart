import 'package:ecomap_web/domain/entities/oferta_entity.dart';
import 'package:ecomap_web/presentation/pages/ofertas/widgets/oferta_card.dart';
import 'package:ecomap_web/presentation/pages/ofertas/widgets/oferta_detail_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('missing and epoch offer dates display Sin fecha',
      (tester) async {
    final missingDate = _offer(createdAt: null);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OfertaCard(
            oferta: missingDate,
            recolectorNombre: 'Recolector',
            centroNombre: 'Centro',
            placa: null,
            onDetails: () {},
            actions: const [],
          ),
        ),
      ),
    );

    expect(find.text('Oferta: Sin fecha'), findsOneWidget);
    expect(find.textContaining('1969'), findsNothing);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OfertaDetailDialog(
            oferta: _offer(
              createdAt: DateTime.fromMillisecondsSinceEpoch(0),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Sin fecha'), findsOneWidget);
    expect(find.textContaining('1969'), findsNothing);
  });

  testWidgets('a valid offer date includes date and time', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OfertaCard(
            oferta: _offer(createdAt: DateTime(2026, 11, 2, 14, 5)),
            recolectorNombre: 'Recolector',
            centroNombre: 'Centro',
            placa: null,
            onDetails: () {},
            actions: const [],
          ),
        ),
      ),
    );

    expect(find.text('Oferta: 02/11/2026 14:05'), findsOneWidget);
  });
}

OfertaEntity _offer({required DateTime? createdAt}) => OfertaEntity(
      id: 'offer-1',
      recolectorId: 'collector-1',
      centroId: 'center-1',
      categoria: 'plastico',
      peso: 1,
      precioSugerido: 10,
      estado: 'OFERTADA',
      fechaOferta: createdAt ?? DateTime.fromMillisecondsSinceEpoch(0),
      estadoActivo: true,
      createdAt: createdAt,
    );
