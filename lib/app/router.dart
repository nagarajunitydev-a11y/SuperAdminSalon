import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/analytics/presentation/analytics_pages.dart';
import '../features/audit/presentation/audit_page.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/auth/presentation/login_page.dart';
import '../features/dashboard/presentation/dashboard_page.dart';
import '../features/salons/presentation/salon_detail_page.dart';
import '../features/salons/presentation/salons_page.dart';
import '../features/settings/presentation/settings_page.dart';
import 'shell.dart';

class Routes {
  const Routes._();
  static const login = '/login';
  static const dashboard = '/';
  static const salons = '/salons';
  static const owners = '/owners';
  static const customers = '/customers';
  static const appointments = '/appointments';
  static const revenue = '/revenue';
  static const services = '/services';
  static const staff = '/staff';
  static const referrals = '/referrals';
  static const sources = '/sources';
  static const platform = '/platform';
  static const audit = '/audit';
  static const settings = '/settings';
}

/// Bridges a Riverpod provider into GoRouter's `refreshListenable`, so the
/// redirect re-evaluates the moment the session changes.
class _AuthNotifier extends ChangeNotifier {
  _AuthNotifier(Ref ref) {
    ref.listen(adminSessionProvider, (_, _) => notifyListeners());
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = _AuthNotifier(ref);
  ref.onDispose(notifier.dispose);

  return GoRouter(
    initialLocation: Routes.dashboard,
    refreshListenable: notifier,

    /// EVERY route except /login is protected here. `adminSessionProvider`
    /// yields non-null only for a signed-in user whose Firestore profile
    /// carries role == 'super_admin', so a signed-in salon owner is redirected
    /// exactly like a signed-out visitor. This is a convenience layer, not the
    /// security boundary — Security Rules independently refuse the data.
    redirect: (context, state) {
      final session = ref.read(adminSessionProvider);
      final loggingIn = state.matchedLocation == Routes.login;

      // Hold position until the first role read resolves, so a refresh does
      // not flash the login screen for an already-authorised admin.
      if (session.isLoading) return null;

      final isAdmin = session.value != null;
      if (!isAdmin) return loggingIn ? null : Routes.login;
      if (loggingIn) return Routes.dashboard;
      return null;
    },
    routes: [
      GoRoute(path: Routes.login, builder: (_, _) => const LoginPage()),
      ShellRoute(
        builder: (_, _, child) => AdminShell(child: child),
        routes: [
          GoRoute(path: Routes.dashboard, builder: (_, _) => const DashboardPage()),
          GoRoute(
            path: Routes.salons,
            builder: (_, _) => const SalonsPage(),
            routes: [
              GoRoute(
                path: ':id',
                builder: (_, s) => SalonDetailPage(salonId: s.pathParameters['id']!),
              ),
            ],
          ),
          GoRoute(path: Routes.owners, builder: (_, _) => const OwnersPage()),
          GoRoute(path: Routes.customers, builder: (_, _) => const CustomersAnalyticsPage()),
          GoRoute(
              path: Routes.appointments,
              builder: (_, _) => const AppointmentsAnalyticsPage()),
          GoRoute(path: Routes.revenue, builder: (_, _) => const RevenuePage()),
          GoRoute(path: Routes.services, builder: (_, _) => const ServicesAnalyticsPage()),
          GoRoute(path: Routes.staff, builder: (_, _) => const StaffAnalyticsPage()),
          GoRoute(path: Routes.referrals, builder: (_, _) => const ReferralsPage()),
          GoRoute(path: Routes.sources, builder: (_, _) => const BookingSourcesPage()),
          GoRoute(path: Routes.platform, builder: (_, _) => const PlatformAnalyticsPage()),
          GoRoute(path: Routes.audit, builder: (_, _) => const AuditPage()),
          GoRoute(path: Routes.settings, builder: (_, _) => const SettingsPage()),
        ],
      ),
    ],
  );
});
