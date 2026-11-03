import 'package:flutter/material.dart';

import '../../../../domain/entities/publicacion_entity.dart';

class MarcadorPublicacion extends StatelessWidget {
  const MarcadorPublicacion(
      {required this.publicacion, required this.onTap, super.key});
  final PublicacionEntity publicacion;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: const Icon(Icons.inventory_2, color: Colors.blue, size: 32),
      );
}
