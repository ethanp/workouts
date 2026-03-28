import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workouts/services/repositories/cardio_repository_powersync.dart';
import 'package:workouts/services/repositories/session_repository_powersync.dart';
import 'package:workouts/utils/training_load_calculator.dart';

part 'unit_system_provider.g.dart';

enum UnitSystem { imperial, metric }

// Overridden with the loaded SharedPreferences instance in main() before runApp.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError();
});

const _kUnitSystemKey = 'unit_system';
const _kMaxHRKey = 'maxHeartRate';
const _kRestingHRKey = 'restingHeartRate';
const _kZ2TargetMinutesKey = 'weeklyZ2TargetMinutes';

@Riverpod(keepAlive: true)
class UnitSystemNotifier extends _$UnitSystemNotifier {
  @override
  UnitSystem build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final storedUnitSystemName = prefs.getString(_kUnitSystemKey);
    return UnitSystem.values.firstWhere(
      (unitSystem) => unitSystem.name == storedUnitSystemName,
      orElse: () => UnitSystem.imperial,
    );
  }

  Future<void> setUnitSystem(UnitSystem system) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(_kUnitSystemKey, system.name);
    state = system;
  }
}

@Riverpod(keepAlive: true)
class MaxHeartRateNotifier extends _$MaxHeartRateNotifier {
  @override
  int build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return prefs.getInt(_kMaxHRKey) ?? 190;
  }

  Future<void> setMaxHeartRate(int heartRateBpm) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setInt(_kMaxHRKey, heartRateBpm);
    state = heartRateBpm;
    _recomputeInBackground(heartRateBpm);
  }

  void _recomputeInBackground(int maxHeartRate) {
    final restingHeartRate = ref.read(restingHeartRateProvider);
    final trainingLoad = TrainingLoadCalculator(
      restingHeartRate: restingHeartRate,
    );
    final progressNotifier =
        ref.read(metricsRecomputeProgressProvider.notifier);
    CardioRepositoryPowerSync cardioRepo;
    SessionRepositoryPowerSync sessionRepo;
    try {
      cardioRepo = ref.read(cardioRepositoryPowerSyncProvider);
      sessionRepo = ref.read(sessionRepositoryPowerSyncProvider);
    } catch (_) {
      return; // DB not yet initialized
    }
    int cardioDone = 0, cardioTotal = 0;
    int sessionsDone = 0, sessionsTotal = 0;
    void reportCombinedProgress() {
      final int done = cardioDone + sessionsDone;
      final int total = cardioTotal + sessionsTotal;
      if (ref.mounted && total > 0) progressNotifier.update(done, total);
    }
    Future.wait([
      cardioRepo.recomputeZones(
        trainingLoad: trainingLoad,
        onProgress: (done, total) {
          cardioDone = done;
          cardioTotal = total;
          reportCombinedProgress();
        },
      ),
      sessionRepo.recomputeZones(
        trainingLoad: trainingLoad,
        onProgress: (done, total) {
          sessionsDone = done;
          sessionsTotal = total;
          reportCombinedProgress();
        },
      ),
    ])
        .then((_) {
          if (ref.mounted) progressNotifier.clear();
        })
        .catchError((Object _) {
          if (ref.mounted) progressNotifier.clear();
        });
  }
}

@Riverpod(keepAlive: true)
class RestingHeartRateNotifier extends _$RestingHeartRateNotifier {
  @override
  int build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return prefs.getInt(_kRestingHRKey) ?? 60;
  }

  Future<void> setRestingHeartRate(int restingHeartRateBpm) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setInt(_kRestingHRKey, restingHeartRateBpm);
    state = restingHeartRateBpm;
  }
}

@Riverpod(keepAlive: true)
class MetricsRecomputeProgress extends _$MetricsRecomputeProgress {
  @override
  (int, int)? build() => null;

  void update(int done, int total) => state = (done, total);
  void clear() => state = null;
}

@Riverpod(keepAlive: true)
class WeeklyZ2TargetMinutesNotifier
    extends _$WeeklyZ2TargetMinutesNotifier {
  @override
  int build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return prefs.getInt(_kZ2TargetMinutesKey) ?? 150;
  }

  Future<void> setTarget(int minutes) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setInt(_kZ2TargetMinutesKey, minutes);
    state = minutes;
  }
}
