import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:workouts/models/health_permission_status.dart';
import 'package:workouts/models/heart_rate_sample.dart';
import 'package:workouts/features/active_session/active_session_provider.dart';
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

  /// Triggers the OS permission prompt and updates [state] to reflect the
  /// resulting authorization status.
  ///
  /// Pins the provider alive for the duration of the request so the
  /// surrounding `ref` survives the OS-dialog await even when no consumer
  /// is currently watching us. Without the pin, the auto-dispose default
  /// of `@riverpod` lets the provider be torn down between "set loading"
  /// and "set result" — `state =` then throws because its `Ref` is gone.
  Future<void> requestAuthorization() async {
    final keepAliveLink = ref.keepAlive();
    try {
      final bridge = ref.read(healthKitBridgeProvider);
      state = const AsyncValue.loading();
      state = await AsyncValue.guard(bridge.requestAuthorization);
    } finally {
      keepAliveLink.close();
    }
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
        ..sort(
          (earlierSample, laterSample) =>
              earlierSample.timestamp.compareTo(laterSample.timestamp),
        );
      state = updated;

      try {
        final heartRateRepository = ref.read(
          heartRateSamplesRepositoryPowerSyncProvider,
        );
        await heartRateRepository.addSample(normalized);
      } catch (_) {
        // Ignore persistence errors; UI still renders live data.
      }
    });
  }

  String? _resolveSessionId(String sessionId) {
    if (sessionId.isNotEmpty && sessionId != 'unknown') {
      return sessionId;
    }
    final activeSession = ref.read(activeSessionProvider).value;
    return activeSession?.id;
  }
}
