import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:powersync/powersync.dart';
import 'package:workouts/features/settings/unit_system_provider.dart';
import 'package:workouts/services/backend/service_urls.dart';
import 'package:workouts/services/powersync/powersync_init.dart';

/// Owns the PowerSync database lifecycle and keeps its connector in sync with
/// the current backend URLs.
///
/// The local database is built once. Whenever [powersyncUrlProvider] or
/// [postgrestUrlProvider] emit a new value (because the hostname notifier
/// was refined to a different candidate, e.g. LAN → Tailscale), we re-apply
/// the connector against the same database — no teardown.
final powerSyncDatabaseProvider = FutureProvider<PowerSyncDatabase>((ref) async {
  final sharedPreferences = ref.watch(sharedPreferencesProvider);
  final powerSyncDatabase = await initPowerSync(
    sharedPreferences: sharedPreferences,
  );

  Future<void> applyCurrentUrls() => connectPowerSync(
    powerSyncDatabase,
    powersyncUrl: ref.read(powersyncUrlProvider),
    postgrestUrl: ref.read(postgrestUrlProvider),
  );

  await applyCurrentUrls();
  ref.listen(powersyncUrlProvider, (_, __) => applyCurrentUrls());
  ref.listen(postgrestUrlProvider, (_, __) => applyCurrentUrls());

  return powerSyncDatabase;
});
