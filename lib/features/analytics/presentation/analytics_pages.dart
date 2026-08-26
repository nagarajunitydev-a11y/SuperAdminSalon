import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/shell.dart';
import '../../../app/theme.dart';
import '../../../core/constants/collections.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/charts.dart';
import '../../../core/widgets/date_range_picker.dart';
import '../../../core/widgets/kpi_card.dart';
import '../../../core/widgets/states.dart';
import '../../auth/data/auth_repository.dart';
import '../../dashboard/domain/platform_metrics.dart';
import '../../dashboard/presentation/dashboard_controller.dart';
import '../data/catalog_repository.dart';

/// Shared layout: KPI strip on top, charts below. Every analytics module is a
/// projection of the same aggregation layer, so they share this shape.
class _AnalyticsScaffold extends ConsumerWidget {
  final String title;
  final String subtitle;
  final List<Widget> Function(BuildContext, WidgetRef) body;

  const _AnalyticsScaffold({
    required this.title,
    required this.subtitle,
    required this.body,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final window = ref.watch(dateWindowProvider);
    return PageBody(
      title: title,
      subtitle: '$subtitle · ${window.label}',
      actions: [
        OutlinedButton.icon(
          onPressed: () => refreshAnalytics(ref),
          icon: const Icon(Icons.refresh, size: 17),
          label: const Text('Refresh'),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: body(context, ref),
      ),
    );
  }
}

Widget _pair(BuildContext context, Widget a, Widget b) => LayoutBuilder(
      builder: (context, c) => c.maxWidth < 860
          ? Column(children: [a, const SizedBox(height: 16), b])
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: a),
                const SizedBox(width: 16),
                Expanded(child: b),
              ],
            ),
    );

Widget _metricsSlice(WidgetRef ref, List<Widget> Function(PlatformMetrics) build) {
  final m = ref.watch(platformMetricsProvider(null));
  return m.when(
    loading: () => const LoadingState(height: 200),
    error: (e, _) => ErrorState(error: e, onRetry: () => ref.invalidate(platformMetricsProvider)),
    data: (data) => KpiGrid(children: build(data)),
  );
}

// ---------------------------------------------------------------- Customers

class CustomersAnalyticsPage extends StatelessWidget {
  const CustomersAnalyticsPage({super.key});

  @override
  Widget build(BuildContext context) => _AnalyticsScaffold(
        title: 'Customers Analytics',
        subtitle: 'Client base across every salon',
        body: (context, ref) => [
          _metricsSlice(ref, (m) => [
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
                  deltaUnavailable:
                      growth(m.newCustomers.value, m.newCustomers.previous ?? 0) == null,
                ),
                KpiCard(
                  label: 'Bookings per period',
                  value: qty(m.totalAppointments.value),
                  icon: Icons.event_note_outlined,
                ),
              ]),
          const SizedBox(height: 22),
          Consumer(builder: (context, ref, _) {
            final g = ref.watch(growthProvider);
            return ChartCard(
              title: 'Customer growth',
              subtitle: 'New clients registered over time',
              height: 300,
              child: g.when(
                loading: () => const LoadingState(),
                error: (e, _) => ErrorState(error: e, compact: true),
                data: (d) => TrendChart(points: d.secondary, color: chartPalette[4]),
              ),
            );
          }),
        ],
      );
}

// ------------------------------------------------------------- Appointments

class AppointmentsAnalyticsPage extends StatelessWidget {
  const AppointmentsAnalyticsPage({super.key});

  @override
  Widget build(BuildContext context) => _AnalyticsScaffold(
        title: 'Appointments Analytics',
        subtitle: 'Booking volume and outcomes',
        body: (context, ref) => [
          _metricsSlice(ref, (m) => [
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
                  icon: Icons.today_outlined,
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
                ),
                KpiCard(
                  label: 'Cancellation rate',
                  value: percent(m.cancellationRate),
                  icon: Icons.percent,
                  accent: chartPalette[3],
                ),
              ]),
          const SizedBox(height: 22),
          Consumer(builder: (context, ref, _) {
            final trend = ref.watch(trendProvider(null));
            final statuses = ref.watch(statusBreakdownProvider(null));
            return _pair(
              context,
              ChartCard(
                title: 'Appointment trends',
                subtitle: 'Bookings over time',
                child: trend.when(
                  loading: () => const LoadingState(),
                  error: (e, _) => ErrorState(error: e, compact: true),
                  data: (d) => TrendChart(points: d.secondary, color: chartPalette[0]),
                ),
              ),
              ChartCard(
                title: 'Status breakdown',
                subtitle: 'Where bookings end up',
                child: statuses.when(
                  loading: () => const LoadingState(),
                  error: (e, _) => ErrorState(error: e, compact: true),
                  data: (d) => DonutChart(items: d),
                ),
              ),
            );
          }),
        ],
      );
}

