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
import '../../audit/data/audit_repository.dart';
import '../../audit/presentation/audit_page.dart';
import '../../auth/data/auth_repository.dart';
import '../../dashboard/presentation/dashboard_controller.dart';
import '../data/salon_repository.dart';
import '../domain/salon.dart';
import 'salons_controller.dart';
import 'salons_page.dart';

final salonAuditProvider =
    FutureProvider.autoDispose.family<List<AuditEntry>, String>((ref, id) =>
        ref.watch(auditRepositoryProvider).fetchRecent(limit: 25, salonId: id));

class SalonDetailPage extends ConsumerWidget {
  final String salonId;
  const SalonDetailPage({super.key, required this.salonId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final salonAsync = ref.watch(salonProvider(salonId));
    final window = ref.watch(dateWindowProvider);

    return salonAsync.when(
      loading: () => const Center(child: LoadingState(height: 400)),
      error: (e, _) => Center(child: ErrorState(error: e)),
      data: (salon) {
        if (salon == null) {
          return const Center(
            child: EmptyState(
              icon: Icons.search_off,
              title: 'Salon not found',
              message: 'It may have been removed from the platform.',
            ),
          );
        }
        return PageBody(
          title: salon.name,
          subtitle: '${salon.address.isEmpty ? 'No address on file' : salon.address}'
              ' · ${window.label}',
          actions: [
            TextButton.icon(
              onPressed: () => context.go(Routes.salons),
              icon: const Icon(Icons.arrow_back, size: 17),
              label: const Text('All salons'),
            ),
            const SizedBox(width: 8),
            _StatusAction(salon: salon),
          ],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _OwnerCard(salon: salon),
              const SizedBox(height: 18),
              _SummaryKpis(salonId: salonId),
              const SizedBox(height: 20),
              _PerformanceCharts(salonId: salonId),
              const SizedBox(height: 16),
              _ActivityCard(salonId: salonId),
            ],
          ),
        );
      },
    );
  }
}

class _OwnerCard extends StatelessWidget {
  final Salon salon;
  const _OwnerCard({required this.salon});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Wrap(
          spacing: 44,
          runSpacing: 16,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _Field(label: 'Status', child: StatusChip(suspended: salon.isSuspended)),
            _Field(label: 'Owner email', value: salon.ownerEmail.isEmpty ? '—' : salon.ownerEmail),
            _Field(label: 'Owner UID', value: salon.ownerId ?? '—', mono: true),
            _Field(label: 'Phone', value: salon.phone.isEmpty ? '—' : salon.phone),
            _Field(
              label: 'Registered',
              value: salon.createdAt.isEmpty ? '—' : salon.createdAt.split('T').first,
            ),
            _Field(label: 'Salon ID', value: salon.id, mono: true),
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final String? value;
  final Widget? child;
  final bool mono;
  const _Field({required this.label, this.value, this.child, this.mono = false});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(),
            style: t.textTheme.labelSmall?.copyWith(
              color: t.colorScheme.onSurfaceVariant,
              letterSpacing: 0.6,
              fontWeight: FontWeight.w700,
            )),
        const SizedBox(height: 5),
        child ??
            Text(
              value ?? '—',
              style: t.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                fontFamily: mono ? 'monospace' : null,
                fontSize: mono ? 12.5 : null,
              ),
            ),
      ],
    );
  }
}

/// Suspend / reactivate, always behind an explicit confirmation. The action is
/// recorded in the audit trail by the repository, never here, so it cannot be
/// bypassed by calling the repository from somewhere else.
class _StatusAction extends ConsumerStatefulWidget {
  final Salon salon;
  const _StatusAction({required this.salon});

  @override
  ConsumerState<_StatusAction> createState() => _StatusActionState();
}

class _StatusActionState extends ConsumerState<_StatusAction> {
  bool _busy = false;

  Future<void> _toggle() async {
    final salon = widget.salon;
    final suspend = salon.isActive;
    final admin = ref.read(adminSessionProvider).value;
    if (admin == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(suspend ? 'Suspend this salon?' : 'Reactivate this salon?'),
        content: Text(
          suspend
              ? 'Access for ${salon.name} will be marked suspended and the action '
                  'recorded in the audit log. Business data is never deleted.'
              : 'Access for ${salon.name} will be restored and the action recorded '
                  'in the audit log.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(suspend ? 'Suspend' : 'Reactivate'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      await ref.read(salonRepositoryProvider).setStatus(
            salon: salon,
            suspend: suspend,
            actorUid: admin.uid,
          );
      ref.invalidate(salonAuditProvider(salon.id));
      ref.invalidate(auditLogProvider);
      ref.read(salonListProvider.notifier).refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(suspend ? 'Salon suspended.' : 'Salon reactivated.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update status: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final suspend = widget.salon.isActive;
    return FilledButton.tonalIcon(
      onPressed: _busy ? null : _toggle,
      icon: _busy
          ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2))
          : Icon(suspend ? Icons.block : Icons.check_circle_outline, size: 17),
      label: Text(suspend ? 'Suspend' : 'Reactivate'),
    );
  }
}

