import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/value_controller.dart';
import '../utils/date_range.dart';

/// The window every analytics query in the console is scoped to. Held in one
/// place so a change re-runs each dependent provider exactly once.
final dateWindowProvider = valueProvider<DateWindow>(DateWindow.of(RangePreset.last30));

class DateRangeSelector extends ConsumerWidget {
  const DateRangeSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final window = ref.watch(dateWindowProvider);
    final t = Theme.of(context);

    return PopupMenuButton<RangePreset>(
      tooltip: 'Change reporting period',
      position: PopupMenuPosition.under,
      onSelected: (preset) async {
        if (preset == RangePreset.custom) {
          final picked = await showDateRangePicker(
            context: context,
            firstDate: DateTime(2020),
            lastDate: DateTime.now(),
            initialDateRange: DateTimeRange(start: window.start, end: window.end),
          );
          if (picked != null) {
            ref.read(dateWindowProvider.notifier).setValue(DateWindow(
                  start: picked.start,
                  end: picked.end,
                  preset: RangePreset.custom,
                ));
          }
          return;
        }
        ref.read(dateWindowProvider.notifier).setValue(DateWindow.of(preset));
      },
      itemBuilder: (_) => [
        for (final p in RangePreset.values)
          PopupMenuItem(value: p, child: Text(p.label)),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: t.colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(10),
          color: t.cardTheme.color,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calendar_today_outlined, size: 15, color: t.colorScheme.onSurfaceVariant),
            const SizedBox(width: 8),
            Text(window.label, style: t.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(width: 4),
            Icon(Icons.expand_more, size: 17, color: t.colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
