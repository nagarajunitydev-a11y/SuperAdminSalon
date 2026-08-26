import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/shell.dart';
import '../../../app/theme.dart';
import '../../../firebase_options.dart';
import '../../auth/data/auth_repository.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final admin = ref.watch(adminSessionProvider).value;
    final mode = ref.watch(themeModeProvider);
    final t = Theme.of(context);

    return PageBody(
      title: 'Settings',
      subtitle: 'Console preferences and session information',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.palette_outlined),
                  title: const Text('Appearance'),
                  subtitle: const Text('Light, dark, or follow the operating system'),
                  trailing: SegmentedButton<ThemeMode>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode_outlined)),
                      ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.computer_outlined)),
                      ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode_outlined)),
                    ],
                    selected: {mode},
                    onSelectionChanged: (s) =>
                        ref.read(themeModeProvider.notifier).setValue(s.first),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: const Text('Signed in as'),
                  subtitle: Text('${admin?.displayName ?? '—'} · ${admin?.email ?? ''}'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.verified_user_outlined),
                  title: const Text('Role'),
                  subtitle: Text(admin?.role ?? '—'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.fingerprint),
                  title: const Text('User ID'),
                  subtitle: Text(
                    admin?.uid ?? '—',
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12.5),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.dns_outlined),
                  title: const Text('Firebase project'),
                  subtitle: Text(DefaultFirebaseOptions.web.projectId),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.shield_outlined, size: 20, color: t.colorScheme.primary),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Security model',
                            style: t.textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 6),
                        Text(
                          'This console holds no privileged credential. It authenticates as a '
                          'normal Firebase user, and every read is authorised by Firestore '
                          'Security Rules against the super_admin role on your users document. '
                          'Route guards here are a convenience — removing them would not grant '
                          'access to any data. Suspend and reactivate actions are written to an '
                          'append-only audit log that no one can edit or delete.',
                          style: t.textTheme.bodySmall
                              ?.copyWith(color: t.colorScheme.onSurfaceVariant, height: 1.5),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () => ref.read(authRepositoryProvider).signOut(),
              icon: const Icon(Icons.logout, size: 17),
              label: const Text('Sign out'),
            ),
          ),
        ],
      ),
    );
  }
}