// ------------------------------------------------------------------ Revenue

class RevenuePage extends StatelessWidget {
  const RevenuePage({super.key});

  @override
  Widget build(BuildContext context) => _AnalyticsScaffold(
        title: 'Revenue & Payments',
        subtitle: 'Settled invoices, outstanding balances and wallet usage',
        body: (context, ref) => [
          _metricsSlice(ref, (m) => [
                KpiCard(
                  label: 'Total Revenue',
                  value: money(m.totalRevenue.value),
                  icon: Icons.account_balance_wallet_outlined,
                  accent: chartPalette[1],
                  delta: growth(m.totalRevenue.value, m.totalRevenue.previous ?? 0),
                  deltaUnavailable:
                      growth(m.totalRevenue.value, m.totalRevenue.previous ?? 0) == null,
                ),
                KpiCard(
                  label: "Today's Revenue",
                  value: money(m.todaysRevenue.value),
                  icon: Icons.today_outlined,
                  accent: chartPalette[1],
                ),
                KpiCard(
                  label: 'Monthly Revenue',
                  value: money(m.monthlyRevenue.value),
                  icon: Icons.calendar_month_outlined,
                  accent: chartPalette[1],
                ),
                KpiCard(
                  label: 'Outstanding Payments',
                  value: money(m.outstandingPayments.value),
                  icon: Icons.pending_actions_outlined,
                  accent: chartPalette[3],
                  footnote: 'Completed but unpaid',
                ),
                KpiCard(
                  label: 'Referral wallet used',
                  value: money(m.referralRevenue.value),
                  icon: Icons.card_giftcard_outlined,
                  accent: chartPalette[2],
                ),
              ]),
          const SizedBox(height: 22),
          Consumer(builder: (context, ref, _) {
            final trend = ref.watch(trendProvider(null));
            return ChartCard(
              title: 'Revenue growth',
              subtitle: 'Settled invoice value over time',
              height: 320,
              child: trend.when(
                loading: () => const LoadingState(),
                error: (e, _) => ErrorState(error: e, compact: true),
                data: (d) => TrendChart(points: d.primary, color: chartPalette[1], currency: true),
              ),
            );
          }),
        ],
      );
}

// ----------------------------------------------------------------- Services

class ServicesAnalyticsPage extends ConsumerWidget {
  const ServicesAnalyticsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final top = ref.watch(topServicesProvider);
    final window = ref.watch(dateWindowProvider);
    return PageBody(
      title: 'Services Analytics',
      subtitle: 'Most booked services across the platform · ${window.label}',
      actions: [
        OutlinedButton.icon(
          onPressed: () => ref.invalidate(topServicesProvider),
          icon: const Icon(Icons.refresh, size: 17),
          label: const Text('Refresh'),
        ),
      ],
      child: ChartCard(
        title: 'Top services',
        subtitle: 'By number of bookings in the selected period',
        height: 420,
        child: top.when(
          loading: () => const LoadingState(height: 380),
          error: (e, _) => ErrorState(error: e, onRetry: () => ref.invalidate(topServicesProvider)),
          data: (rows) => RankedBars(items: rows),
        ),
      ),
    );
  }
}

// -------------------------------------------------------------------- Staff

