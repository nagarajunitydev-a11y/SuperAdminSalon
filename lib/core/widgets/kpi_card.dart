import 'package:flutter/material.dart';

import '../utils/formatters.dart';

/// A single headline figure with an optional period-over-period delta.
///
/// The delta never renders as a bare percentage when the baseline was zero —
/// that would be a division by nothing. It shows "New" instead, which is the
/// honest reading of "there was nothing before".
class KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final double? delta;
  final bool deltaUnavailable;
  final Color? accent;
  final String? footnote;

  const KpiCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.delta,
    this.deltaUnavailable = false,
    this.accent,
    this.footnote,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final c = accent ?? t.colorScheme.primary;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: c.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(icon, size: 17, color: c),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: t.textTheme.bodySmall?.copyWith(
                      color: t.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: t.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            if (delta != null || deltaUnavailable || footnote != null) ...[
              const SizedBox(height: 8),
              _Delta(delta: delta, unavailable: deltaUnavailable, footnote: footnote),
            ],
          ],
        ),
      ),
    );
  }
}

class _Delta extends StatelessWidget {
  final double? delta;
  final bool unavailable;
  final String? footnote;
  const _Delta({this.delta, required this.unavailable, this.footnote});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    if (delta == null) {
      return Text(
        unavailable ? 'New this period' : (footnote ?? ''),
        style: t.textTheme.labelSmall?.copyWith(color: t.colorScheme.onSurfaceVariant),
      );
    }
    final up = delta! >= 0;
    final color = up ? const Color(0xFF12A150) : const Color(0xFFE5484D);
    return Row(
      children: [
        Icon(up ? Icons.trending_up : Icons.trending_down, size: 15, color: color),
        const SizedBox(width: 4),
        Text(
          percent(delta!.abs()),
          style: t.textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w700),
        ),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            footnote ?? 'vs previous',
            style: t.textTheme.labelSmall?.copyWith(color: t.colorScheme.onSurfaceVariant),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// Responsive KPI grid: the column count follows the available width rather
/// than a fixed breakpoint list, so it degrades cleanly at any window size.
class KpiGrid extends StatelessWidget {
  final List<Widget> children;
  const KpiGrid({super.key, required this.children});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, c) {
          final columns = (c.maxWidth / 250).floor().clamp(1, 5);
          return GridView.count(
            crossAxisCount: columns,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            childAspectRatio: 1.62,
            children: children,
          );
        },
      );
}
