import 'package:flutter/material.dart';

/// Shared loading / empty / error presentation so every module reports the
/// same way. Analytics screens fail partially rather than blanking the page:
/// a card that could not load shows its own error while its neighbours render.

class LoadingState extends StatelessWidget {
  final double height;
  const LoadingState({super.key, this.height = 160});

  @override
  Widget build(BuildContext context) => SizedBox(
        height: height,
        child: const Center(
          child: SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        ),
      );
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  const EmptyState({
    super.key,
    this.icon = Icons.inbox_outlined,
    required this.title,
    this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 44, horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 38, color: t.colorScheme.outline),
          const SizedBox(height: 14),
          Text(title, style: t.textTheme.titleMedium, textAlign: TextAlign.center),
          if (message != null) ...[
            const SizedBox(height: 6),
            Text(
              message!,
              style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
          if (action != null) ...[const SizedBox(height: 18), action!],
        ],
      ),
    );
  }
}

class ErrorState extends StatelessWidget {
  final Object error;
  final VoidCallback? onRetry;
  final bool compact;

  const ErrorState({super.key, required this.error, this.onRetry, this.compact = false});

  /// Firestore's raw messages are unhelpful to an operator. The two failures
  /// that actually happen in this console get a plain-language explanation,
  /// because both are fixable by a human and neither is a bug.
  String get _message {
    final s = error.toString();
    if (s.contains('permission-denied')) {
      return 'Access denied. This account must have role "super_admin" in its '
          'users document, and the console security rules must be deployed.';
    }
    if (s.contains('failed-precondition') || s.contains('requires an index')) {
      return 'This query needs a Firestore index that has not been created yet. '
          'Deploy firestore.indexes.json, then retry.';
    }
    return s;
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: compact ? 20 : 40, horizontal: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, color: t.colorScheme.error, size: compact ? 26 : 34),
          const SizedBox(height: 10),
          Text(
            _message,
            textAlign: TextAlign.center,
            style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 17),
              label: const Text('Retry'),
            ),
          ],
        ],
      ),
    );
  }
}
