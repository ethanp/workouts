import 'dart:convert';

import 'package:ethan_utils/ethan_utils.dart';
import 'package:powersync/powersync.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:workouts/models/training_influence.dart';
import 'package:workouts/services/powersync/powersync_database_provider.dart';

part 'influences_repository_powersync.g.dart';

class InfluencesRepositoryPowerSync {
  InfluencesRepositoryPowerSync(this._powerSync);

  final PowerSyncDatabase _powerSync;

  Future<List<TrainingInfluence>> fetchInfluences() async {
    await _ensureSeeded();
    final influenceRows = await _powerSync.getAll(
      'SELECT * FROM training_influences ORDER BY name ASC',
    );
    return influenceRows.mapL(TrainingInfluence.fromRow);
  }

  Stream<List<TrainingInfluence>> watchInfluences() {
    // Seed on first access, then watch
    return _ensureSeeded().asStream().asyncExpand((_) {
      return _powerSync
          .watch('SELECT * FROM training_influences ORDER BY name ASC')
          .map(
            (influenceRows) => influenceRows.mapL(TrainingInfluence.fromRow),
          );
    });
  }

  Future<void> _ensureSeeded() async {
    final count = await _powerSync.get(
      'SELECT COUNT(*) as cnt FROM training_influences',
    );
    if ((count['cnt'] as int) == 0) {
      await seedInfluencesIfEmpty();
    }
  }

  Stream<List<TrainingInfluence>> watchActiveInfluences() {
    return _ensureSeeded().asStream().asyncExpand((_) {
      return _powerSync
          .watch(
            'SELECT * FROM training_influences WHERE is_active = 1 ORDER BY name ASC',
          )
          .map(
            (influenceRows) => influenceRows.mapL(TrainingInfluence.fromRow),
          );
    });
  }

  Future<List<TrainingInfluence>> fetchActiveInfluences() async {
    await _ensureSeeded();
    final influenceRows = await _powerSync.getAll(
      'SELECT * FROM training_influences WHERE is_active = 1 ORDER BY name ASC',
    );
    return influenceRows.mapL(TrainingInfluence.fromRow);
  }

  Future<void> toggleInfluence(String id, bool isActive) async {
    final now = DateTime.now().toIso8601String();
    await _powerSync.execute(
      'UPDATE training_influences SET is_active = ?, updated_at = ? WHERE id = ?',
      [isActive ? 1 : 0, now, id],
    );
  }

  Future<void> updateInfluence(TrainingInfluence influence) async {
    final now = DateTime.now().toIso8601String();
    await _powerSync.execute(
      '''
      UPDATE training_influences
      SET name = ?, description = ?, principles = ?, updated_at = ?
      WHERE id = ?
      ''',
      [
        influence.name,
        influence.description,
        jsonEncode(influence.principles),
        now,
        influence.id,
      ],
    );
  }

  Future<void> deleteInfluence(String id) async {
    await _powerSync.execute('DELETE FROM training_influences WHERE id = ?', [
      id,
    ]);
  }

  Future<void> addInfluence(TrainingInfluence influence) async {
    final now = DateTime.now().toIso8601String();
    await _powerSync.execute(
      '''
      INSERT INTO training_influences (
        id, name, description, principles, is_active, created_at, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?)
      ''',
      [
        influence.id,
        influence.name,
        influence.description,
        jsonEncode(influence.principles),
        1,
        now,
        now,
      ],
    );
  }

  Future<void> seedInfluencesIfEmpty() async {
    final count = await _powerSync.get(
      'SELECT COUNT(*) as cnt FROM training_influences',
    );
    if ((count['cnt'] as int) > 0) return;

    final now = DateTime.now().toIso8601String();

    for (final influence in seedInfluences) {
      await _powerSync.execute(
        '''
        INSERT INTO training_influences (
          id, name, description, principles, is_active, created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?)
        ''',
        [
          influence.id,
          influence.name,
          influence.description,
          jsonEncode(influence.principles),
          influence.isActive ? 1 : 0,
          now,
          now,
        ],
      );
    }
  }
}

@riverpod
InfluencesRepositoryPowerSync influencesRepositoryPowerSync(Ref ref) {
  final powerSyncDatabaseAsync = ref.watch(powerSyncDatabaseProvider);
  final powerSyncDatabase = powerSyncDatabaseAsync.value;
  if (powerSyncDatabase == null) {
    throw StateError('PowerSync database not initialized');
  }
  return InfluencesRepositoryPowerSync(powerSyncDatabase);
}
