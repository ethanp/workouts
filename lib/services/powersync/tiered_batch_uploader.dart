import 'dart:math' as math;

import 'package:http/http.dart' as http;
import 'package:powersync/powersync.dart';
import 'package:workouts/services/powersync/postgrest_uploader.dart';

/// Uploads a [CrudBatch] in FK-safe tier order with concurrent chunking.
///
/// Tables are grouped into tiers via [_UploadGraph] so that parent rows
/// (e.g. exercises, runs) are uploaded before the child rows that reference
/// them. Within each tier, ops are uploaded in concurrent chunks of
/// [_chunkConcurrency].
class TieredBatchUploader {
  TieredBatchUploader(this._uploader);

  final PostgRestUploader _uploader;
  static const _chunkConcurrency = 30;

  /// Returns (uploaded, discarded) counts.
  Future<(int, int)> upload(CrudBatch batch) async {
    var uploaded = 0;
    var discarded = 0;

    void tally(bool wasDiscarded) {
      if (wasDiscarded) {
        discarded++;
      } else {
        uploaded++;
      }
    }

    final client = http.Client();
    try {
      for (final tier in _UploadGraph.tiers) {
        final tierOps =
            batch.crud.where((op) => tier.contains(op.table)).toList();
        await _uploadChunked(tierOps, client, tally);
      }

      final unknownOps = batch.crud
          .where((op) => !_UploadGraph.allTables.contains(op.table))
          .toList();
      await _uploadChunked(unknownOps, client, tally);
    } finally {
      client.close();
    }

    return (uploaded, discarded);
  }

  Future<void> _uploadChunked(
    List<CrudEntry> ops,
    http.Client client,
    void Function(bool) tally,
  ) async {
    for (var i = 0; i < ops.length; i += _chunkConcurrency) {
      final chunk =
          ops.sublist(i, math.min(i + _chunkConcurrency, ops.length));
      final results = await Future.wait(
        chunk.map((op) => _uploader.upload(op, client)),
      );
      results.forEach(tally);
    }
  }
}

/// FK dependency graph for upload ordering, derived from init.sql.
///
/// Each table declares the tables it depends on via foreign keys.
/// [tiers] is computed via topological sort so that every table in tier N
/// only references tables in tiers 0..N-1.
class _UploadGraph {
  _UploadGraph._();

  /// table -> tables it holds foreign keys to.
  static const dependencies = <String, Set<String>>{
    'exercises': {},
    'workout_templates': {},
    'fitness_goals': {},
    'cardio_workouts': {},
    'training_influences': {},
    'workout_blocks': {'workout_templates'},
    'sessions': {'workout_templates'},
    'background_notes': {'fitness_goals'},
    'cardio_route_points': {'cardio_workouts'},
    'cardio_heart_rate_samples': {'cardio_workouts'},
    'cardio_best_efforts': {'cardio_workouts'},
    'workout_block_exercises': {'workout_blocks', 'exercises'},
    'session_blocks': {'sessions'},
    'session_notes': {'sessions'},
    'heart_rate_samples': {'sessions'},
    'session_block_exercises': {'session_blocks', 'exercises'},
    'session_set_logs': {'session_blocks', 'exercises'},
  };

  static final tiers = _topologicalTiers();
  static final allTables = dependencies.keys.toSet();

  static List<Set<String>> _topologicalTiers() {
    final remaining = Map.of(dependencies);
    final placed = <String>{};
    final result = <Set<String>>[];

    while (remaining.isNotEmpty) {
      final tier = remaining.entries
          .where((e) => e.value.every(placed.contains))
          .map((e) => e.key)
          .toSet();
      if (tier.isEmpty) {
        throw StateError('Circular FK dependency in: ${remaining.keys}');
      }
      result.add(tier);
      placed.addAll(tier);
      tier.forEach(remaining.remove);
    }

    return result;
  }
}
