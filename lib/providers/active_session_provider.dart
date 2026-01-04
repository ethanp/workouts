import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';
import 'package:workouts/models/session.dart';
import 'package:workouts/models/workout_exercise.dart';
import 'package:workouts/providers/health_kit_provider.dart';
import 'package:workouts/providers/history_provider.dart';
import 'package:workouts/services/repositories/session_repository_powersync.dart';

part 'active_session_provider.g.dart';

const _uuid = Uuid();

@riverpod
class ActiveSessionNotifier extends _$ActiveSessionNotifier {
  @override
  Future<Session?> build() async {
    return null;
  }

  Future<void> start(String templateId) async {
    final repository = ref.read(sessionRepositoryPowerSyncProvider);
    final session = await repository.startSession(templateId);
    state = AsyncValue.data(session);
    ref.invalidate(heartRateTimelineNotifierProvider);
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
    int? unitRemaining,
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
      unitRemaining: unitRemaining,
    );
    final repository = ref.read(sessionRepositoryPowerSyncProvider);
    await repository.logSet(
      session: current,
      block: block,
      exercise: exercise,
      log: log,
    );
    final updatedSession = await repository.fetchSessionById(current.id);
    state = AsyncValue.data(updatedSession);
  }

  Future<void> unlogSet({
    required SessionBlock block,
    required WorkoutExercise exercise,
  }) async {
    final current = state.value;
    if (current == null) {
      throw StateError('No active session');
    }
    final repository = ref.read(sessionRepositoryPowerSyncProvider);
    await repository.unlogSet(
      session: current,
      block: block,
      exercise: exercise,
    );
    final updatedSession = await repository.fetchSessionById(current.id);
    state = AsyncValue.data(updatedSession);
  }

  Future<void> complete({String? notes, String? feeling}) async {
    final current = state.value;
    if (current == null) {
      return;
    }
    final repository = ref.read(sessionRepositoryPowerSyncProvider);
    await repository.completeSession(current, notes: notes, feeling: feeling);
    state = const AsyncValue.data(null);
    ref.invalidate(heartRateTimelineNotifierProvider);
    ref.read(sessionUIVisibilityNotifierProvider.notifier).hide();
    ref.invalidate(sessionHistoryProvider);
  }

  Future<void> pause() async {
    final current = state.value;
    if (current == null || current.isPaused || current.completedAt != null) {
      return;
    }
    final repository = ref.read(sessionRepositoryPowerSyncProvider);
    await repository.pauseSession(current);
    final updatedSession = await repository.fetchSessionById(current.id);
    state = AsyncValue.data(updatedSession);
  }

  Future<void> resume() async {
    final current = state.value;
    if (current == null || !current.isPaused || current.completedAt != null) {
      return;
    }
    final repository = ref.read(sessionRepositoryPowerSyncProvider);
    await repository.resumeSession(current);
    final updatedSession = await repository.fetchSessionById(current.id);
    state = AsyncValue.data(updatedSession);
  }

  Future<void> discard() async {
    final current = state.value;
    if (current != null) {
      final repository = ref.read(sessionRepositoryPowerSyncProvider);
      await repository.discardSession(current.id);
    }
    state = const AsyncValue.data(null);
    ref.invalidate(heartRateTimelineNotifierProvider);
    ref.read(sessionUIVisibilityNotifierProvider.notifier).hide();
    ref.invalidate(sessionHistoryProvider);
  }

  Future<void> addExercise(SessionBlock block, WorkoutExercise exercise) async {
    final current = state.value;
    if (current == null) return;
    final repository = ref.read(sessionRepositoryPowerSyncProvider);
    state = AsyncValue.data(
      await repository.addExercise(current, block.id, exercise),
    );
  }

  Future<void> removeExercise(SessionBlock block, String exerciseId) async {
    final current = state.value;
    if (current == null) return;
    final repository = ref.read(sessionRepositoryPowerSyncProvider);
    state = AsyncValue.data(
      await repository.removeExercise(current, block.id, exerciseId),
    );
  }

  Future<void> refreshFromDatabase() async {
    final current = state.value;
    if (current == null) return;
    final repository = ref.read(sessionRepositoryPowerSyncProvider);
    final refreshed = await repository.fetchSessionById(current.id);
    state = AsyncValue.data(refreshed);
  }
}

@riverpod
class SessionUIVisibilityNotifier extends _$SessionUIVisibilityNotifier {
  @override
  bool build() => false;

  void show() => state = true;

  void hide() => state = false;
}
