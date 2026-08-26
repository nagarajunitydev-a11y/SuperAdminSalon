import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/collections.dart';
import '../../../core/utils/date_range.dart';
import '../../../core/widgets/date_range_picker.dart';
import '../../auth/data/auth_repository.dart';
import '../../dashboard/domain/platform_metrics.dart';

/// "Top services" and "staff utilisation" cannot be answered by a `count()`
/// alone: Firestore has no GROUP BY, so there is no server-side way to ask
/// "count appointments per distinct serviceName".
///
/// Rather than download every appointment to group in the browser, this reads a
/// BOUNDED, date-filtered projection and tallies it client-side. The read is
/// capped so cost stays predictable on a large platform; when the cap is hit
/// the result is a representative sample of the window, and the UI says so.
///
/// The durable fix for exact figures at scale is a rollup document maintained
/// by a Cloud Function on appointment writes — noted in the README as the next
/// optimisation, since it needs the Blaze plan.
const _sampleCap = 3000;

final catalogRepositoryProvider = Provider<CatalogRepository>(
  (ref) => CatalogRepository(ref.watch(firestoreProvider)),
);

class CatalogRepository {
  final FirebaseFirestore _db;
  CatalogRepository(this._db);

  Future<List<NamedValue>> _tallyBy(String field, DateWindow w, {int top = 12}) async {
    final snap = await _db
        .collectionGroup(Col.appointments)
        .where('date', isGreaterThanOrEqualTo: w.startKey)
        .where('date', isLessThanOrEqualTo: w.endKey)
        .limit(_sampleCap)
        .get();

    final tally = <String, int>{};
    for (final doc in snap.docs) {
      final name = (doc.data()[field] as String?)?.trim();
      if (name == null || name.isEmpty) continue;
      tally[name] = (tally[name] ?? 0) + 1;
    }

    final entries = tally.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final capped = snap.docs.length >= _sampleCap;

    return [
      for (final e in entries.take(top))
        NamedValue(
          e.key,
          e.value,
          subtitle: capped ? 'from a $_sampleCap-booking sample' : null,
        ),
    ];
  }

  Future<List<NamedValue>> topServices(DateWindow w) => _tallyBy('serviceName', w);
  Future<List<NamedValue>> staffUtilisation(DateWindow w) => _tallyBy('staffName', w);
}

final topServicesProvider = FutureProvider.autoDispose<List<NamedValue>>((ref) async {
  ref.keepAlive();
  final w = ref.watch(dateWindowProvider);
  return ref.watch(catalogRepositoryProvider).topServices(w);
});

final staffUtilisationProvider = FutureProvider.autoDispose<List<NamedValue>>((ref) async {
  ref.keepAlive();
  final w = ref.watch(dateWindowProvider);
  return ref.watch(catalogRepositoryProvider).staffUtilisation(w);
});
