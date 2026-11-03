import 'package:flutter/material.dart';

class PopupInfo extends StatelessWidget {
  const PopupInfo({required this.title, required this.rows, super.key});
  final String title;
  final List<({String label, String value})> rows;

  @override
  Widget build(BuildContext context) => Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...rows.map((row) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text('${row.label}: ${row.value}'),
                  )),
            ],
          ),
        ),
      );
}
