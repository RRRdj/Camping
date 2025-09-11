// lib/widgets/weather_summary_chip.dart
import 'package:flutter/material.dart';
import 'weather_presenter.dart';

class WeatherSummaryChip extends StatelessWidget {
  final int? wmo;
  final double? temp;
  final int? pop;
  final EdgeInsetsGeometry padding;

  const WeatherSummaryChip({
    super.key,
    required this.wmo,
    this.temp,
    this.pop,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
  });

  @override
  Widget build(BuildContext context) {
    final pieces = <String>[];
    if (temp != null) pieces.add('${temp!.toStringAsFixed(1)}℃');
    if (pop != null) pieces.add('강수 ${pop!}%');
    pieces.add(wmoKoText(wmo));

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.25),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            wmoIcon(wmo),
            size: 16,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 6),
          Text(pieces.join(' · '), style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}
