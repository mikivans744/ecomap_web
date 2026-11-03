import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../presentation/providers/estadisticas_providers.dart';

class ChartMaterialesMes extends StatelessWidget {
  const ChartMaterialesMes({required this.data, super.key});
  final List<MaterialesMes> data;
  @override
  Widget build(BuildContext context) {
    final categories =
        data.expand((item) => item.valores.keys).toSet().toList();
    return LineChart(LineChartData(minY: 0, lineBarsData: [
      for (var index = 0; index < categories.length; index++)
        LineChartBarData(
            isCurved: true,
            color: Colors.primaries[index % Colors.primaries.length],
            spots: [
              for (var month = 0; month < data.length; month++)
                FlSpot(month.toDouble(),
                    data[month].valores[categories[index]] ?? 0)
            ])
    ]));
  }
}
