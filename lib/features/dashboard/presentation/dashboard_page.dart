import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/shell.dart';
import '../../../app/theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/charts.dart';
import '../../../core/widgets/date_range_picker.dart';
import '../../../core/widgets/kpi_card.dart';
import '../../../core/widgets/states.dart';
import '../domain/platform_metrics.dart';
import 'dashboard_controller.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final window = ref.watch(dateWindowProvider);
    final metrics = ref.watch(platformMetricsProvider(null));

    return PageBody(
      title: 'Platform Overview',
      subtitle: 'All salons · ${window.label}',
      actions: [
        OutlinedButton.icon(
          onPressed: () => refreshAnalytics(ref),
          icon: const Icon(Icons.refresh, size: 17),
          label: const Text('Refresh'),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          metrics.when(
            loading: () => const LoadingState(height: 320),
            error: (e, _) => ErrorState(
              error: e,
              onRetry: () => ref.invalidate(platformMetricsProvider),
            ),
            data: (m) => _Kpis(m: m),
          ),
          const SizedBox(height: 26),
          const _TrendSection(),
          const SizedBox(height: 16),
          const _GrowthSection(),
          const SizedBox(height: 16),
          const _BreakdownSection(),
          const SizedBox(height: 16),
          const _TopSalonsSection(),
        ],
      ),
    );
  }
}

class _Kpis extends StatelessWidget {
  final PlatformMetrics m;
  const _Kpis({required this.m});

  @override
  Widget build(BuildContext context) {
    return KpiGrid(
      children: [
        KpiCard(
          label: 'Total Revenue',
          value: money(m.totalRevenue.value),
          icon: Icons.account_balance_wallet_outlined,
          accent: chartPalette[1],
          delta: growth(m.totalRevenue.value, m.totalRevenue.previous ?? 0),
          deltaUnavailable: growth(m.totalRevenue.value, m.totalRevenue.previous ?? 0) == null,
        ),
        KpiCard(
          label: "Today's Revenue",
          value: money(m.todaysRevenue.value),
          icon: Icons.today_outlined,
          accent: chartPalette[1],
          footnote: 'Settled invoices today',
        ),
        KpiCard(
          label: 'Monthly Revenue',
          value: money(m.monthlyRevenue.value),
          icon: Icons.calendar_month_outlined,
          accent: chartPalette[1],
          footnote: 'Month to date',
        ),
        KpiCard(
          label: 'Outstanding Payments',
          value: money(m.outstandingPayments.value),
          icon: Icons.pending_actions_outlined,
          accent: chartPalette[3],
          footnote: 'Completed but unpaid',
        ),
        KpiCard(
          label: 'Total Salons',
          value: qty(m.totalSalons.value),
          icon: Icons.storefront_outlined,
          footnote: '${qty(m.activeSalons.value)} active · '
              '${qty(m.suspendedSalons.value)} suspended',
        ),
        KpiCard(
          label: 'New Salons',
          value: qty(m.newSalons.value),
          icon: Icons.add_business_outlined,
          delta: growth(m.newSalons.value, m.newSalons.previous ?? 0),
          deltaUnavailable: growth(m.newSalons.value, m.newSalons.previous ?? 0) == null,
        ),
        KpiCard(
          label: 'Total Customers',
          value: qty(m.totalCustomers.value),
          icon: Icons.groups_outlined,
          accent: chartPalette[4],
        ),
        KpiCard(
          label: 'New Customers',
          value: qty(m.newCustomers.value),
          icon: Icons.person_add_alt_outlined,
          accent: chartPalette[4],
          delta: growth(m.newCustomers.value, m.newCustomers.previous ?? 0),
          deltaUnavailable: growth(m.newCustomers.value, m.newCustomers.previous ?? 0) == null,
        ),
        KpiCard(
          label: 'Total Appointments',
          value: qty(m.totalAppointments.value),
          icon: Icons.event_note_outlined,
          delta: growth(m.totalAppointments.value, m.totalAppointments.previous ?? 0),
          deltaUnavailable:
              growth(m.totalAppointments.value, m.totalAppointments.previous ?? 0) == null,
        ),
        KpiCard(
          label: "Today's Appointments",
          value: qty(m.todaysAppointments.value),
          icon: Icons.schedule_outlined,
        ),
        KpiCard(
          label: 'Completed',
          value: qty(m.completedAppointments.value),
          icon: Icons.check_circle_outline,
          accent: chartPalette[5],
        ),
        KpiCard(
          label: 'Cancelled',
          value: qty(m.cancelledAppointments.value),
          icon: Icons.cancel_outlined,
          accent: chartPalette[3],
          footnote: '${percent(m.cancellationRate)} cancellation rate',
        ),
        KpiCard(
          label: 'Total Staff',
          value: qty(m.totalStaff.value),
          icon: Icons.engineering_outlined,
        ),
        KpiCard(
          label: 'Total Services',
          value: qty(m.totalServices.value),
          icon: Icons.design_services_outlined,
        ),
        KpiCard(
          label: 'Referral Wallet Used',
          value: money(m.referralRevenue.value),
          icon: Icons.card_giftcard_outlined,
          accent: chartPalette[2],
          footnote: 'Redeemed on invoices',
        ),
        KpiCard(
          label: 'Loyalty Redemptions',
          value: qty(m.loyaltyRedemptions.value),
          icon: Icons.stars_outlined,
          accent: chartPalette[2],
        ),
        KpiCard(
          label: 'Public / WhatsApp Bookings',
          value: qty(m.publicBookings.value),
          icon: Icons.alt_route_outlined,
          accent: chartPalette[4],
        ),
      ],
    );
  }
}

