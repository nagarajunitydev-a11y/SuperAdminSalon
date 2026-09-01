import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/collections.dart';
import '../../../core/utils/date_range.dart';
import '../../auth/data/auth_repository.dart';
import '../domain/platform_metrics.dart';

final metricsRepositoryProvider = Provider<MetricsRepository>(
  (ref) => MetricsRepository(ref.watch(firestoreProvider)),
);

/// Platform-wide analytics built on Firestore SERVER-SIDE aggregation.
///
/// Every number here comes back from `count()` / `sum()` / `average()`, which
/// execute in the backend and return a single scalar. No raw document is ever
/// downloaded to produce a KPI, so dashboard cost is independent of how many
/// appointments or customers exist.
///
/// Cross-salon reads use COLLECTION GROUP queries, authorized by the
/// `match /{path=**}/<col>/{id}` rules restricted to super admins.
class MetricsRepository {
  final FirebaseFirestore _db;
  MetricsRepository(this._db);

  Query<Map<String, dynamic>> _appointments({String? salonId}) => salonId == null
      ? _db.collectionGroup(Col.appointments)
      : _db.collection(Col.salons).doc(salonId).collection(Col.appointments);

  Query<Map<String, dynamic>> _customers({String? salonId}) => salonId == null
      ? _db.collectionGroup(Col.customers)
      : _db.collection(Col.salons).doc(salonId).collection(Col.customers);

  Query<Map<String, dynamic>> _inWindow(
    Query<Map<String, dynamic>> q,
    DateWindow w, {
    String field = 'date',
  }) =>
      q
          .where(field, isGreaterThanOrEqualTo: w.startKey)
          .where(field, isLessThanOrEqualTo: w.endKey);

  /// Bounds a query over a TIMESTAMP-stored date field (e.g.
  /// `customers.createdAt`) to the whole window, using genuine start-of-day /
  /// exclusive next-day Timestamp boundaries. String keys are invalid against a
  /// Timestamp field, so this never appends a lexicographic pad character.
  Query<Map<String, dynamic>> _inCreatedAtWindow(
    Query<Map<String, dynamic>> q,
    DateWindow w,
  ) =>
      q
          .where('createdAt', isGreaterThanOrEqualTo: startOfDayForKey(w.startKey))
          .where('createdAt', isLessThan: exclusiveEndOfDayForKey(w.endKey));

  Future<int> _count(Query<Map<String, dynamic>> q) async =>
      (await q.count().get()).count ?? 0;

  Future<double> _sum(Query<Map<String, dynamic>> q, String field) async =>
      ((await q.aggregate(sum(field)).get()).getSum(field) ?? 0).toDouble();

