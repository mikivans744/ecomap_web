import 'package:flutter/material.dart';

import '../providers/material_category_provider.dart';

class CategoryCatalogNotice extends StatelessWidget {
  const CategoryCatalogNotice({
    super.key,
    required this.catalog,
    this.onSeed,
  });

  final MaterialCategoryCatalog catalog;
  final VoidCallback? onSeed;

  @override
  Widget build(BuildContext context) {
    if (catalog.isSeeded) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(
              children: [
                Icon(Icons.info_outline),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'El catálogo de categorías está vacío o incompleto. '
                    'Siembra el catálogo desde Publicaciones.',
                  ),
                ),
              ],
            ),
            if (onSeed != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: onSeed,
                  child: const Text('Sembrar catálogo oficial'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
