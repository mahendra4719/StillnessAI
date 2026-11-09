import 'package:flutter/material.dart';
import '../app/theme.dart';

class SimpleBarChart extends StatelessWidget {
  final List<double?> values; // 0.0 to 1.0, null = no data
  final List<String> labels;
  const SimpleBarChart({super.key, required this.values, required this.labels});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 120,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < values.length; i++)
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (values[i] == null)
                    Container(
                      width: 22, height: 14,
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.muted, width: 1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    )
                  else
                    Container(
                      width: 22, height: 4 + values[i]! * 80,
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  const SizedBox(height: 6),
                  Text(labels[i],
                      style: const TextStyle(color: AppColors.muted, fontSize: 10)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}