  /// Headline KPIs for a window, with the preceding window for growth arrows.
  Future<PlatformMetrics> loadPlatformMetrics(DateWindow w, {String? salonId}) async {
    final prev = w.previous;
    final todayKey = ymd.format(DateTime.now());
    final monthStart = DateFormat('yyyy-MM-01').format(DateTime.now());

    final appts = _appointments(salonId: salonId);
    final custs = _customers(salonId: salonId);
    final paidInWindow = _inWindow(appts, w).where('paid', isEqualTo: true);
    final salons = _db.collection(Col.salons);

    // All independent, so they are issued concurrently: the dashboard is one
    // round trip deep rather than nineteen.
    final results = await Future.wait<num>([
      salonId != null ? Future.value(1) : _count(salons),
      salonId != null
          ? Future.value(1)
          : _count(salons.where('status', isNotEqualTo: SalonStatus.suspended)),
      salonId != null
          ? Future.value(0)
          : _count(salons.where('status', isEqualTo: SalonStatus.suspended)),
      salonId != null
          ? Future.value(0)
          : _count(_inWindow(salons, w, field: 'createdAt')),
      _count(custs),
      _count(_inCreatedAtWindow(custs, w)),
      _count(_inWindow(appts, w)),
      _count(appts.where('date', isEqualTo: todayKey)),
      _count(_inWindow(appts, w).where('status', isEqualTo: ApptStatus.completed)),
      _count(_inWindow(appts, w).where('status', isEqualTo: ApptStatus.cancelled)),
      _sum(paidInWindow, 'invoiceAmount'),
      _sum(appts.where('date', isEqualTo: todayKey).where('paid', isEqualTo: true),
          'invoiceAmount'),
      _sum(
        appts
            .where('date', isGreaterThanOrEqualTo: monthStart)
            .where('date', isLessThanOrEqualTo: todayKey)
            .where('paid', isEqualTo: true),
        'invoiceAmount',
      ),
      _sum(
        _inWindow(appts, w)
            .where('status', isEqualTo: ApptStatus.completed)
            .where('paid', isEqualTo: false),
        'invoiceAmount',
      ),
      salonId != null
          ? _count(_db.collection(Col.salons).doc(salonId).collection(Col.staff))
          : _count(_db.collectionGroup(Col.staff)),
      salonId != null
          ? _count(_db.collection(Col.salons).doc(salonId).collection(Col.services))
          : _count(_db.collectionGroup(Col.services)),
      _sum(paidInWindow, 'walletRedeemed'),
      _count(
        _db
            .collection(Col.rewardTransactions)
            .where('type', isEqualTo: 'REDEMPTION')
            .where('createdAt', isGreaterThanOrEqualTo: w.startKey),
      ),
      _count(_inWindow(appts, w).where('source', whereIn: <String>[
        BookingSource.publicBooking,
        BookingSource.whatsapp,
      ])),
      // Previous-window baselines for growth.
      _count(_inWindow(appts, prev)),
      _sum(_inWindow(appts, prev).where('paid', isEqualTo: true), 'invoiceAmount'),
      _count(_inCreatedAtWindow(custs, prev)),
      salonId != null
          ? Future.value(0)
          : _count(_inWindow(salons, prev, field: 'createdAt')),
    ]);

    return PlatformMetrics(
      totalSalons: Kpi(results[0]),
      activeSalons: Kpi(results[1]),
      suspendedSalons: Kpi(results[2]),
      newSalons: Kpi(results[3], previous: results[22]),
      totalCustomers: Kpi(results[4]),
      newCustomers: Kpi(results[5], previous: results[21]),
      totalAppointments: Kpi(results[6], previous: results[19]),
      todaysAppointments: Kpi(results[7]),
      completedAppointments: Kpi(results[8]),
      cancelledAppointments: Kpi(results[9]),
      totalRevenue: Kpi(results[10], previous: results[20]),
      todaysRevenue: Kpi(results[11]),
      monthlyRevenue: Kpi(results[12]),
      outstandingPayments: Kpi(results[13]),
      totalStaff: Kpi(results[14]),
      totalServices: Kpi(results[15]),
      referralRevenue: Kpi(results[16]),
      loyaltyRedemptions: Kpi(results[17]),
      publicBookings: Kpi(results[18]),
    );
  }

  /// Bucket a window into at most ~30 points so a long range never fans out
  /// into hundreds of queries. Short ranges stay daily; longer ones roll up.
  List<TimeBucket> _buckets(DateWindow w) {
    final out = <TimeBucket>[];
    if (w.days <= 14) {
      for (final key in w.dayKeys) {
        final d = DateTime.parse(key);
        out.add(TimeBucket(DateFormat('d MMM').format(d), key, key));
      }
      return out;
    }
    final bucketDays = (w.days / 26).ceil();
    var cursor = w.start;
    while (!cursor.isAfter(w.end)) {
      final end = cursor.add(Duration(days: bucketDays - 1));
      final clamped = end.isAfter(w.end) ? w.end : end;
      out.add(TimeBucket(
        DateFormat('d MMM').format(cursor),
        ymd.format(cursor),
        ymd.format(clamped),
      ));
      cursor = clamped.add(const Duration(days: 1));
    }
    return out;
  }

