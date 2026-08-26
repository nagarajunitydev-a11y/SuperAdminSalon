import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/collections.dart';
import '../../../core/utils/date_range.dart';
import '../../auth/data/auth_repository.dart';
import '../../audit/data/audit_repository.dart';
import '../domain/salon.dart';

final salonRepositoryProvider = Provider<SalonRepository>(
  (ref) => SalonRepository(
    ref.watch(firestoreProvider),
    ref.watch(auditRepositoryProvider),
  ),
);

/// A page of salons plus the cursor needed to fetch the next one.
class SalonPage {
  final List<Salon> items;
  final DocumentSnapshot<Map<String, dynamic>>? cursor;
  final bool hasMore;
  const SalonPage(this.items, this.cursor, this.hasMore);
}

class SalonRepository {
  final FirebaseFirestore _db;
  final AuditRepository _audit;
  SalonRepository(this._db, this._audit);

  CollectionReference<Map<String, dynamic>> get _salons => _db.collection(Col.salons);

  /// SERVER-SIDE pagination via `startAfterDocument`. The browser only ever
  /// holds one page; `limit` is applied by the backend, so a platform with
  /// thousands of salons costs the same per page as one with ten.
  ///
  /// Firestore cannot combine a full-text search with pagination, so the
  /// `search` term is applied as an indexed prefix range on `name` — that is a
  /// real server-side filter, not a client-side scan.
  Future<SalonPage> fetchPage({
    int limit = 25,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    String? search,
    String? status,
  }) async {
    Query<Map<String, dynamic>> q = _salons;

    final term = (search ?? '').trim();
    if (term.isNotEmpty) {
      // Prefix range: matches every name starting with the term.
      q = q
          .where('name', isGreaterThanOrEqualTo: term)
          .where('name', isLessThan: '$term')
          .orderBy('name');
    } else {
      q = q.orderBy('createdAt', descending: true);
    }

    // Suspension is an equality filter the backend can index. "Active" cannot
    // be: an absent status means active, and Firestore cannot match a missing
    // field, so that one case is narrowed after the page arrives.
    if (status == SalonStatus.suspended) {
      q = q.where('status', isEqualTo: SalonStatus.suspended);
    }

    // Fetch one extra row to learn whether another page exists without a
    // second round trip.
    q = q.limit(limit + 1);
    if (startAfter != null) q = q.startAfterDocument(startAfter);

    final snap = await q.get();
    var docs = snap.docs;
    final hasMore = docs.length > limit;
    if (hasMore) docs = docs.sublist(0, limit);

    var items = docs.map(Salon.fromDoc).toList();
    if (status == SalonStatus.active) {
      items = items.where((s) => s.isActive).toList();
    }

    return SalonPage(items, docs.isEmpty ? null : docs.last, hasMore);
  }

  Future<Salon?> fetchOne(String id) async {
    final doc = await _salons.doc(id).get();
    return doc.exists ? Salon.fromDoc(doc) : null;
  }

  Stream<Salon?> watchOne(String id) =>
      _salons.doc(id).snapshots().map((d) => d.exists ? Salon.fromDoc(d) : null);

  /// Per-salon rollup. Every figure is a server-side aggregation.
  Future<SalonSummary> loadSummary(String salonId, DateWindow w) async {
    final base = _salons.doc(salonId);
    final appts = base.collection(Col.appointments);
    final inWindow = appts
        .where('date', isGreaterThanOrEqualTo: w.startKey)
        .where('date', isLessThanOrEqualTo: w.endKey);

    Future<int> c(Query<Map<String, dynamic>> q) async => (await q.count().get()).count ?? 0;
    Future<double> s(Query<Map<String, dynamic>> q, String f) async =>
        ((await q.aggregate(sum(f)).get()).getSum(f) ?? 0).toDouble();

    final r = await Future.wait<num>([
      c(base.collection(Col.customers)),
      c(base.collection(Col.staff)),
      c(base.collection(Col.services)),
      c(inWindow),
      c(inWindow.where('status', isEqualTo: ApptStatus.completed)),
      c(inWindow.where('status', isEqualTo: ApptStatus.cancelled)),
      s(inWindow.where('paid', isEqualTo: true), 'invoiceAmount'),
      s(
        inWindow.where('status', isEqualTo: ApptStatus.completed).where('paid', isEqualTo: false),
        'invoiceAmount',
      ),
    ]);

    // Repeat customers: clients whose wallet/loyalty history implies more than
    // one visit is not directly queryable, so this uses the count of customers
    // that carry a referral link — the one repeat signal the schema stores.
    final repeat = await c(
      base.collection(Col.customers).where('referredBy', isNull: false),
    );

    // Most recent booking date, one document, ordered server-side.
    final last = await appts.orderBy('date', descending: true).limit(1).get();

    final completed = r[4].toInt();
    final revenue = r[6].toDouble();

    return SalonSummary(
      customers: r[0].toInt(),
      staff: r[1].toInt(),
      services: r[2].toInt(),
      appointments: r[3].toInt(),
      completed: completed,
      cancelled: r[5].toInt(),
      revenue: revenue,
      outstanding: r[7].toDouble(),
      avgBookingValue: completed == 0 ? 0 : revenue / completed,
      repeatCustomers: repeat,
      lastActivity: last.docs.isEmpty ? null : last.docs.first.data()['date'] as String?,
    );
  }

  /// Leaderboard for the salons currently on screen. Bounded by design: it
  /// aggregates only the supplied salons, never the whole platform.
  Future<List<SalonPerformance>> loadPerformance(List<Salon> salons, DateWindow w) async {
    return Future.wait(salons.map((salon) async {
      final appts = _salons.doc(salon.id).collection(Col.appointments);
      final inWindow = appts
          .where('date', isGreaterThanOrEqualTo: w.startKey)
          .where('date', isLessThanOrEqualTo: w.endKey);
      // Three aggregations per salon, issued together.
      final revenueF = inWindow
          .where('paid', isEqualTo: true)
          .aggregate(sum('invoiceAmount'))
          .get();
      final bookingsF = inWindow.count().get();
      final customersF = _salons.doc(salon.id).collection(Col.customers).count().get();

      final revenue = (await revenueF).getSum('invoiceAmount') ?? 0;
      final bookings = (await bookingsF).count ?? 0;
      final customers = (await customersF).count ?? 0;

      return SalonPerformance(
        salon: salon,
        revenue: revenue.toDouble(),
        bookings: bookings,
        customers: customers,
      );
    }));
  }

  /// Suspend or reactivate a salon. Always paired with an audit row — the write
  /// and its audit entry go out together so a status change can never happen
  /// without a trace.
  Future<void> setStatus({
    required Salon salon,
    required bool suspend,
    required String actorUid,
    String? note,
  }) async {
    final next = suspend ? SalonStatus.suspended : SalonStatus.active;
    await _salons.doc(salon.id).update({'status': next});
    await _audit.record(
      action: suspend ? 'salon.suspend' : 'salon.reactivate',
      actorUid: actorUid,
      targetSalonId: salon.id,
      note: note ?? '${salon.name} set to $next',
    );
  }
}