/// Two charts side by side on wide screens, stacked when narrow.
class _Pair extends StatelessWidget {
  final Widget left;
  final Widget right;
  const _Pair({required this.left, required this.right});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, c) {
          if (c.maxWidth < 860) {
            return Column(children: [left, const SizedBox(height: 16), right]);
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: left),
              const SizedBox(width: 16),
              Expanded(child: right),
            ],
          );
        },
      );
}

class _TrendSection extends ConsumerWidget {
  const _TrendSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trend = ref.watch(trendProvider(null));
    return _Pair(
      left: ChartCard(
        title: 'Revenue growth',
        subtitle: 'Settled invoice value over time',
        child: trend.when(
          loading: () => const LoadingState(),
          error: (e, _) => ErrorState(error: e, compact: true),
          data: (d) => TrendChart(points: d.primary, color: chartPalette[1], currency: true),
        ),
      ),
      right: ChartCard(
        title: 'Appointment trends',
        subtitle: 'Bookings created over time',
        child: trend.when(
          loading: () => const LoadingState(),
          error: (e, _) => ErrorState(error: e, compact: true),
          data: (d) => TrendChart(points: d.secondary, color: chartPalette[0]),
        ),
      ),
    );
  }
}

class _GrowthSection extends ConsumerWidget {
  const _GrowthSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final growthData = ref.watch(growthProvider);
    return _Pair(
      left: ChartCard(
        title: 'New salon registrations',
        subtitle: 'Platform expansion',
        child: growthData.when(
          loading: () => const LoadingState(),
          error: (e, _) => ErrorState(error: e, compact: true),
          data: (d) => TrendChart(points: d.primary, color: chartPalette[2]),
        ),
      ),
      right: ChartCard(
        title: 'Customer growth',
        subtitle: 'New clients across all salons',
        child: growthData.when(
          loading: () => const LoadingState(),
          error: (e, _) => ErrorState(error: e, compact: true),
          data: (d) => TrendChart(points: d.secondary, color: chartPalette[4]),
        ),
      ),
    );
  }
}

class _BreakdownSection extends ConsumerWidget {
  const _BreakdownSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sources = ref.watch(bookingSourcesProvider(null));
    final referrals = ref.watch(referralPerformanceProvider(null));
    return _Pair(
      left: ChartCard(
        title: 'Booking source',
        subtitle: 'Where bookings originate',
        child: sources.when(
          loading: () => const LoadingState(),
          error: (e, _) => ErrorState(error: e, compact: true),
          data: (d) => DonutChart(items: d),
        ),
      ),
      right: ChartCard(
        title: 'Referral performance',
        subtitle: 'Referrals by lifecycle stage',
        child: referrals.when(
          loading: () => const LoadingState(),
          error: (e, _) => ErrorState(error: e, compact: true),
          data: (d) => RankedBars(items: d),
        ),
      ),
    );
  }
}

class _TopSalonsSection extends ConsumerWidget {
  const _TopSalonsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final top = ref.watch(topSalonsProvider);
    return ChartCard(
      title: 'Top-performing salons',
      subtitle: 'Ranked by settled revenue in the selected period',
      height: 300,
      actions: [
        TextButton(
          onPressed: () => context.go(Routes.salons),
          child: const Text('View all'),
        ),
      ],
      child: top.when(
        loading: () => const LoadingState(),
        error: (e, _) => ErrorState(error: e, compact: true),
        data: (rows) => RankedBars(
          currency: true,
          items: [
            for (final r in rows)
              NamedValue(
                r.salon.name,
                r.revenue,
                subtitle: '${qty(r.bookings)} bookings · '
                    '${qty(r.customers)} clients'
                    '${r.salon.isSuspended ? ' · SUSPENDED' : ''}',
              ),
          ],
        ),
      ),
    );
  }
}
