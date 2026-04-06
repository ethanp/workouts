import 'package:flutter/services.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';
import 'package:workouts/models/session.dart';
import 'package:workouts/models/workout_exercise.dart';
import 'package:workouts/providers/health_kit_provider.dart';
import 'package:workouts/features/history/history_provider.dart';
import 'package:workouts/features/settings/unit_system_provider.dart';
import 'package:workouts/providers/watch_connectivity_provider.dart';
import 'package:workouts/services/repositories/session_repository_powersync.dart';
import 'package:workouts/services/watch_connectivity_bridge.dart';
import 'package:workouts/utils/error_bus.dart';
import 'package:workouts/utils/training_load_calculator.dart';

part 'active_session_provider.g.dart';

const _uuid = Uuid();
const _watchBridge = WatchConnectivityBridge();

@riverpod
class ActiveSessionNotifier extends _$ActiveSessionNotifier {
  @override
  Future<Session?> build() async {
    final commandStream = ref.watch(watchCommandStreamProvider);
    commandStream.whenData((command) {
      if (command == 'workoutStopped' && state.value != null) {
        complete();
      }
    });
    return null;
  }

  Future<void> _sendWatchCommand(Future<void> Function() command) async {
    try {
      await command();
    } on PlatformException catch (platformException) {
      errorBus.add('Watch: ${platformException.message}');
    }
  }

  void _invalidateSessionStreamsIfMounted() {
    if (ref.mounted) {
      ref.invalidate(heartRateTimelineProvider);
      ref.invalidate(sessionHistoryProvider);
    }
  }

  Future<void> start(String templateId) async {
    final repository = ref.read(sessionRepositoryPowerSyncProvider);
    final session = await repository.startSession(templateId);
    if (ref.mounted) {
      state = AsyncValue.data(session);
      ref.invalidate(heartRateTimelineProvider);
      ref.read(sessionUIVisibilityProvider.notifier).show();
      _sendWatchCommand(() =>
          _watchBridge.startWatchWorkout(sessionId: session.id));
    }
  }

  Future<void> resumeExisting(Session session) async {
    state = AsyncValue.data(session);
    // Automatically show session UI when resuming
    ref.read(sessionUIVisibilityProvider.notifier).show();
    _sendWatchCommand(() =>
        _watchBridge.startWatchWorkout(sessionId: session.id));
  }

  Future<void> logSet({
    required SessionBlock block,
    required WorkoutExercise exercise,
    double? weightKg,
    int? reps,
    Duration? duration,
    int? unitRemaining,
  }) async {
    final activeSession = state.value;
    if (activeSession == null) {
      throw StateError('No active session');
    }
    final sessionSetLog = SessionSetLog(
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
    await repository.logSet(session: activeSession, setLog: sessionSetLog);
    final updatedSession = await repository.fetchSessionById(activeSession.id);
    state = AsyncValue.data(updatedSession);
  }

  Future<void> unlogSet({
    required SessionBlock block,
    required WorkoutExercise exercise,
  }) async {
    final activeSession = state.value;
    if (activeSession == null) {
      throw StateError('No active session');
    }
    final repository = ref.read(sessionRepositoryPowerSyncProvider);
    await repository.unlogSet(
      session: activeSession,
      block: block,
      exercise: exercise,
    );
    final updatedSession = await repository.fetchSessionById(activeSession.id);
    state = AsyncValue.data(updatedSession);
  }

  Future<void> complete({String? notes, String? feeling}) async {
    final activeSession = state.value;
    if (activeSession == null) {
      return;
    }
    final repository = ref.read(sessionRepositoryPowerSyncProvider);
    final restingHeartRate = ref.read(restingHeartRateProvider);
    final trainingLoad = TrainingLoadCalculator(
      restingHeartRate: restingHeartRate,
    );
    await repository.completeSession(
      activeSession,
      notes: notes,
      feeling: feeling,
      trainingLoad: trainingLoad,
    );
    if (ref.mounted) {
      state = const AsyncValue.data(null);
      _invalidateSessionStreamsIfMounted();
      ref.read(sessionUIVisibilityProvider.notifier).hide();
      _sendWatchCommand(_watchBridge.stopWatchWorkout);
    }
  }

  Future<void> pause() async {
    final activeSession = state.value;
    if (activeSession == null ||
        activeSession.isPaused ||
        activeSession.completedAt != null) {
      return;
    }
    final repository = ref.read(sessionRepositoryPowerSyncProvider);
    await repository.pauseSession(activeSession);
    final updatedSession = await repository.fetchSessionById(activeSession.id);
    state = AsyncValue.data(updatedSession);
    _sendWatchCommand(_watchBridge.pauseWatchWorkout);
  }

  Future<void> resume() async {
    final activeSession = state.value;
    if (activeSession == null ||
        !activeSession.isPaused ||
        activeSession.completedAt != null) {
      return;
    }
    final repository = ref.read(sessionRepositoryPowerSyncProvider);
    await repository.resumeSession(activeSession);
    final updatedSession = await repository.fetchSessionById(activeSession.id);
    state = AsyncValue.data(updatedSession);
    _sendWatchCommand(_watchBridge.resumeWatchWorkout);
  }

  Future<void> discard() async {
    final activeSession = state.value;
    if (activeSession != null) {
      final repository = ref.read(sessionRepositoryPowerSyncProvider);
      await repository.discardSession(activeSession.id);
    }
    if (ref.mounted) {
      state = const AsyncValue.data(null);
      _invalidateSessionStreamsIfMounted();
      ref.read(sessionUIVisibilityProvider.notifier).hide();
      _sendWatchCommand(_watchBridge.stopWatchWorkout);
    }
  }

  Future<void> addExercise(SessionBlock block, WorkoutExercise exercise) async {
    final activeSession = state.value;
    if (activeSession == null) return;
    final repository = ref.read(sessionRepositoryPowerSyncProvider);
    state = AsyncValue.data(
      await repository.addExercise(activeSession, block.id, exercise),
    );
  }

  Future<void> removeExercise(SessionBlock block, String exerciseId) async {
    final activeSession = state.value;
    if (activeSession == null) return;
    final repository = ref.read(sessionRepositoryPowerSyncProvider);
    state = AsyncValue.data(
      await repository.removeExercise(activeSession, block.id, exerciseId),
    );
  }

  Future<void> refreshFromDatabase() async {
    final activeSession = state.value;
    if (activeSession == null) return;
    final repository = ref.read(sessionRepositoryPowerSyncProvider);
    final refreshedSession = await repository.fetchSessionById(activeSession.id);
    state = AsyncValue.data(refreshedSession);
  }
}

@riverpod
class SessionUIVisibilityNotifier extends _$SessionUIVisibilityNotifier {
  @override
  bool build() => false;

  void show() => state = true;

  void hide() => state = false;
}
