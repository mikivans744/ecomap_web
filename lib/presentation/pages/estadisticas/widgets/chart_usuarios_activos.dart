import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../presentation/providers/estadisticas_providers.dart';

class ChartUsuariosActivos extends StatelessWidget {
  const ChartUsuariosActivos({required this.data, super.key});
  final List<UsuarioActivoMes> data;
  @override
  Widget build(BuildContext context) => LineChart(
        LineChartData(
          minY: 0,
          lineBarsData: [
            LineChartBarData(
              isCurved: true,
              color: Colors.green,
              spots: [
                for (var index = 0; index < data.length; index++)
                  FlSpot(index.toDouble(), data[index].ciudadanos.toDouble()),
              ],
            ),
          ],
        ),
      );
}
