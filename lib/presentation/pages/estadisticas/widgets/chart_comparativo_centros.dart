import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../presentation/providers/estadisticas_providers.dart';

class ChartComparativoCentros extends StatelessWidget {
  const ChartComparativoCentros({required this.data, super.key});
  final List<CentroStats> data;
  @override
  Widget build(BuildContext context) => BarChart(
        BarChartData(
          barGroups: [
            for (var index = 0; index < data.length; index++)
              BarChartGroupData(
                x: index,
                barsSpace: 4,
                barRods: [
                  BarChartRodData(
                      toY: data[index].maxima, color: Colors.grey, width: 9),
                  BarChartRodData(
                      toY: data[index].comprometida,
                      color: Colors.green,
                      width: 9),
                ],
              ),
          ],
        ),
      );
}
