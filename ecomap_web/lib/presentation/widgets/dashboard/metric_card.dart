import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.title,
    required this.value,
    this.delta,
    required this.icon,
    this.color = AppColors.primary,
    this.valueColor,
  });

  final String title;
  final String value;
  final String? delta;
  final IconData icon;
  final Color color;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 220;

          return Padding(
            padding: EdgeInsets.all(isCompact ? 12 : 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: isCompact ? 36 : 42,
                      height: isCompact ? 36 : 42,
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: color),
                    ),
                    const SizedBox(width: 8),
                    if (delta != null && delta!.isNotEmpty)
                      Expanded(
                        child: Text(
                          delta!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.end,
                          style: textTheme.labelLarge?.copyWith(
                            color: color,
                            fontSize: isCompact ? 12 : null,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
                SizedBox(height: isCompact ? 12 : 20),
                Text(
                  title,
                  style: textTheme.labelLarge?.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: isCompact ? 12 : null,
                  ),
                ),
                SizedBox(height: isCompact ? 4 : 6),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.headlineSmall?.copyWith(
                    fontSize: isCompact ? 22 : null,
                    fontWeight: FontWeight.w700,
                    color: valueColor,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
