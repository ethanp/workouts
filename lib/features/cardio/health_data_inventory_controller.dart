import 'package:ethan_utils/ethan_utils.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:workouts/models/health_data_inventory.dart';
import 'package:workouts/providers/health_kit_provider.dart';

part 'health_data_inventory_controller.g.dart';

const _log = ELogger('HealthDataInventoryController');

@riverpod
class HealthDataInventoryController() extends _$HealthDataInventoryController {
  @override
  HealthDataInventoryState build() => const HealthDataInventoryState();

  Future<void> inspectRecentWorkouts({int maxWorkouts = 40}) async {
    final keepAliveLink = ref.keepAlive();
    final healthKitBridge = ref.read(healthKitBridgeProvider);
    final progressSubscription = healthKitBridge
        .inventoryInspectProgress()
        .listen(_showInspectProgress);
    try {
      state = HealthDataInventoryState(
        inventory: state.inventory,
        inspectProgress: const HealthInventoryInspectProgress(
          caption: 'Requesting Health access…',
        ),
      );
      await ref
          .read(healthKitPermissionProvider.notifier)
          .requestAuthorization();
      _showInspectProgress(
        HealthInventoryInspectProgress(
          caption: 'Loading last $maxWorkouts cardio workouts…',
          totalWorkouts: maxWorkouts,
        ),
      );
      final payload = await healthKitBridge.inspectRecentCardioWorkouts(
        maxWorkouts: maxWorkouts,
      );
      await progressSubscription.cancel();
      state = HealthDataInventoryState(
        inventory: HealthDataInventory.fromMap(payload),
      );
    } catch (error, stackTrace) {
      await progressSubscription.cancel();
      _log.error('Health data inventory failed', error, stackTrace);
      state = HealthDataInventoryState(
        inventory: state.inventory,
        errorMessage: '$error',
      );
    } finally {
      keepAliveLink.close();
    }
  }

  void _showInspectProgress(HealthInventoryInspectProgress inspectProgress) {
    if (!ref.mounted) return;
    state = HealthDataInventoryState(
      inventory: state.inventory,
      inspectProgress: inspectProgress,
    );
  }
}
