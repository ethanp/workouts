import 'package:ethan_utils/ethan_utils.dart';
import 'package:powersync/powersync.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:workouts/models/training_location.dart';
import 'package:workouts/services/powersync/powersync_database_provider.dart';

part 'locations_repository_powersync.g.dart';

class LocationsRepositoryPowerSync {
  LocationsRepositoryPowerSync(this._powerSync);

  final PowerSyncDatabase _powerSync;

  Future<List<TrainingLocation>> fetchLocations() async {
    final locationRows = await _powerSync.getAll(
      'SELECT * FROM training_locations ORDER BY name ASC',
    );
    return locationRows.mapL(TrainingLocation.fromRow);
  }

  Stream<List<TrainingLocation>> watchLocations() {
    return _powerSync
        .watch('SELECT * FROM training_locations ORDER BY name ASC')
        .map((locationRows) => locationRows.mapL(TrainingLocation.fromRow));
  }

  Future<void> addLocation(TrainingLocation location) async {
    final now = DateTime.now().toIso8601String();
    await _powerSync.execute(
      '''
      INSERT INTO training_locations (
        id, name, equipment, created_at, updated_at
      ) VALUES (?, ?, ?, ?, ?)
      ''',
      [location.id, location.name, location.equipment, now, now],
    );
  }

  Future<void> updateLocation(TrainingLocation location) async {
    final now = DateTime.now().toIso8601String();
    await _powerSync.execute(
      '''
      UPDATE training_locations
      SET name = ?, equipment = ?, updated_at = ?
      WHERE id = ?
      ''',
      [location.name, location.equipment, now, location.id],
    );
  }

  Future<void> deleteLocation(String id) async {
    await _powerSync.execute(
      'DELETE FROM training_locations WHERE id = ?',
      [id],
    );
  }
}

@riverpod
LocationsRepositoryPowerSync locationsRepositoryPowerSync(Ref ref) {
  final powerSyncDatabaseAsync = ref.watch(powerSyncDatabaseProvider);
  final powerSyncDatabase = powerSyncDatabaseAsync.value;
  if (powerSyncDatabase == null) {
    throw StateError('PowerSync database not initialized');
  }
  return LocationsRepositoryPowerSync(powerSyncDatabase);
}
