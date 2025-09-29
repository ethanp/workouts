import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workouts/models/health_export_summary.dart';
import 'package:workouts/models/health_permission_status.dart';
import 'package:workouts/providers/health_kit_provider.dart';

import 'support/fake_health_kit_bridge.dart';

void main() {
  group('HealthKitPermissionNotifier', () {
    test('loads initial status from bridge', () async {
      final bridge = FakeHealthKitBridge(
        status: HealthPermissionStatus.limited,
      );
      final container = ProviderContainer(
        overrides: [healthKitBridgeProvider.overrideWithValue(bridge)],
      );
      addTearDown(() {
        bridge.dispose();
        container.dispose();
      });

      final status = await container.read(
        healthKitPermissionNotifierProvider.future,
      );
      expect(status, HealthPermissionStatus.limited);
    });

    test('requestAuthorization updates state', () async {
      final bridge = FakeHealthKitBridge(
        status: HealthPermissionStatus.denied,
        requestedStatus: HealthPermissionStatus.authorized,
      );
      final container = ProviderContainer(
        overrides: [healthKitBridgeProvider.overrideWithValue(bridge)],
      );
      addTearDown(() {
        bridge.dispose();
        container.dispose();
      });

      await container
          .read(healthKitPermissionNotifierProvider.notifier)
          .requestAuthorization();
      final updated = container.read(healthKitPermissionNotifierProvider);
      expect(updated.value, HealthPermissionStatus.authorized);
    });
  });

  group('HeartRateTimelineNotifier', () {
    test('can be cleared', () async {
      final bridge = FakeHealthKitBridge();
      final container = ProviderContainer(
        overrides: [healthKitBridgeProvider.overrideWithValue(bridge)],
      );
      addTearDown(() {
        bridge.dispose();
        container.dispose();
      });

      final notifier = container.read(
        heartRateTimelineNotifierProvider.notifier,
      );
      notifier.clear();

      final timeline = container.read(heartRateTimelineNotifierProvider);
      expect(timeline, isEmpty);
    });
  });

  group('HealthExportController', () {
    test('clears exports when bridge deletion succeeds', () async {
      final bridge = FakeHealthKitBridge(deleteResult: true);
      final container = ProviderContainer(
        overrides: [healthKitBridgeProvider.overrideWithValue(bridge)],
      );
      addTearDown(() {
        bridge.dispose();
        container.dispose();
      });

      final notifier = container.read(healthExportControllerProvider.notifier);
      notifier.state = AsyncValue.data(
        const HealthExportSummary(exportedWorkoutUUIDs: ['a', 'b']),
      );

      await notifier.deleteAllExports();
      final state = container.read(healthExportControllerProvider);
      expect(state.value?.remainingCount, 0);
      expect(state.value?.lastError, isNull);
    });

    test('persists error message when deletion fails', () async {
      final bridge = FakeHealthKitBridge(deleteResult: false);
      final container = ProviderContainer(
        overrides: [healthKitBridgeProvider.overrideWithValue(bridge)],
      );
      addTearDown(() {
        bridge.dispose();
        container.dispose();
      });

      final notifier = container.read(healthExportControllerProvider.notifier);
      notifier.state = AsyncValue.data(
        const HealthExportSummary(exportedWorkoutUUIDs: ['a']),
      );

      await notifier.deleteAllExports();
      final state = container.read(healthExportControllerProvider);
      expect(state.value?.remainingCount, 1);
      expect(state.value?.lastError, isNotEmpty);
    });
  });
}
