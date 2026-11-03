import 'package:flutter/material.dart';

import '../../../../domain/entities/recolector_entity.dart';

class MarcadorRecolector extends StatelessWidget {
  const MarcadorRecolector(
      {required this.recolector, required this.onTap, super.key});
  final RecolectorEntity recolector;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Icon(
          recolector.medioTransporte == 'bicicleta'
              ? Icons.pedal_bike
              : Icons.local_shipping,
          color: Colors.green,
          size: 34,
        ),
      );
}
