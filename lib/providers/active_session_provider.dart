import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';
import 'package:workouts/models/session.dart';
import 'package:workouts/models/workout_exercise.dart';
import 'package:workouts/providers/history_provider.dart';
import 'package:workouts/services/repositories/session_repository.dart';

part 'active_session_provider.g.dart';

const _uuid = Uuid();

@riverpod
class ActiveSessionNotifier extends _$ActiveSessionNotifier {
  @override
  Future<Session?> build() async {
    return null;
  }

  Future<void> start(String templateId) async {
    final repository = ref.read(sessionRepositoryProvider);
    final session = await repository.startSession(templateId);
    state = AsyncValue.data(session);
    // Automatically show session UI when starting
    ref.read(sessionUIVisibilityNotifierProvider.notifier).show();
  }

  Future<void> resumeExisting(Session session) async {
    state = AsyncValue.data(session);
    // Automatically show session UI when resuming
    ref.read(sessionUIVisibilityNotifierProvider.notifier).show();
  }

  Future<void> logSet({
    required SessionBlock block,
    required WorkoutExercise exercise,
    double? weightKg,
    int? reps,
    Duration? duration,
    double? rpe,
    String? notes,
  }) async {
    final current = state.value;
    if (current == null) {
      throw StateError('No active session');
    }
    final log = SessionSetLog(
      id: _uuid.v4(),
      sessionBlockId: block.id,
      exerciseId: exercise.id,
      setIndex: block.logs.length,
      weightKg: weightKg,
      reps: reps,
      duration: duration,
      rpe: rpe,
      notes: notes,
    );
    final repository = ref.read(sessionRepositoryProvider);
    await repository.logSet(
      session: current,
      block: block,
      exercise: exercise,
      log: log,
    );
    final updatedSession = await repository.fetchSessionById(current.id);
    state = AsyncValue.data(updatedSession);
  }

  Future<void> complete({String? notes, String? feeling}) async {
    final current = state.value;
    if (current == null) {
      return;
    }
    final repository = ref.read(sessionRepositoryProvider);
    await repository.completeSession(current, notes: notes, feeling: feeling);
    state = const AsyncValue.data(null);
    // Hide session UI when completing
    ref.read(sessionUIVisibilityNotifierProvider.notifier).hide();
    // Refresh history to show updated session
    ref.invalidate(sessionHistoryProvider);
  }

  Future<void> pause() async {
    final current = state.value;
    if (current == null || current.isPaused || current.completedAt != null) {
      return;
    }
    final pausedSession = current.copyWith(
      isPaused: true,
      pausedAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    final repository = ref.read(sessionRepositoryProvider);
    await repository.updateSession(pausedSession);
    state = AsyncValue.data(pausedSession);
  }

  Future<void> resume() async {
    final current = state.value;
    if (current == null || !current.isPaused || current.completedAt != null) {
      return;
    }
    final pauseDuration = current.pausedAt != null
        ? DateTime.now().difference(current.pausedAt!)
        : Duration.zero;

    final resumedSession = current.copyWith(
      isPaused: false,
      pausedAt: null,
      totalPausedDuration: current.totalPausedDuration + pauseDuration,
      updatedAt: DateTime.now(),
    );
    final repository = ref.read(sessionRepositoryProvider);
    await repository.updateSession(resumedSession);
    state = AsyncValue.data(resumedSession);
  }

  Future<void> discard() async {
    state = const AsyncValue.data(null);
  }
}

@riverpod
class SessionUIVisibilityNotifier extends _$SessionUIVisibilityNotifier {
  @override
  bool build() => false;

  void show() => state = true;
  void hide() => state = false;
}
