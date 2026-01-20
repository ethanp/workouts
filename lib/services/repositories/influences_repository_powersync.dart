import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:powersync/powersync.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:workouts/models/training_influence.dart';
import 'package:workouts/services/powersync_database_provider.dart';

part 'influences_repository_powersync.g.dart';

class InfluencesRepositoryPowerSync {
  InfluencesRepositoryPowerSync(this._db);

  final PowerSyncDatabase _db;

  Future<List<TrainingInfluence>> fetchInfluences() async {
    await _ensureSeeded();
    final rows = await _db.getAll(
      'SELECT * FROM training_influences ORDER BY name ASC',
    );
    return rows.map(_influenceFromRow).toList();
  }

  Stream<List<TrainingInfluence>> watchInfluences() {
    // Seed on first access, then watch
    return _ensureSeeded().asStream().asyncExpand((_) {
      return _db
          .watch('SELECT * FROM training_influences ORDER BY name ASC')
          .map((rows) => rows.map(_influenceFromRow).toList());
    });
  }

  Future<void> _ensureSeeded() async {
    final count = await _db.get('SELECT COUNT(*) as cnt FROM training_influences');
    if ((count['cnt'] as int) == 0) {
      await seedInfluencesIfEmpty();
    }
  }

  Stream<List<TrainingInfluence>> watchActiveInfluences() {
    return _ensureSeeded().asStream().asyncExpand((_) {
      return _db
          .watch(
            'SELECT * FROM training_influences WHERE is_active = 1 ORDER BY name ASC',
          )
          .map((rows) => rows.map(_influenceFromRow).toList());
    });
  }

  Future<List<TrainingInfluence>> fetchActiveInfluences() async {
    await _ensureSeeded();
    final rows = await _db.getAll(
      'SELECT * FROM training_influences WHERE is_active = 1 ORDER BY name ASC',
    );
    return rows.map(_influenceFromRow).toList();
  }

  Future<void> toggleInfluence(String id, bool isActive) async {
    final now = DateTime.now().toIso8601String();
    await _db.execute(
      'UPDATE training_influences SET is_active = ?, updated_at = ? WHERE id = ?',
      [isActive ? 1 : 0, now, id],
    );
  }

  Future<void> seedInfluencesIfEmpty() async {
    final count = await _db.get('SELECT COUNT(*) as cnt FROM training_influences');
    if ((count['cnt'] as int) > 0) return;

    final now = DateTime.now().toIso8601String();

    for (final influence in seedInfluences) {
      await _db.execute(
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

  TrainingInfluence _influenceFromRow(Map<String, dynamic> row) {
    final principlesJson = row['principles'] as String? ?? '[]';
    final principles = (jsonDecode(principlesJson) as List).cast<String>();

    return TrainingInfluence(
      id: row['id'] as String,
      name: row['name'] as String,
      description: (row['description'] as String?) ?? '',
      principles: principles,
      isActive: (row['is_active'] as int?) == 1,
      createdAt: row['created_at'] != null
          ? DateTime.tryParse(row['created_at'] as String)
          : null,
      updatedAt: row['updated_at'] != null
          ? DateTime.tryParse(row['updated_at'] as String)
          : null,
    );
  }
}

@riverpod
InfluencesRepositoryPowerSync influencesRepositoryPowerSync(Ref ref) {
  final dbAsync = ref.watch(powerSyncDatabaseProvider);
  final db = dbAsync.value;
  if (db == null) {
    throw StateError('PowerSync database not initialized');
  }
  return InfluencesRepositoryPowerSync(db);
}
