import 'package:flutter/material.dart';
import '../app/theme.dart';

class AppCard extends StatelessWidget {
  final Widget child;
  const AppCard({super.key, required this.child});
  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(padding: const EdgeInsets.all(16), child: child),
      );
}

class SectionLabel extends StatelessWidget {
  final String text;
  const SectionLabel(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text.toUpperCase(),
            style: const TextStyle(
                color: AppColors.muted, fontSize: 12, letterSpacing: 1)),
      );
}

class MetricRow extends StatelessWidget {
  final String label, value;
  final Color? color;
  const MetricRow(this.label, this.value, {super.key, this.color});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.border))),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: AppColors.muted)),
            const SizedBox(width: 12),
            Flexible(
                child: Text(value,
                    textAlign: TextAlign.right,
                    style: TextStyle(color: color))),
          ],
        ),
      );
}

class Pill extends StatelessWidget {
  final String text;
  const Pill(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
            color: const Color(0xFF1E3B34),
            borderRadius: BorderRadius.circular(20)),
        child: Text(text,
            style: const TextStyle(color: AppColors.good, fontSize: 12)),
      );
}

Future<bool> confirmDialog(BuildContext context, String title, String body) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirm')),
      ],
    ),
  );
  return r ?? false;
}