  /// Revenue and booking trend. One aggregation per bucket, run concurrently;
  /// still zero raw documents transferred.
  Future<TrendData> loadTrend(DateWindow w, {String? salonId}) async {
    final buckets = _buckets(w);
    final appts = _appointments(salonId: salonId);

    final revenue = await Future.wait(buckets.map((b) async {
      final q = appts
          .where('date', isGreaterThanOrEqualTo: b.start)
          .where('date', isLessThanOrEqualTo: b.end)
          .where('paid', isEqualTo: true);
      return SeriesPoint(b.start, b.label, await _sum(q, 'invoiceAmount'));
    }));

    final bookings = await Future.wait(buckets.map((b) async {
      final q = appts
          .where('date', isGreaterThanOrEqualTo: b.start)
          .where('date', isLessThanOrEqualTo: b.end);
      return SeriesPoint(b.start, b.label, await _count(q));
    }));

    return TrendData(revenue, bookings);
  }

  /// New-salon and new-customer registrations over time.
  ///
  /// `salons.createdAt` is a full ISO-8601 STRING, so its upper bound is padded
  /// with a char above every timestamp glyph to catch the whole final day via
  /// lexical comparison. `customers.createdAt` is stored as a Firestore
  /// TIMESTAMP, so its range uses real start-of-day / exclusive next-day
  /// Timestamp bounds — never a padded string.
  Future<TrendData> loadGrowth(DateWindow w) async {
    final buckets = _buckets(w);

    final salons = await Future.wait(buckets.map((b) async {
      final q = _db
          .collection(Col.salons)
          .where('createdAt', isGreaterThanOrEqualTo: b.start)
          .where('createdAt', isLessThan: '${b.end}');
      return SeriesPoint(b.start, b.label, await _count(q));
    }));

    final customers = await Future.wait(buckets.map((b) async {
      final q = _db
          .collectionGroup(Col.customers)
          .where('createdAt', isGreaterThanOrEqualTo: startOfDayForKey(b.start))
          .where('createdAt', isLessThan: exclusiveEndOfDayForKey(b.end));
      return SeriesPoint(b.start, b.label, await _count(q));
    }));

    return TrendData(salons, customers);
  }

  /// Booking-source split. The CRM omits `source` for in-CRM bookings, so the
  /// in-CRM slice is derived by subtraction — Firestore cannot query for
  /// "field is absent".
  Future<List<NamedValue>> loadBookingSources(DateWindow w, {String? salonId}) async {
    final appts = _appointments(salonId: salonId);
    final total = await _count(_inWindow(appts, w));
    final counts = await Future.wait([
      _count(_inWindow(appts, w).where('source', isEqualTo: BookingSource.publicBooking)),
      _count(_inWindow(appts, w).where('source', isEqualTo: BookingSource.whatsapp)),
    ]);
    final inCrm = (total - counts[0] - counts[1]).clamp(0, total);
    return [
      NamedValue('In-CRM', inCrm),
      NamedValue('Public booking', counts[0]),
      NamedValue('WhatsApp', counts[1]),
    ];
  }

  /// Referral funnel by status.
  Future<List<NamedValue>> loadReferralPerformance({String? salonId}) async {
    final base = salonId == null
        ? _db.collectionGroup(Col.referrals)
        : _db.collection(Col.salons).doc(salonId).collection(Col.referrals);
    final counts = await Future.wait(
      ReferralStatus.all.map((s) => _count(base.where('status', isEqualTo: s))),
    );
    return [
      for (var i = 0; i < ReferralStatus.all.length; i++)
        NamedValue(ReferralStatus.all[i], counts[i]),
    ];
  }

  /// Appointment status breakdown for the window.
  Future<List<NamedValue>> loadStatusBreakdown(DateWindow w, {String? salonId}) async {
    final appts = _appointments(salonId: salonId);
    final counts = await Future.wait(
      ApptStatus.all.map((s) => _count(_inWindow(appts, w).where('status', isEqualTo: s))),
    );
    return [
      for (var i = 0; i < ApptStatus.all.length; i++) NamedValue(ApptStatus.all[i], counts[i]),
    ];
  }
}

class TimeBucket {
  final String label;
  final String start;
  final String end;
  const TimeBucket(this.label, this.start, this.end);
}

class TrendData {
  final List<SeriesPoint> primary;
  final List<SeriesPoint> secondary;
  const TrendData(this.primary, this.secondary);
}
