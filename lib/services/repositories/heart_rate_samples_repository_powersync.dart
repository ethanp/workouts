import 'package:powersync/powersync.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:workouts/models/heart_rate_sample.dart';
import 'package:workouts/services/powersync_database_provider.dart';

part 'heart_rate_samples_repository_powersync.g.dart';

@riverpod
HeartRateSamplesRepository heartRateSamplesRepositoryPowerSync(Ref ref) {
  final db = ref.watch(powerSyncDatabaseProvider).value;
  if (db == null) {
    throw StateError('PowerSync database not initialized');
  }
  return HeartRateSamplesRepository(db);
}

class HeartRateSamplesRepository {
  HeartRateSamplesRepository(this._db);

  final PowerSyncDatabase _db;

  Stream<List<HeartRateSample>> watchSamplesForSession(String sessionId) {
    return _db
        .watch(
          '''
          SELECT * FROM heart_rate_samples
          WHERE session_id = ?
          ORDER BY timestamp ASC
          ''',
          parameters: [sessionId],
        )
        .map((rows) => rows.map(_mapRowToSample).toList());
  }

  Future<List<HeartRateSample>> fetchSamplesForSession(String sessionId) async {
    final rows = await _db.getAll(
      '''
      SELECT * FROM heart_rate_samples
      WHERE session_id = ?
      ORDER BY timestamp ASC
      ''',
      [sessionId],
    );
    return rows.map(_mapRowToSample).toList();
  }

  Future<void> addSample(HeartRateSample sample) async {
    await _db.execute(
      '''
      INSERT INTO heart_rate_samples (
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

  HeartRateSample _mapRowToSample(Map<String, dynamic> row) {
    return HeartRateSample(
      id: row['id'] as String,
      sessionId: row['session_id'] as String,
      timestamp: DateTime.parse(row['timestamp'] as String),
      bpm: row['bpm'] as int,
      energyKcal: (row['energy_kcal'] as num?)?.toDouble(),
      source: row['source'] as String,
    );
  }
}
