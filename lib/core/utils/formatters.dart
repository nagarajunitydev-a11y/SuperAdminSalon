import 'package:intl/intl.dart';

final _inr = NumberFormat.currency(locale: 'en_IN', symbol: '\u20B9', decimalDigits: 0);
final _compact = NumberFormat.compactCurrency(locale: 'en_IN', symbol: '\u20B9', decimalDigits: 1);
final _num = NumberFormat.decimalPattern('en_IN');

String money(num? v) => _inr.format(v ?? 0);
String moneyCompact(num? v) => (v ?? 0).abs() >= 100000 ? _compact.format(v ?? 0) : _inr.format(v ?? 0);
String qty(num? v) => _num.format(v ?? 0);
String percent(num? v, {int digits = 1}) => '${(v ?? 0).toStringAsFixed(digits)}%';

/// Growth between two periods. Returns null when the baseline is zero, so the
/// UI can show "new" instead of a meaningless infinite percentage.
double? growth(num current, num previous) {
  if (previous == 0) return current == 0 ? 0 : null;
  return ((current - previous) / previous) * 100;
}
