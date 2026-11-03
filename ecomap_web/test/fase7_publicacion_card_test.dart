import 'package:ecomap_web/domain/entities/publicacion_entity.dart';
import 'package:ecomap_web/presentation/pages/publicaciones/widgets/publicacion_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('muestra información y acciones seguras de una publicación',
      (tester) async {
    var detailsOpened = false;
    var activeToggled = false;
    final publication = PublicacionEntity(
      id: 'publication-1',
      userId: 'seller-1',
      titulo: 'Botellas PET',
      descripcion: 'Botellas limpias listas para reciclar',
      categoria: 'plastico',
      peso: 12,
      precioSugerido: 25,
      calidad: 'usado',
      estado: 'disponible',
      fechaPublicacion: DateTime(2026, 4, 12),
      estadoActivo: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PublicacionCard(
            publicacion: publication,
            vendedorEmail: 'seller@example.com',
            onDetails: () => detailsOpened = true,
            onToggleActive: () => activeToggled = true,
          ),
        ),
      ),
    );

    expect(find.text('Botellas PET'), findsOneWidget);
    expect(find.text('Botellas limpias listas para reciclar'), findsOneWidget);
    expect(find.text('Disponible'), findsOneWidget);
    expect(find.text('plastico'), findsOneWidget);
    expect(find.text('Peso: 12 kg'), findsOneWidget);
    expect(find.text('Precio: \$25'), findsOneWidget);
    expect(find.text('Usado'), findsOneWidget);
    expect(find.textContaining('seller@example.com'), findsOneWidget);
    expect(find.textContaining('12/04/2026'), findsOneWidget);
    expect(find.text('Marcar como vendida'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is OutlinedButton && widget.onPressed == null,
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Ver detalle'));
    await tester.tap(find.text('Desactivar'));
    expect(detailsOpened, isTrue);
    expect(activeToggled, isTrue);
  });
}
