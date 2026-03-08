import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workouts/services/repositories/runs_repository_powersync.dart';
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

@Riverpod(keepAlive: true)
class UnitSystemNotifier extends _$UnitSystemNotifier {
  @override
  UnitSystem build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final stored = prefs.getString(_kUnitSystemKey);
    return UnitSystem.values.firstWhere(
      (u) => u.name == stored,
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

  Future<void> setMaxHeartRate(int hr) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setInt(_kMaxHRKey, hr);
    state = hr;
    _recomputeInBackground(hr);
  }

  void _recomputeInBackground(int maxHR) {
    final restingHR = ref.read(restingHeartRateProvider);
    final trainingLoad = TrainingLoadCalculator(
      maxHeartRate: maxHR,
      restingHeartRate: restingHR,
    );
    final progressNotifier =
        ref.read(metricsRecomputeProgressProvider.notifier);
    RunsRepositoryPowerSync runsRepo;
    SessionRepositoryPowerSync sessionRepo;
    try {
      runsRepo = ref.read(runsRepositoryPowerSyncProvider);
      sessionRepo = ref.read(sessionRepositoryPowerSyncProvider);
    } catch (_) {
      return; // DB not yet initialized
    }
    int runsDone = 0, runsTotal = 0;
    int sessionsDone = 0, sessionsTotal = 0;
    void reportCombinedProgress() {
      final int done = runsDone + sessionsDone;
      final int total = runsTotal + sessionsTotal;
      if (ref.mounted && total > 0) progressNotifier.update(done, total);
    }
    Future.wait([
      runsRepo.recomputeZone2(
        trainingLoad: trainingLoad,
        onProgress: (done, total) {
          runsDone = done;
          runsTotal = total;
          reportCombinedProgress();
        },
      ),
      sessionRepo.recomputeZone2(
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

  Future<void> setRestingHeartRate(int hr) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setInt(_kRestingHRKey, hr);
    state = hr;
  }
}

@Riverpod(keepAlive: true)
class MetricsRecomputeProgress extends _$MetricsRecomputeProgress {
  @override
  (int, int)? build() => null;

  void update(int done, int total) => state = (done, total);
  void clear() => state = null;
}
