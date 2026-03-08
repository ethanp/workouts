import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workouts/services/repositories/runs_repository_powersync.dart';
import 'package:workouts/utils/zone2_calculator.dart';

part 'unit_system_provider.g.dart';

enum UnitSystem { imperial, metric }

// Overridden with the loaded SharedPreferences instance in main() before runApp.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError();
});

const _kUnitSystemKey = 'unit_system';
const _kMaxHRKey = 'maxHeartRate';

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
    final zone2 = Zone2Calculator(maxHeartRate: maxHR);
    final progressNotifier =
        ref.read(zone2RecomputeProgressProvider.notifier);
    RunsRepositoryPowerSync repo;
    try {
      repo = ref.read(runsRepositoryPowerSyncProvider);
    } catch (_) {
      return; // DB not yet initialized
    }
    repo
        .recomputeAllZone2(
          zone2: zone2,
          onProgress: (done, total) {
            if (ref.mounted) progressNotifier.update(done, total);
          },
        )
        .then((_) {
          if (ref.mounted) progressNotifier.clear();
        })
        .catchError((Object _) {
          if (ref.mounted) progressNotifier.clear();
        });
  }
}

@Riverpod(keepAlive: true)
class Zone2RecomputeProgress extends _$Zone2RecomputeProgress {
  @override
  (int, int)? build() => null;

  void update(int done, int total) => state = (done, total);
  void clear() => state = null;
}
