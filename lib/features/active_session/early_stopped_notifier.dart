import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workouts/features/active_session/active_session_provider.dart';
import 'package:workouts/features/active_session/block_progress.dart';
import 'package:workouts/models/session.dart';

/// The set of (block, exercise) pairs the user has explicitly flagged as
/// "I'm done with this one" during the active session. Hides the
/// composite-key encoding so callers only deal in domain ids.
class EarlyStopped {
  EarlyStopped([this._keys = const <String>{}]);

  final Set<String> _keys;

  bool includes({required String blockId, required String exerciseId}) =>
      _keys.contains(_keyFor(blockId: blockId, exerciseId: exerciseId));

  EarlyStopped toggled({required String blockId, required String exerciseId}) {
    final key = _keyFor(blockId: blockId, exerciseId: exerciseId);
    final next = Set<String>.from(_keys);
    if (!next.remove(key)) next.add(key);
    return EarlyStopped(next);
  }

  static String _keyFor({
    required String blockId,
    required String exerciseId,
  }) => '$blockId::$exerciseId';
}

/// Tracks which exercises the user has explicitly "called it quits" on
/// during the active session.
///
/// Ephemeral: the state lives only as long as the current session does.
/// When the active session id changes (new session, completion, discard,
/// resume of a different session), the set resets. Markers don't survive
/// app restart — the user can re-flag in one tap, and that's a deliberate
/// trade-off to avoid a schema migration for what is essentially a UI hint.
class EarlyStoppedNotifier extends Notifier<EarlyStopped> {
  @override
  EarlyStopped build() {
    ref.listen<AsyncValue<Session?>>(activeSessionProvider, (previous, next) {
      final previousSessionId = previous?.value?.id;
      final nextSessionId = next.value?.id;
      if (previousSessionId != nextSessionId) {
        state = EarlyStopped();
      }
    });
    return EarlyStopped();
  }

  void toggle({required String blockId, required String exerciseId}) {
    state = state.toggled(blockId: blockId, exerciseId: exerciseId);
  }
}

final earlyStoppedProvider =
    NotifierProvider<EarlyStoppedNotifier, EarlyStopped>(
      EarlyStoppedNotifier.new,
    );

/// True when every exercise across every block in the active session is
/// either fully logged (loggedCount >= effectiveTargetSets) or explicitly
/// marked early-stopped via [earlyStoppedProvider]. Used by the session
/// resume screen to auto-prompt the user to finish.
///
/// Built atop [blockProgressProvider] so the auto-finish trigger and the
/// in-block "next exercise" recommendation share one source of truth.
final sessionAllExercisesDoneProvider = Provider<bool>((ref) {
  final session = ref.watch(activeSessionProvider).value;
  if (session == null || session.blocks.isEmpty) return false;
  bool sawScheduledExercise = false;
  for (final block in session.blocks) {
    final progress = ref.watch(blockProgressProvider(block));
    if (progress.hasScheduledWork) sawScheduledExercise = true;
    if (!progress.allComplete) return false;
  }
  return sawScheduledExercise;
});
