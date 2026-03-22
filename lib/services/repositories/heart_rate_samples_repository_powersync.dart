import 'package:ethan_utils/ethan_utils.dart';
import 'package:powersync/powersync.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:workouts/models/heart_rate_sample.dart';
import 'package:workouts/services/powersync/powersync_database_provider.dart';

part 'heart_rate_samples_repository_powersync.g.dart';

@riverpod
HeartRateSamplesRepository heartRateSamplesRepositoryPowerSync(Ref ref) {
  final powerSyncDatabase = ref.watch(powerSyncDatabaseProvider).value;
  if (powerSyncDatabase == null) {
    throw StateError('PowerSync database not initialized');
  }
  return HeartRateSamplesRepository(powerSyncDatabase);
}

class HeartRateSamplesRepository {
  HeartRateSamplesRepository(this._powerSync);

  final PowerSyncDatabase _powerSync;

  Stream<List<HeartRateSample>> watchSamplesForSession(String sessionId) {
    return _powerSync
        .watch(
          '''
          SELECT * FROM heart_rate_samples
          WHERE session_id = ?
          ORDER BY timestamp ASC
          ''',
          parameters: [sessionId],
        )
        .map((sampleRows) => sampleRows.mapL(HeartRateSample.fromRow));
  }

  Future<List<HeartRateSample>> fetchSamplesForSession(String sessionId) async {
    final sampleRows = await _powerSync.getAll(
      '''
      SELECT * FROM heart_rate_samples
      WHERE session_id = ?
      ORDER BY timestamp ASC
      ''',
      [sessionId],
    );
    return sampleRows.mapL(HeartRateSample.fromRow);
  }

  Future<void> addSample(HeartRateSample sample) async {
    await _powerSync.execute(
      '''
      INSERT OR IGNORE INTO heart_rate_samples (
        id, session_id, timestamp, bpm, source, energy_kcal, created_at, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      [
        sample.id,
        sample.sessionId,
        sample.timestamp.toIso8601String(),
        sample.bpm,
        sample.source,
        sample.energyKcal,
        DateTime.now().toIso8601String(),
        DateTime.now().toIso8601String(),
      ],
    );
  }

}
