import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// The CRM stores appointment dates as 'yyyy-MM-dd' STRINGS (see
/// core/scheduling.js), not Timestamps. String range filters therefore work
/// correctly for date windows and are indexable, so every date-bounded query
/// in this console filters on that field server-side.
final DateFormat ymd = DateFormat('yyyy-MM-dd');

enum RangePreset { today, last7, last30, last90, thisMonth, thisYear, custom }

extension RangePresetLabel on RangePreset {
  String get label => switch (this) {
        RangePreset.today => 'Today',
        RangePreset.last7 => 'Last 7 days',
        RangePreset.last30 => 'Last 30 days',
        RangePreset.last90 => 'Last 90 days',
        RangePreset.thisMonth => 'This month',
        RangePreset.thisYear => 'This year',
        RangePreset.custom => 'Custom',
      };
}

@immutable
class DateWindow {
  final DateTime start;
  final DateTime end;
  final RangePreset preset;

  const DateWindow({required this.start, required this.end, required this.preset});

  factory DateWindow.of(RangePreset preset, {DateTime? now}) {
    final n = now ?? DateTime.now();
    final today = DateTime(n.year, n.month, n.day);
    return switch (preset) {
      RangePreset.today => DateWindow(start: today, end: today, preset: preset),
      RangePreset.last7 =>
        DateWindow(start: today.subtract(const Duration(days: 6)), end: today, preset: preset),
      RangePreset.last30 =>
        DateWindow(start: today.subtract(const Duration(days: 29)), end: today, preset: preset),
      RangePreset.last90 =>
        DateWindow(start: today.subtract(const Duration(days: 89)), end: today, preset: preset),
      RangePreset.thisMonth =>
        DateWindow(start: DateTime(n.year, n.month, 1), end: today, preset: preset),
      RangePreset.thisYear =>
        DateWindow(start: DateTime(n.year, 1, 1), end: today, preset: preset),
      RangePreset.custom =>
        DateWindow(start: today.subtract(const Duration(days: 29)), end: today, preset: preset),
    };
  }

  String get startKey => ymd.format(start);
  String get endKey => ymd.format(end);
  int get days => end.difference(start).inDays + 1;

  /// Same-length window immediately before this one, for growth comparisons.
  DateWindow get previous {
    final len = Duration(days: days);
    return DateWindow(
      start: start.subtract(len),
      end: start.subtract(const Duration(days: 1)),
      preset: RangePreset.custom,
    );
  }

  /// Every day key in the window, for dense chart series (no gaps).
  List<String> get dayKeys => List.generate(
        days,
        (i) => ymd.format(start.add(Duration(days: i))),
      );

  String get label => preset == RangePreset.custom
      ? '${DateFormat('d MMM y').format(start)} – ${DateFormat('d MMM y').format(end)}'
      : preset.label;

  DateWindow copyWith({DateTime? start, DateTime? end, RangePreset? preset}) => DateWindow(
        start: start ?? this.start,
        end: end ?? this.end,
        preset: preset ?? this.preset,
      );

  @override
  bool operator ==(Object other) =>
      other is DateWindow && other.startKey == startKey && other.endKey == endKey;

  @override
  int get hashCode => Object.hash(startKey, endKey);
}
