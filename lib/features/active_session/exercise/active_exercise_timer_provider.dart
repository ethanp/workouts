import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'active_exercise_timer_provider.g.dart';

/// Tracks which `ExerciseIntervalTimer` instance currently owns the single
/// running-timer slot. Only one timer may run at a time across the active
/// session: starting another claims the slot and any prior timer listening
/// to this provider resets itself.
///
/// The state is an opaque [Object] token created by the timer itself, so
/// identity (`identical(...)`) determines ownership without any need for the
/// timer to know about peers.
@Riverpod(keepAlive: true)
class ActiveExerciseTimer extends _$ActiveExerciseTimer {
  @override
  Object? build() => null;

  /// Claims the single active-timer slot for [owner]. Any prior owner that
  /// is listening will see the change and reset itself.
  void claim(Object owner) {
    if (!identical(state, owner)) state = owner;
  }

  /// Releases the slot iff [owner] still holds it. Safe to call even after
  /// another timer has already claimed — this is a no-op in that case.
  void release(Object owner) {
    if (identical(state, owner)) state = null;
  }
}