class StaffAnalyticsPage extends ConsumerWidget {
  const StaffAnalyticsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final top = ref.watch(staffUtilisationProvider);
    final window = ref.watch(dateWindowProvider);
    return PageBody(
      title: 'Staff Analytics',
      subtitle: 'Staff utilisation by booking volume · ${window.label}',
      actions: [
        OutlinedButton.icon(
          onPressed: () => ref.invalidate(staffUtilisationProvider),
          icon: const Icon(Icons.refresh, size: 17),
          label: const Text('Refresh'),
        ),
      ],
      child: ChartCard(
        title: 'Busiest staff',
        subtitle: 'Appointments assigned in the selected period',
        height: 420,
        child: top.when(
          loading: () => const LoadingState(height: 380),
          error: (e, _) =>
              ErrorState(error: e, onRetry: () => ref.invalidate(staffUtilisationProvider)),
          data: (rows) => RankedBars(items: rows),
        ),
      ),
    );
  }
}

// -------------------------------------------------------- Referrals/Loyalty

class ReferralsPage extends StatelessWidget {
  const ReferralsPage({super.key});

  @override
  Widget build(BuildContext context) => _AnalyticsScaffold(
        title: 'Referrals & Loyalty',
        subtitle: 'Referral funnel and loyalty programme usage',
        body: (context, ref) => [
          _metricsSlice(ref, (m) => [
                KpiCard(
                  label: 'Referral wallet used',
                  value: money(m.referralRevenue.value),
                  icon: Icons.card_giftcard_outlined,
                  accent: chartPalette[2],
                  footnote: 'Redeemed against invoices',
                ),
                KpiCard(
                  label: 'Loyalty redemptions',
                  value: qty(m.loyaltyRedemptions.value),
                  icon: Icons.stars_outlined,
                  accent: chartPalette[2],
                ),
              ]),
          const SizedBox(height: 22),
          Consumer(builder: (context, ref, _) {
            final referrals = ref.watch(referralPerformanceProvider(null));
            return ChartCard(
              title: 'Referral performance',
              subtitle: 'Referrals by lifecycle stage across all salons',
              height: 320,
              child: referrals.when(
                loading: () => const LoadingState(),
                error: (e, _) => ErrorState(error: e, compact: true),
                data: (d) => RankedBars(items: d),
              ),
            );
          }),
        ],
      );
}

// ---------------------------------------------------------- Booking sources

class BookingSourcesPage extends StatelessWidget {
  const BookingSourcesPage({super.key});

  @override
  Widget build(BuildContext context) => _AnalyticsScaffold(
        title: 'Booking Sources',
        subtitle: 'In-CRM vs public booking page vs WhatsApp',
        body: (context, ref) => [
          _metricsSlice(ref, (m) => [
                KpiCard(
                  label: 'Public / WhatsApp bookings',
                  value: qty(m.publicBookings.value),
                  icon: Icons.alt_route_outlined,
                  accent: chartPalette[4],
                ),
                KpiCard(
                  label: 'Total appointments',
                  value: qty(m.totalAppointments.value),
                  icon: Icons.event_note_outlined,
                ),
              ]),
          const SizedBox(height: 22),
          Consumer(builder: (context, ref, _) {
            final sources = ref.watch(bookingSourcesProvider(null));
            return ChartCard(
              title: 'Booking source split',
              subtitle: 'In-CRM bookings are those with no recorded source',
              height: 320,
              child: sources.when(
                loading: () => const LoadingState(),
                error: (e, _) => ErrorState(error: e, compact: true),
                data: (d) => DonutChart(items: d),
              ),
            );
          }),
        ],
      );
}

// ------------------------------------------------------- Platform analytics

class PlatformAnalyticsPage extends StatelessWidget {
  const PlatformAnalyticsPage({super.key});

