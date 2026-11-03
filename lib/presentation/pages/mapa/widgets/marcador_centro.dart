import 'package:flutter/material.dart';

import '../../../../domain/entities/centro_acopio_entity.dart';

class MarcadorCentro extends StatelessWidget {
  const MarcadorCentro({required this.centro, required this.onTap, super.key});
  final CentroAcopioEntity centro;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: const Icon(Icons.warehouse, color: Colors.orange, size: 34),
      );
}
