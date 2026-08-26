import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/shell.dart';
import '../../../core/constants/collections.dart';
import '../../../core/widgets/states.dart';
import '../domain/salon.dart';
import 'salons_controller.dart';

class SalonsPage extends ConsumerStatefulWidget {
  const SalonsPage({super.key});

  @override
  ConsumerState<SalonsPage> createState() => _SalonsPageState();
}

class _SalonsPageState extends ConsumerState<SalonsPage> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  /// Debounced so typing does not fire a query per keystroke.
  void _onSearch(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      ref.read(salonListProvider.notifier).setSearch(v);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(salonListProvider);
    final notifier = ref.read(salonListProvider.notifier);

    return PageBody(
      title: 'Salons',
      subtitle: 'Every salon registered on the platform',
      actions: [
        OutlinedButton.icon(
          onPressed: notifier.refresh,
          icon: const Icon(Icons.refresh, size: 17),
          label: const Text('Refresh'),
        ),
      ],
      child: Card(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 300,
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: _onSearch,
                      decoration: InputDecoration(
                        hintText: 'Search by salon name…',
                        prefixIcon: const Icon(Icons.search, size: 19),
                        suffixIcon: _searchCtrl.text.isEmpty
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.close, size: 17),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  notifier.setSearch('');
                                },
                              ),
                      ),
                    ),
                  ),
                  SegmentedButton<String>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(value: 'all', label: Text('All')),
                      ButtonSegment(value: SalonStatus.active, label: Text('Active')),
                      ButtonSegment(value: SalonStatus.suspended, label: Text('Suspended')),
                    ],
                    selected: {state.status ?? 'all'},
                    onSelectionChanged: (s) =>
                        notifier.setStatus(s.first == 'all' ? null : s.first),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            if (state.error != null)
              ErrorState(error: state.error!, onRetry: notifier.refresh)
            else if (state.loading)
              const LoadingState(height: 260)
            else if (state.items.isEmpty)
              EmptyState(
                icon: Icons.storefront_outlined,
                title: state.search.isEmpty ? 'No salons yet' : 'No salons match that search',
                message: state.search.isEmpty
                    ? 'Salons appear here as owners register them in the CRM.'
                    : 'Search matches the start of a salon name.',
              )
            else
              _SalonTable(items: state.items),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text('Page ${state.page}',
                      style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(width: 14),
                  IconButton(
                    tooltip: 'Previous page',
                    onPressed: state.page > 1 && !state.loading ? notifier.previous : null,
                    icon: const Icon(Icons.chevron_left),
                  ),
                  IconButton(
                    tooltip: 'Next page',
                    onPressed: state.hasMore && !state.loading ? notifier.next : null,
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SalonTable extends StatelessWidget {
  final List<Salon> items;
  const _SalonTable({required this.items});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: BoxConstraints(minWidth: MediaQuery.sizeOf(context).width - 340),
        child: DataTable(
          headingTextStyle: t.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
          columnSpacing: 30,
          columns: const [
            DataColumn(label: Text('Salon')),
            DataColumn(label: Text('Owner')),
            DataColumn(label: Text('Contact')),
            DataColumn(label: Text('Registered')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('')),
          ],
          rows: [
            for (final s in items)
              DataRow(
                onSelectChanged: (_) => context.go('${Routes.salons}/${s.id}'),
                cells: [
                  DataCell(
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.name,
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                        if (s.address.isNotEmpty)
                          Text(
                            s.address,
                            style: t.textTheme.labelSmall
                                ?.copyWith(color: t.colorScheme.onSurfaceVariant),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  DataCell(Text(s.ownerEmail.isEmpty ? '—' : s.ownerEmail)),
                  DataCell(Text(s.phone.isEmpty ? '—' : s.phone)),
                  DataCell(Text(s.createdAt.isEmpty
                      ? '—'
                      : s.createdAt.split('T').first)),
                  DataCell(StatusChip(suspended: s.isSuspended)),
                  const DataCell(Icon(Icons.chevron_right, size: 18)),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class StatusChip extends StatelessWidget {
  final bool suspended;
  const StatusChip({super.key, required this.suspended});

  @override
  Widget build(BuildContext context) {
    final color = suspended ? const Color(0xFFE5484D) : const Color(0xFF12A150);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        suspended ? 'Suspended' : 'Active',
        style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 11.5),
      ),
    );
  }
}
