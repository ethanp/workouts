import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:powersync/powersync.dart';
import 'package:workouts/services/powersync_init.dart';

final powerSyncDatabaseProvider = FutureProvider<PowerSyncDatabase>((
  ref,
) async {
  return await initPowerSync();
});
