import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/collections.dart';
import '../../auth/data/auth_repository.dart';

final auditRepositoryProvider = Provider<AuditRepository>(
  (ref) => AuditRepository(ref.watch(firestoreProvider)),
);

@immutable
class AuditEntry {
  final String id;
  final String action;
  final String actorUid;
  final String? targetSalonId;
  final String? note;
  final String at;

  const AuditEntry({
    required this.id,
    required this.action,
    required this.actorUid,
    required this.targetSalonId,
    required this.note,
    required this.at,
  });

  factory AuditEntry.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    return AuditEntry(
      id: doc.id,
      action: d['action'] as String? ?? '',
      actorUid: d['actorUid'] as String? ?? '',
      targetSalonId: d['targetSalonId'] as String?,
      note: d['note'] as String?,
      at: d['at'] as String? ?? '',
    );
  }
}

/// Append-only trail of sensitive console actions.
///
/// Security Rules deny `update` and `delete` outright, so history cannot be
/// rewritten — not even by the super admin who wrote it.
class AuditRepository {
  final FirebaseFirestore _db;
  AuditRepository(this._db);

  CollectionReference<Map<String, dynamic>> get _logs => _db.collection(Col.adminAuditLogs);

  Future<void> record({
    required String action,
    required String actorUid,
    String? targetSalonId,
    String? note,
  }) async {
    await _logs.add({
      'action': action,
      'actorUid': actorUid,
      if (targetSalonId != null) 'targetSalonId': targetSalonId,
      if (note != null) 'note': note,
      'at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  /// Newest first, server-side limited. Audit logs are never streamed in bulk.
  Future<List<AuditEntry>> fetchRecent({int limit = 100, String? salonId}) async {
    Query<Map<String, dynamic>> q = _logs;
    if (salonId != null) q = q.where('targetSalonId', isEqualTo: salonId);
    final snap = await q.orderBy('at', descending: true).limit(limit).get();
    return snap.docs.map(AuditEntry.fromDoc).toList();
  }
}
