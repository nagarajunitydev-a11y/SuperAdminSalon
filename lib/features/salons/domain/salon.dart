import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../../core/constants/collections.dart';

@immutable
class Salon {
  final String id;
  final String name;
  final String ownerEmail;
  final String? ownerId;
  final String phone;
  final String address;
  final String createdAt;

  /// The CRM predates this field entirely, so an ABSENT status means active.
  /// Never treat a missing value as suspended — that would lock out every
  /// salon created before the console existed.
  final String status;

  const Salon({
    required this.id,
    required this.name,
    required this.ownerEmail,
    required this.ownerId,
    required this.phone,
    required this.address,
    required this.createdAt,
    required this.status,
  });

  bool get isSuspended => status == SalonStatus.suspended;
  bool get isActive => !isSuspended;

  factory Salon.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const <String, dynamic>{};
    return Salon(
      id: doc.id,
      name: d['name'] as String? ?? 'Untitled salon',
      ownerEmail: d['ownerEmail'] as String? ?? '',
      ownerId: d['ownerId'] as String?,
      phone: d['phone'] as String? ?? '',
      address: d['address'] as String? ?? '',
      createdAt: d['createdAt'] as String? ?? '',
      status: d['status'] as String? ?? SalonStatus.active,
    );
  }
}

/// Per-salon rollup shown in the salon detail header.
@immutable
class SalonSummary {
  final int customers;
  final int staff;
  final int services;
  final int appointments;
  final int completed;
  final int cancelled;
  final double revenue;
  final double outstanding;
  final double avgBookingValue;
  final int repeatCustomers;
  final String? lastActivity;

  const SalonSummary({
    required this.customers,
    required this.staff,
    required this.services,
    required this.appointments,
    required this.completed,
    required this.cancelled,
    required this.revenue,
    required this.outstanding,
    required this.avgBookingValue,
    required this.repeatCustomers,
    required this.lastActivity,
  });

  double get cancellationRate =>
      appointments == 0 ? 0 : (cancelled / appointments) * 100;
}

/// One row of the leaderboard. Built from aggregation queries per salon, so it
/// is only ever computed for the page of salons actually on screen.
@immutable
class SalonPerformance {
  final Salon salon;
  final double revenue;
  final int bookings;
  final int customers;

  const SalonPerformance({
    required this.salon,
    required this.revenue,
    required this.bookings,
    required this.customers,
  });
}