class _SummaryKpis extends ConsumerWidget {
  final String salonId;
  const _SummaryKpis({required this.salonId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(salonSummaryProvider(salonId));
    return summary.when(
      loading: () => const LoadingState(height: 260),
      error: (e, _) =>
          ErrorState(error: e, onRetry: () => ref.invalidate(salonSummaryProvider(salonId))),
      data: (s) => KpiGrid(
        children: [
          KpiCard(
            label: 'Revenue',
            value: money(s.revenue),
            icon: Icons.account_balance_wallet_outlined,
            accent: chartPalette[1],
          ),
          KpiCard(
            label: 'Avg booking value',
            value: money(s.avgBookingValue),
            icon: Icons.receipt_long_outlined,
            accent: chartPalette[1],
          ),
          KpiCard(
            label: 'Outstanding',
            value: money(s.outstanding),
            icon: Icons.pending_actions_outlined,
            accent: chartPalette[3],
          ),
          KpiCard(label: 'Bookings', value: qty(s.appointments), icon: Icons.event_note_outlined),
          KpiCard(
            label: 'Completed',
            value: qty(s.completed),
            icon: Icons.check_circle_outline,
            accent: chartPalette[5],
          ),
          KpiCard(
            label: 'Cancellation rate',
            value: percent(s.cancellationRate),
            icon: Icons.cancel_outlined,
            accent: chartPalette[3],
            footnote: '${qty(s.cancelled)} cancelled',
          ),
          KpiCard(
            label: 'Customers',
            value: qty(s.customers),
            icon: Icons.groups_outlined,
            accent: chartPalette[4],
          ),
          KpiCard(
            label: 'Referred customers',
            value: qty(s.repeatCustomers),
            icon: Icons.repeat,
            accent: chartPalette[4],
          ),
          KpiCard(label: 'Staff', value: qty(s.staff), icon: Icons.engineering_outlined),
          KpiCard(
              label: 'Services', value: qty(s.services), icon: Icons.design_services_outlined),
          KpiCard(
            label: 'Last activity',
            value: s.lastActivity ?? '—',
            icon: Icons.history,
            footnote: 'Most recent booking date',
          ),
        ],
      ),
    );
  }
}

class _PerformanceCharts extends ConsumerWidget {
  final String salonId;
  const _PerformanceCharts({required this.salonId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trend = ref.watch(trendProvider(salonId));
    final sources = ref.watch(bookingSourcesProvider(salonId));
    final statuses = ref.watch(statusBreakdownProvider(salonId));

    Widget card(String title, String sub, AsyncValue<dynamic> v, Widget Function(dynamic) b) =>
        ChartCard(
          title: title,
          subtitle: sub,
          child: v.when(
            loading: () => const LoadingState(),
            error: (e, _) => ErrorState(error: e, compact: true),
            data: (d) => b(d),
          ),
        );

    return LayoutBuilder(builder: (context, c) {
      final wide = c.maxWidth >= 900;
      final children = [
        card('Revenue', 'Settled invoices over time', trend,
            (d) => TrendChart(points: d.primary, color: chartPalette[1], currency: true)),
        card('Bookings', 'Appointments over time', trend,
            (d) => TrendChart(points: d.secondary, color: chartPalette[0])),
        card('Booking source', 'Where this salon gets bookings', sources,
            (d) => DonutChart(items: d)),
        card('Appointment status', 'Lifecycle breakdown', statuses,
            (d) => RankedBars(items: d)),
      ];
      if (!wide) {
        return Column(
          children: [
            for (final w in children) Padding(padding: const EdgeInsets.only(bottom: 16), child: w),
          ],
        );
      }
      return Column(
        children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: children[0]),
            const SizedBox(width: 16),
            Expanded(child: children[1]),
          ]),
          const SizedBox(height: 16),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: children[2]),
            const SizedBox(width: 16),
            Expanded(child: children[3]),
          ]),
        ],
      );
    });
  }
}

class _ActivityCard extends ConsumerWidget {
  final String salonId;
  const _ActivityCard({required this.salonId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logs = ref.watch(salonAuditProvider(salonId));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Activity history',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
              'Administrative actions taken on this salon',
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            logs.when(
              loading: () => const LoadingState(height: 110),
              error: (e, _) => ErrorState(error: e, compact: true),
              data: (rows) => rows.isEmpty
                  ? const EmptyState(
                      icon: Icons.history_toggle_off,
                      title: 'No administrative actions yet',
                      message: 'Suspending or reactivating this salon will appear here.',
                    )
                  : AuditList(entries: rows),
            ),
          ],
        ),
      ),
    );
  }
}