  @override
  Widget build(BuildContext context) => _AnalyticsScaffold(
        title: 'Platform Analytics',
        subtitle: 'Overall growth and platform health',
        body: (context, ref) => [
          _metricsSlice(ref, (m) => [
                KpiCard(
                  label: 'Total Salons',
                  value: qty(m.totalSalons.value),
                  icon: Icons.storefront_outlined,
                ),
                KpiCard(
                  label: 'Active Salons',
                  value: qty(m.activeSalons.value),
                  icon: Icons.check_circle_outline,
                  accent: chartPalette[5],
                ),
                KpiCard(
                  label: 'Suspended Salons',
                  value: qty(m.suspendedSalons.value),
                  icon: Icons.block,
                  accent: chartPalette[3],
                ),
                KpiCard(
                  label: 'New Salons',
                  value: qty(m.newSalons.value),
                  icon: Icons.add_business_outlined,
                  delta: growth(m.newSalons.value, m.newSalons.previous ?? 0),
                  deltaUnavailable: growth(m.newSalons.value, m.newSalons.previous ?? 0) == null,
                ),
                KpiCard(
                  label: 'Total Transactions',
                  value: qty(m.completedAppointments.value),
                  icon: Icons.swap_horiz,
                  footnote: 'Completed appointments',
                ),
              ]),
          const SizedBox(height: 22),
          Consumer(builder: (context, ref, _) {
            final g = ref.watch(growthProvider);
            final trend = ref.watch(trendProvider(null));
            return _pair(
              context,
              ChartCard(
                title: 'New salon registrations',
                subtitle: 'Platform expansion over time',
                child: g.when(
                  loading: () => const LoadingState(),
                  error: (e, _) => ErrorState(error: e, compact: true),
                  data: (d) => TrendChart(points: d.primary, color: chartPalette[2]),
                ),
              ),
              ChartCard(
                title: 'Revenue trend',
                subtitle: 'Platform-wide settled revenue',
                child: trend.when(
                  loading: () => const LoadingState(),
                  error: (e, _) => ErrorState(error: e, compact: true),
                  data: (d) =>
                      TrendChart(points: d.primary, color: chartPalette[1], currency: true),
                ),
              ),
            );
          }),
          const SizedBox(height: 16),
          const _TopSalonsCard(),
        ],
      );
}

class _TopSalonsCard extends ConsumerWidget {
  const _TopSalonsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final top = ref.watch(topSalonsProvider);
    return ChartCard(
      title: 'Top-performing salons',
      subtitle: 'Ranked by settled revenue',
      height: 320,
      child: top.when(
        loading: () => const LoadingState(),
        error: (e, _) => ErrorState(error: e, compact: true),
        data: (rows) => RankedBars(
          currency: true,
          items: [
            for (final r in rows)
              NamedValue(r.salon.name, r.revenue,
                  subtitle: '${qty(r.bookings)} bookings · ${qty(r.customers)} clients'),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------ Owners / users

final ownersProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final db = ref.watch(firestoreProvider);
  // Bounded read: the console never streams the whole user table.
  final snap = await db.collection(Col.users).limit(200).get();
  return snap.docs.map((d) => {'uid': d.id, ...d.data()}).toList();
});

class OwnersPage extends ConsumerWidget {
  const OwnersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final owners = ref.watch(ownersProvider);
    final t = Theme.of(context);

    return PageBody(
      title: 'Owners & Users',
      subtitle: 'Accounts registered against the platform',
      actions: [
        OutlinedButton.icon(
          onPressed: () => ref.invalidate(ownersProvider),
          icon: const Icon(Icons.refresh, size: 17),
          label: const Text('Refresh'),
        ),
      ],
      child: Card(
        child: owners.when(
          loading: () => const LoadingState(height: 300),
          error: (e, _) => ErrorState(error: e, onRetry: () => ref.invalidate(ownersProvider)),
          data: (rows) => rows.isEmpty
              ? const EmptyState(icon: Icons.badge_outlined, title: 'No user profiles found')
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints:
                        BoxConstraints(minWidth: MediaQuery.sizeOf(context).width - 340),
                    child: DataTable(
                      headingTextStyle:
                          t.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
                      columns: const [
                        DataColumn(label: Text('Name')),
                        DataColumn(label: Text('Email')),
                        DataColumn(label: Text('Role')),
                        DataColumn(label: Text('UID')),
                      ],
                      rows: [
                        for (final u in rows)
                          DataRow(cells: [
                            DataCell(Text((u['displayName'] as String?)?.trim().isNotEmpty == true
                                ? u['displayName'] as String
                                : '—')),
                            DataCell(Text(u['email'] as String? ?? '—')),
                            DataCell(_RoleChip(role: u['role'] as String? ?? 'salon_owner')),
                            DataCell(Text(
                              u['uid'] as String,
                              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                            )),
                          ]),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  final String role;
  const _RoleChip({required this.role});

  @override
  Widget build(BuildContext context) {
    final isAdmin = role == 'super_admin';
    final color = isAdmin ? const Color(0xFF6D4AFF) : const Color(0xFF64748B);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isAdmin ? 'Super admin' : 'Salon owner',
        style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 11.5),
      ),
    );
  }
}
