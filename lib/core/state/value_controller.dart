import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A minimal writable provider for simple UI state.
///
/// Riverpod 3 moved `StateProvider` into its legacy surface, so the console
/// uses `Notifier` instead — the supported, non-deprecated primitive. This
/// wrapper keeps the ergonomics of a plain value holder without spreading a
/// bespoke Notifier subclass across every file that needs one.
class ValueController<T> extends Notifier<T> {
  ValueController(this._initial);
  final T _initial;

  @override
  T build() => _initial;

  void setValue(T value) => state = value;

  void update(T Function(T current) transform) => state = transform(state);
}

/// Convenience constructor for the common case.
NotifierProvider<ValueController<T>, T> valueProvider<T>(T initial) =>
    NotifierProvider<ValueController<T>, T>(() => ValueController<T>(initial));
