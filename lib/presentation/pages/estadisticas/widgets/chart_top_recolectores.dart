import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../presentation/providers/estadisticas_providers.dart';

class ChartTopRecolectores extends StatelessWidget {
  const ChartTopRecolectores({required this.data, super.key});
  final List<RecolectorStats> data;
  @override
  Widget build(BuildContext context) => BarChart(BarChartData(
          barGroups: [
            for (var index = 0; index < data.length; index++)
              BarChartGroupData(x: index, barRods: [
                BarChartRodData(
                    toY: data[index].kilos, color: Colors.green, width: 18)
              ])
          ],
          titlesData: FlTitlesData(
              bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) => Text(
                          value.toInt() < data.length
                              ? data[value.toInt()].nombre.split(' ').first
                              : ''))))));
}
