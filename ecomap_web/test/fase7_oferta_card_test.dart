import 'package:ecomap_web/domain/entities/oferta_entity.dart';
import 'package:ecomap_web/presentation/pages/ofertas/widgets/oferta_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('muestra datos y acciones de una oferta pendiente',
      (tester) async {
    var detailsOpened = false;
    var accepted = false;
    final offer = OfertaEntity(
      id: 'offer-12345678',
      recolectorId: 'collector-1',
      centroId: 'center-1',
      categoria: 'plastico',
      peso: 20,
      precioSugerido: 40,
      estado: 'pendiente',
      fechaOferta: DateTime(2026, 4, 12, 9, 30),
      estadoActivo: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OfertaCard(
            oferta: offer,
            recolectorNombre: 'María Pérez',
            centroNombre: 'Centro Norte',
            placa: null,
            onDetails: () => detailsOpened = true,
            actions: [
              FilledButton(
                onPressed: () => accepted = true,
                child: const Text('Aceptar'),
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Oferta #offer-12'), findsOneWidget);
    expect(find.text('Pendiente'), findsOneWidget);
    expect(find.text('María Pérez'), findsOneWidget);
    expect(find.text('Centro Norte'), findsOneWidget);
    expect(find.text('plastico'), findsOneWidget);
    expect(find.text('Peso: 20 kg'), findsOneWidget);
    expect(find.text('Precio: \$40'), findsOneWidget);
    expect(find.textContaining('12/04/2026 09:30'), findsOneWidget);

    await tester.tap(find.text('Ver detalle'));
    await tester.tap(find.text('Aceptar'));
    expect(detailsOpened, isTrue);
    expect(accepted, isTrue);
  });
}
