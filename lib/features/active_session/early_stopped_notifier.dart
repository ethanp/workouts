import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workouts/features/active_session/active_session_provider.dart';
import 'package:workouts/models/session.dart';

/// Tracks which exercises the user has explicitly "called it quits" on
/// during the active session.
///
/// Ephemeral: the state lives only as long as the current session does.
/// When the active session id changes (new session, completion, discard,
/// resume of a different session), the set resets. Markers don't survive
/// app restart — the user can re-flag in one tap, and that's a deliberate
/// trade-off to avoid a schema migration for what is essentially a UI hint.
class EarlyStoppedNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() {
    ref.listen<AsyncValue<Session?>>(activeSessionProvider, (previous, next) {
      final previousSessionId = previous?.value?.id;
      final nextSessionId = next.value?.id;
      if (previousSessionId != nextSessionId) {
        state = <String>{};
      }
    });
    return <String>{};
  }

  void toggle({required String blockId, required String exerciseId}) {
    final key = earlyStoppedKey(blockId: blockId, exerciseId: exerciseId);
    final updated = Set<String>.from(state);
    if (!updated.remove(key)) updated.add(key);
    state = updated;
  }
}

String earlyStoppedKey({
  required String blockId,
  required String exerciseId,
}) => '$blockId::$exerciseId';

final earlyStoppedProvider =
    NotifierProvider<EarlyStoppedNotifier, Set<String>>(
      EarlyStoppedNotifier.new,
    );
