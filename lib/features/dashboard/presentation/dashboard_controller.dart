import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/date_range_picker.dart';
import '../../salons/data/salon_repository.dart';
import '../../salons/domain/salon.dart';
import '../data/metrics_repository.dart';
import '../domain/platform_metrics.dart';

/// Analytics providers are keyed by the active date window and are `autoDispose`
/// with a keepAlive link, so:
///   - changing the window issues each query exactly once, and
///   - navigating away and back reuses the cached result instead of re-querying.
/// This is what keeps the console from re-running aggregations on every rebuild.

final platformMetricsProvider =
    FutureProvider.autoDispose.family<PlatformMetrics, String?>((ref, salonId) async {
  ref.keepAlive();
  final window = ref.watch(dateWindowProvider);
  return ref.watch(metricsRepositoryProvider).loadPlatformMetrics(window, salonId: salonId);
});

final trendProvider =
    FutureProvider.autoDispose.family<TrendData, String?>((ref, salonId) async {
  ref.keepAlive();
  final window = ref.watch(dateWindowProvider);
  return ref.watch(metricsRepositoryProvider).loadTrend(window, salonId: salonId);
});

final growthProvider = FutureProvider.autoDispose<TrendData>((ref) async {
  ref.keepAlive();
  final window = ref.watch(dateWindowProvider);
  return ref.watch(metricsRepositoryProvider).loadGrowth(window);
});

final bookingSourcesProvider =
    FutureProvider.autoDispose.family<List<NamedValue>, String?>((ref, salonId) async {
  ref.keepAlive();
  final window = ref.watch(dateWindowProvider);
  return ref.watch(metricsRepositoryProvider).loadBookingSources(window, salonId: salonId);
});

final referralPerformanceProvider =
    FutureProvider.autoDispose.family<List<NamedValue>, String?>((ref, salonId) async {
  ref.keepAlive();
  return ref.watch(metricsRepositoryProvider).loadReferralPerformance(salonId: salonId);
});

final statusBreakdownProvider =
    FutureProvider.autoDispose.family<List<NamedValue>, String?>((ref, salonId) async {
  ref.keepAlive();
  final window = ref.watch(dateWindowProvider);
  return ref.watch(metricsRepositoryProvider).loadStatusBreakdown(window, salonId: salonId);
});

/// Top-performing salons. Deliberately bounded: it ranks the most recent page
/// of salons, never the entire platform, so the query count stays constant as
/// the platform grows.
final topSalonsProvider = FutureProvider.autoDispose<List<SalonPerformance>>((ref) async {
  ref.keepAlive();
  final window = ref.watch(dateWindowProvider);
  final repo = ref.watch(salonRepositoryProvider);
  final page = await repo.fetchPage(limit: 12);
  final perf = await repo.loadPerformance(page.items, window);
  perf.sort((a, b) => b.revenue.compareTo(a.revenue));
  return perf;
});

/// Invalidate every analytics provider at once (the Refresh action).
void refreshAnalytics(WidgetRef ref) {
  ref.invalidate(platformMetricsProvider);
  ref.invalidate(trendProvider);
  ref.invalidate(growthProvider);
  ref.invalidate(bookingSourcesProvider);
  ref.invalidate(referralPerformanceProvider);
  ref.invalidate(statusBreakdownProvider);
  ref.invalidate(topSalonsProvider);
}
