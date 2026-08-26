import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/shell.dart';
import '../../../core/widgets/states.dart';
import '../data/audit_repository.dart';

final auditLogProvider = FutureProvider.autoDispose<List<AuditEntry>>(
  (ref) => ref.watch(auditRepositoryProvider).fetchRecent(limit: 200),
);

class AuditPage extends ConsumerWidget {
  const AuditPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logs = ref.watch(auditLogProvider);

    return PageBody(
      title: 'Audit Logs',
      subtitle: 'Append-only record of sensitive administrative actions',
      actions: [
        OutlinedButton.icon(
          onPressed: () => ref.invalidate(auditLogProvider),
          icon: const Icon(Icons.refresh, size: 17),
          label: const Text('Refresh'),
        ),
      ],
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: logs.when(
            loading: () => const LoadingState(height: 300),
            error: (e, _) => ErrorState(error: e, onRetry: () => ref.invalidate(auditLogProvider)),
            data: (rows) => rows.isEmpty
                ? const EmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'No administrative actions recorded',
                    message:
                        'Suspending or reactivating a salon writes an entry here. '
                        'Entries can never be edited or deleted.',
                  )
                : AuditList(entries: rows),
          ),
        ),
      ),
    );
  }
}

class AuditList extends StatelessWidget {
  final List<AuditEntry> entries;
  const AuditList({super.key, required this.entries});

  static const _icons = {
    'salon.suspend': Icons.block,
    'salon.reactivate': Icons.check_circle_outline,
  };

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: entries.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final e = entries[i];
        final suspend = e.action == 'salon.suspend';
        final color = suspend ? const Color(0xFFE5484D) : const Color(0xFF12A150);
        return ListTile(
          leading: CircleAvatar(
            radius: 17,
            backgroundColor: color.withValues(alpha: 0.13),
            child: Icon(_icons[e.action] ?? Icons.bolt, size: 17, color: color),
          ),
          title: Text(
            e.note ?? e.action,
            style: t.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            '${e.action} · by ${e.actorUid}',
            style: t.textTheme.labelSmall?.copyWith(
              color: t.colorScheme.onSurfaceVariant,
              fontFamily: 'monospace',
            ),
          ),
          trailing: Text(
            e.at.isEmpty ? '—' : e.at.replaceFirst('T', ' ').split('.').first,
            style: t.textTheme.labelSmall?.copyWith(color: t.colorScheme.onSurfaceVariant),
          ),
        );
      },
    );
  }
}
