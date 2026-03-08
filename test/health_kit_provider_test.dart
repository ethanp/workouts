import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
        healthKitPermissionProvider.future,
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
          .read(healthKitPermissionProvider.notifier)
          .requestAuthorization();
      final updated = container.read(healthKitPermissionProvider);
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
        heartRateTimelineProvider.notifier,
      );
      notifier.clear();

      final timeline = container.read(heartRateTimelineProvider);
      expect(timeline, isEmpty);
    });
  });
}
