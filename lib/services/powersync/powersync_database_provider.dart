import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:powersync/powersync.dart';
import 'package:workouts/providers/unit_system_provider.dart';
import 'package:workouts/services/powersync/powersync_init.dart';

final powerSyncDatabaseProvider = FutureProvider<PowerSyncDatabase>((
  ref,
) async {
  final sharedPreferences = ref.watch(sharedPreferencesProvider);
  return await initPowerSync(sharedPreferences: sharedPreferences);
});
