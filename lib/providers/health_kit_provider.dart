import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:workouts/models/health_export_summary.dart';
import 'package:workouts/models/health_permission_status.dart';
import 'package:workouts/models/heart_rate_sample.dart';
import 'package:workouts/providers/active_session_provider.dart';
import 'package:workouts/services/repositories/heart_rate_samples_repository_powersync.dart';
import 'package:workouts/services/health_kit_bridge.dart';

part 'health_kit_provider.g.dart';

@riverpod
HealthKitBridge healthKitBridge(Ref ref) {
  return HealthKitBridge();
}

@riverpod
class HealthKitPermissionNotifier extends _$HealthKitPermissionNotifier {
  @override
  Future<HealthPermissionStatus> build() async {
    final bridge = ref.watch(healthKitBridgeProvider);
    return bridge.getAuthorizationStatus();
  }

  Future<void> requestAuthorization() async {
    final bridge = ref.read(healthKitBridgeProvider);
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(bridge.requestAuthorization);
  }
}

@riverpod
class HeartRateTimelineNotifier extends _$HeartRateTimelineNotifier {
  StreamSubscription<HeartRateSample>? _subscription;

  @override
  List<HeartRateSample> build() {
    ref.onDispose(() => _subscription?.cancel());
    _listen();
    return const [];
  }

  void clear() {
    state = const [];
  }

  void _listen() {
    _subscription?.cancel();
    final bridge = ref.read(healthKitBridgeProvider);
    _subscription = bridge.heartRateStream().listen((sample) async {
      final sessionId = _resolveSessionId(sample.sessionId);
      if (sessionId == null) {
        return;
      }

      final normalized = sample.copyWith(sessionId: sessionId);
      final updated = [...state, normalized]
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
      state = updated;

      try {
        final repo = ref.read(heartRateSamplesRepositoryPowerSyncProvider);
        await repo.addSample(normalized);
      } catch (_) {
        // Ignore persistence errors; UI still renders live data.
      }
    });
  }

  String? _resolveSessionId(String sessionId) {
    if (sessionId.isNotEmpty && sessionId != 'unknown') {
      return sessionId;
    }
    final active = ref.read(activeSessionProvider).value;
    return active?.id;
  }
}

@riverpod
class HealthExportController extends _$HealthExportController {
  @override
  Future<HealthExportSummary> build() async {
    return const HealthExportSummary(exportedWorkoutUUIDs: []);
  }

  Future<void> deleteAllExports() async {
    final snapshot = state.value;
    if (snapshot == null || snapshot.exportedWorkoutUUIDs.isEmpty) {
      state = AsyncValue.data(
        (snapshot ?? const HealthExportSummary(exportedWorkoutUUIDs: []))
            .copyWith(clearError: true),
      );
      return;
    }

    state = const AsyncValue.loading();
    final bridge = ref.read(healthKitBridgeProvider);
    final result = await AsyncValue.guard(
      () => bridge.deleteWorkouts(snapshot.exportedWorkoutUUIDs),
    );

    result.when(
      data: (success) {
        if (success) {
          state = AsyncValue.data(
            HealthExportSummary(
              exportedWorkoutUUIDs: const [],
              lastDeletionAt: DateTime.now(),
            ),
          );
        } else {
          state = AsyncValue.data(
            snapshot.copyWith(
              lastError: 'Unable to remove workouts from HealthKit.',
            ),
          );
        }
      },
      loading: () {
        // Keep current loading state
      },
      error: (error, stackTrace) {
        state = AsyncValue.error(error, stackTrace);
      },
    );
  }
}
