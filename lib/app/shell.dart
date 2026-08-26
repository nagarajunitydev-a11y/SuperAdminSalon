import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/widgets/date_range_picker.dart';
import '../features/auth/data/auth_repository.dart';
import 'router.dart';
import 'theme.dart';

class NavItem {
  final String label;
  final IconData icon;
  final String path;
  const NavItem(this.label, this.icon, this.path);
}

const navItems = <NavItem>[
  NavItem('Dashboard', Icons.space_dashboard_outlined, Routes.dashboard),
  NavItem('Salons', Icons.storefront_outlined, Routes.salons),
  NavItem('Owners & Users', Icons.badge_outlined, Routes.owners),
  NavItem('Customers', Icons.groups_outlined, Routes.customers),
  NavItem('Appointments', Icons.event_note_outlined, Routes.appointments),
  NavItem('Revenue & Payments', Icons.payments_outlined, Routes.revenue),
  NavItem('Services', Icons.design_services_outlined, Routes.services),
  NavItem('Staff', Icons.engineering_outlined, Routes.staff),
  NavItem('Referrals & Loyalty', Icons.card_giftcard_outlined, Routes.referrals),
  NavItem('Booking Sources', Icons.alt_route_outlined, Routes.sources),
  NavItem('Platform Analytics', Icons.insights_outlined, Routes.platform),
  NavItem('Audit Logs', Icons.receipt_long_outlined, Routes.audit),
  NavItem('Settings', Icons.settings_outlined, Routes.settings),
];

/// Enterprise shell: persistent sidebar on wide screens, a drawer below
/// 1100px, and a top bar that carries the global date window.
class AdminShell extends ConsumerWidget {
  final Widget child;
  const AdminShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wide = MediaQuery.sizeOf(context).width >= 1100;
    final location = GoRouterState.of(context).uri.path;

    return Scaffold(
      drawer: wide ? null : Drawer(child: _Sidebar(location: location, inDrawer: true)),
      appBar: _TopBar(showMenu: !wide),
      body: Row(
        children: [
          if (wide)
            SizedBox(width: 246, child: _Sidebar(location: location, inDrawer: false)),
          if (wide) const VerticalDivider(width: 1),
          Expanded(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1500),
                child: child,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends ConsumerWidget implements PreferredSizeWidget {
  final bool showMenu;
  const _TopBar({required this.showMenu});

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context);
    final admin = ref.watch(adminSessionProvider).value;
    final mode = ref.watch(themeModeProvider);
    final isDark = mode == ThemeMode.dark ||
        (mode == ThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.dark);

    return AppBar(
      automaticallyImplyLeading: showMenu,
      scrolledUnderElevation: 0,
      backgroundColor: t.cardTheme.color,
      shape: Border(bottom: BorderSide(color: t.colorScheme.outlineVariant)),
      titleSpacing: showMenu ? 0 : 24,
      title: Row(
        children: [
          if (!showMenu) const _Brand(),
          const Spacer(),
          const DateRangeSelector(),
          const SizedBox(width: 8),
          IconButton(
            tooltip: isDark ? 'Switch to light mode' : 'Switch to dark mode',
            onPressed: () => ref
                .read(themeModeProvider.notifier)
                .setValue(isDark ? ThemeMode.light : ThemeMode.dark),
            icon: Icon(isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined, size: 20),
          ),
          const SizedBox(width: 4),
          PopupMenuButton<String>(
            tooltip: 'Account',
            position: PopupMenuPosition.under,
            onSelected: (v) async {
              if (v == 'signout') {
                await ref.read(authRepositoryProvider).signOut();
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                enabled: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(admin?.displayName ?? '—',
                        style: t.textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600)),
                    Text(admin?.email ?? '',
                        style: t.textTheme.labelSmall
                            ?.copyWith(color: t.colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'signout',
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.logout, size: 19),
                  title: Text('Sign out'),
                ),
              ),
            ],
            child: Padding(
              padding: const EdgeInsets.only(right: 20, left: 4),
              child: CircleAvatar(
                radius: 16,
                backgroundColor: t.colorScheme.primaryContainer,
                child: Text(
                  (admin?.displayName ?? '?').characters.first.toUpperCase(),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: t.colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: t.colorScheme.primary,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(Icons.shield_moon_outlined, size: 18, color: t.colorScheme.onPrimary),
        ),
        const SizedBox(width: 11),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Qvrix Luxe',
                style: t.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
            Text('Super Admin',
                style: t.textTheme.labelSmall
                    ?.copyWith(color: t.colorScheme.onSurfaceVariant, height: 1.1)),
          ],
        ),
      ],
    );
  }
}

class _Sidebar extends StatelessWidget {
  final String location;
  final bool inDrawer;
  const _Sidebar({required this.location, required this.inDrawer});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Container(
      color: t.cardTheme.color,
      child: Column(
        children: [
          if (inDrawer)
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 26, 20, 14),
              child: Align(alignment: Alignment.centerLeft, child: _Brand()),
            ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              children: [
                for (final item in navItems)
                  _NavTile(
                    item: item,
                    // A detail route keeps its parent section highlighted.
                    selected: location == item.path ||
                        (item.path != Routes.dashboard && location.startsWith('${item.path}/')),
                    onTap: () {
                      if (inDrawer) Navigator.of(context).pop();
                      context.go(item.path);
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  final NavItem item;
  final bool selected;
  final VoidCallback onTap;
  const _NavTile({required this.item, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Material(
        color: selected ? t.colorScheme.primary.withValues(alpha: 0.11) : Colors.transparent,
        borderRadius: BorderRadius.circular(9),
        child: InkWell(
          borderRadius: BorderRadius.circular(9),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(
                  item.icon,
                  size: 18,
                  color: selected ? t.colorScheme.primary : t.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.label,
                    style: t.textTheme.bodySmall?.copyWith(
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected ? t.colorScheme.primary : t.colorScheme.onSurface,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Standard page scaffold: title, optional actions, scrolling body.
class PageBody extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final Widget child;

  const PageBody({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: 12,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title,
                      style: t.textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(
                        subtitle!,
                        style: t.textTheme.bodySmall
                            ?.copyWith(color: t.colorScheme.onSurfaceVariant),
                      ),
                    ),
                ],
              ),
              if (actions.isNotEmpty) Row(mainAxisSize: MainAxisSize.min, children: actions),
            ],
          ),
          const SizedBox(height: 22),
          child,
        ],
      ),
    );
  }
}
