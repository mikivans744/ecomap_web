import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../presentation/providers/estadisticas_providers.dart';

class ChartDistribucionCategorias extends StatelessWidget {
  const ChartDistribucionCategorias({required this.data, super.key});
  final List<CategoriaDistribucion> data;
  @override
  Widget build(BuildContext context) {
    final total = data.fold<double>(0, (sum, item) => sum + item.kilos);
    return PieChart(PieChartData(centerSpaceRadius: 42, sections: [
      for (var index = 0; index < data.length; index++)
        PieChartSectionData(
            value: data[index].kilos,
            title: total == 0
                ? '0%'
                : '${(data[index].kilos / total * 100).round()}%',
            color: Colors.primaries[index % Colors.primaries.length],
            radius: 70)
    ]));
  }
}
