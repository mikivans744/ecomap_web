import 'package:ecomap_web/presentation/providers/material_category_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('uses the official category IDs and display names', () {
    const catalog = MaterialCategoryCatalog.fallback;

    expect(
      catalog.categories.map((category) => category.id).toList(),
      [
        'PLASTICO',
        'METAL',
        'VIDRIO',
        'PAPEL_CARTON',
        'ELECTRONICO',
        'TEXTIL',
        'OTRO',
      ],
    );
    expect(
      catalog.categories.map((category) => category.displayName).toList(),
      [
        'Plástico',
        'Metal',
        'Vidrio',
        'Papel y cartón',
        'Electrónico',
        'Textil',
        'Otros',
      ],
    );
  });

  test('normalizes legacy labels and hides unrecognized raw values', () {
    expect(materialCategoryId('Papel y cartón'), 'PAPEL_CARTON');
    expect(materialCategoryId('plastico'), 'PLASTICO');
    expect(displayMaterialCategory('ELECTRONICO'), 'Electrónico');
    expect(materialCategoryId('1'), isNull);
    expect(displayMaterialCategory('1'), 'Sin categoría');
  });
}
