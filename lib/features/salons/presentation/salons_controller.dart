import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/date_range_picker.dart';
import '../data/salon_repository.dart';
import '../domain/salon.dart';

@immutable
class SalonListState {
  final List<Salon> items;
  final bool loading;
  final bool hasMore;
  final Object? error;
  final String search;
  final String? status;
  final int page;

  const SalonListState({
    this.items = const [],
    this.loading = true,
    this.hasMore = false,
    this.error,
    this.search = '',
    this.status,
    this.page = 1,
  });

  SalonListState copyWith({
    List<Salon>? items,
    bool? loading,
    bool? hasMore,
    Object? error,
    String? search,
    String? status,
    bool clearStatus = false,
    int? page,
  }) =>
      SalonListState(
        items: items ?? this.items,
        loading: loading ?? this.loading,
        hasMore: hasMore ?? this.hasMore,
        error: error,
        search: search ?? this.search,
        status: clearStatus ? null : (status ?? this.status),
        page: page ?? this.page,
      );
}

/// Cursor-paged salon list.
///
/// Pages are fetched one at a time with `startAfterDocument`, and the cursor
/// stack is what makes "previous" work without re-reading everything: each
/// page's last document is pushed so stepping back is a single query, never a
/// re-scan from the beginning.
class SalonListNotifier extends Notifier<SalonListState> {
  final _cursors = <DocumentSnapshot<Map<String, dynamic>>?>[null];

  @override
  SalonListState build() {
    // Rebuild from scratch whenever the reporting window changes.
    ref.watch(dateWindowProvider);
    Future.microtask(() => _load(reset: true));
    return const SalonListState();
  }

  SalonRepository get _repo => ref.read(salonRepositoryProvider);

  Future<void> _load({bool reset = false, int? pageIndex}) async {
    if (reset) {
      _cursors
        ..clear()
        ..add(null);
    }
    final index = pageIndex ?? 0;
    state = state.copyWith(loading: true, error: null);
    try {
      final page = await _repo.fetchPage(
        startAfter: index < _cursors.length ? _cursors[index] : null,
        search: state.search,
        status: state.status,
      );
      // Record this page's cursor so the next page can start after it.
      if (_cursors.length == index + 1 && page.cursor != null) {
        _cursors.add(page.cursor);
      }
      state = state.copyWith(
        items: page.items,
        loading: false,
        hasMore: page.hasMore,
        page: index + 1,
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: e);
    }
  }

  Future<void> setSearch(String value) async {
    state = state.copyWith(search: value);
    await _load(reset: true);
  }

  Future<void> setStatus(String? value) async {
    state = state.copyWith(status: value, clearStatus: value == null);
    await _load(reset: true);
  }

  Future<void> next() async {
    if (!state.hasMore || state.loading) return;
    await _load(pageIndex: state.page);
  }

  Future<void> previous() async {
    if (state.page <= 1 || state.loading) return;
    await _load(pageIndex: state.page - 2);
  }

  Future<void> refresh() => _load(reset: true);
}

final salonListProvider =
    NotifierProvider<SalonListNotifier, SalonListState>(SalonListNotifier.new);

final salonProvider =
    StreamProvider.autoDispose.family<Salon?, String>((ref, id) =>
        ref.watch(salonRepositoryProvider).watchOne(id));

final salonSummaryProvider =
    FutureProvider.autoDispose.family<SalonSummary, String>((ref, id) async {
  ref.keepAlive();
  final window = ref.watch(dateWindowProvider);
  return ref.watch(salonRepositoryProvider).loadSummary(id, window);
});
