import 'package:flutter/foundation.dart';

@immutable
class Kpi {
  final num value;
  final num? previous;
  const Kpi(this.value, {this.previous});
  static const zero = Kpi(0);
}

@immutable
class PlatformMetrics {
  final Kpi totalSalons;
  final Kpi activeSalons;
  final Kpi suspendedSalons;
  final Kpi newSalons;
  final Kpi totalCustomers;
  final Kpi newCustomers;
  final Kpi totalAppointments;
  final Kpi todaysAppointments;
  final Kpi completedAppointments;
  final Kpi cancelledAppointments;
  final Kpi totalRevenue;
  final Kpi todaysRevenue;
  final Kpi monthlyRevenue;
  final Kpi outstandingPayments;
  final Kpi totalStaff;
  final Kpi totalServices;
  final Kpi referralRevenue;
  final Kpi loyaltyRedemptions;
  final Kpi publicBookings;

  const PlatformMetrics({
    required this.totalSalons,
    required this.activeSalons,
    required this.suspendedSalons,
    required this.newSalons,
    required this.totalCustomers,
    required this.newCustomers,
    required this.totalAppointments,
    required this.todaysAppointments,
    required this.completedAppointments,
    required this.cancelledAppointments,
    required this.totalRevenue,
    required this.todaysRevenue,
    required this.monthlyRevenue,
    required this.outstandingPayments,
    required this.totalStaff,
    required this.totalServices,
    required this.referralRevenue,
    required this.loyaltyRedemptions,
    required this.publicBookings,
  });

  /// Cancellation rate across the selected window.
  double get cancellationRate => totalAppointments.value == 0
      ? 0
      : (cancelledAppointments.value / totalAppointments.value) * 100;
}

@immutable
class SeriesPoint {
  final String key;
  final String label;
  final num value;
  const SeriesPoint(this.key, this.label, this.value);
}

@immutable
class NamedValue {
  final String name;
  final num value;
  final String? subtitle;
  const NamedValue(this.name, this.value, {this.subtitle});
}
