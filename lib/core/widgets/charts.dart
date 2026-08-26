import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../features/dashboard/domain/platform_metrics.dart';
import '../utils/formatters.dart';
import 'states.dart';

/// A titled panel that hosts a chart and handles its own async states, so one
/// failing aggregation never blanks the whole dashboard.
class ChartCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  final double height;
  final List<Widget> actions;

  const ChartCard({
    super.key,
    required this.title,
    this.subtitle,
    required this.child,
    this.height = 260,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(title,
                          style: t.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      if (subtitle != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            subtitle!,
                            style: t.textTheme.labelSmall
                                ?.copyWith(color: t.colorScheme.onSurfaceVariant),
                          ),
                        ),
                    ],
                  ),
                ),
                ...actions,
              ],
            ),
            const SizedBox(height: 18),
            SizedBox(height: height, child: child),
          ],
        ),
      ),
    );
  }
}

/// Line/area trend. Labels are thinned to fit the axis rather than overlapping.
class TrendChart extends StatelessWidget {
  final List<SeriesPoint> points;
  final Color color;
  final bool currency;

  const TrendChart({
    super.key,
    required this.points,
    required this.color,
    this.currency = false,
  });

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const EmptyState(title: 'No data in this period');
    }
    final t = Theme.of(context);
    final maxY = points.fold<double>(0, (m, p) => p.value > m ? p.value.toDouble() : m);
    final step = (points.length / 6).ceil().clamp(1, points.length);

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: maxY == 0 ? 1 : maxY * 1.2,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(
            color: t.colorScheme.outlineVariant.withValues(alpha: 0.4),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 52,
              getTitlesWidget: (v, _) => Text(
                currency ? moneyCompact(v) : qty(v),
                style: t.textTheme.labelSmall
                    ?.copyWith(color: t.colorScheme.onSurfaceVariant, fontSize: 10),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: 1,
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i < 0 || i >= points.length || i % step != 0) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    points[i].label,
                    style: t.textTheme.labelSmall
                        ?.copyWith(color: t.colorScheme.onSurfaceVariant, fontSize: 10),
                  ),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (spots) => spots
                .map((s) => LineTooltipItem(
                      '${points[s.x.toInt()].label}\n'
                      '${currency ? money(s.y) : qty(s.y)}',
                      TextStyle(
                        color: t.colorScheme.onInverseSurface,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ))
                .toList(),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: [
              for (var i = 0; i < points.length; i++)
                FlSpot(i.toDouble(), points[i].value.toDouble()),
            ],
            isCurved: true,
            curveSmoothness: 0.28,
            barWidth: 2.5,
            color: color,
            dotData: FlDotData(show: points.length <= 14),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [color.withValues(alpha: 0.28), color.withValues(alpha: 0.01)],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Horizontal ranked bars — used for leaderboards, where comparing lengths is
/// far easier to read than comparing pie slices.
class RankedBars extends StatelessWidget {
  final List<NamedValue> items;
  final bool currency;

  const RankedBars({super.key, required this.items, this.currency = false});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final visible = items.where((i) => i.value > 0).toList();
    if (visible.isEmpty) return const EmptyState(title: 'Nothing recorded yet');

    final max = visible.fold<double>(0, (m, i) => i.value > m ? i.value.toDouble() : m);

    return ListView.separated(
      itemCount: visible.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final item = visible[i];
        final color = chartPalette[i % chartPalette.length];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.name,
                    style: t.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  currency ? money(item.value) : qty(item.value),
                  style: t.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: max == 0 ? 0 : item.value / max,
                minHeight: 7,
                backgroundColor: t.colorScheme.outlineVariant.withValues(alpha: 0.35),
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
            if (item.subtitle != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  item.subtitle!,
                  style: t.textTheme.labelSmall
                      ?.copyWith(color: t.colorScheme.onSurfaceVariant),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Donut for part-to-whole splits (booking source, appointment status), with a
/// legend so colour is never the only way to identify a slice.
class DonutChart extends StatelessWidget {
  final List<NamedValue> items;
  const DonutChart({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final visible = items.where((i) => i.value > 0).toList();
    if (visible.isEmpty) return const EmptyState(title: 'Nothing recorded yet');
    final total = visible.fold<double>(0, (s, i) => s + i.value);

    return Row(
      children: [
        Expanded(
          flex: 4,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 44,
              sections: [
                for (var i = 0; i < visible.length; i++)
                  PieChartSectionData(
                    value: visible[i].value.toDouble(),
                    color: chartPalette[i % chartPalette.length],
                    radius: 34,
                    showTitle: false,
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 5,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < visible.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: chartPalette[i % chartPalette.length],
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          visible[i].name,
                          style: t.textTheme.bodySmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${qty(visible[i].value)}  '
                        '(${percent(total == 0 ? 0 : visible[i].value / total * 100, digits: 0)})',
                        style: t.textTheme.labelSmall?.copyWith(
                          color: t.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
