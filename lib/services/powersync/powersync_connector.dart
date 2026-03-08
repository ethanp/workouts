import 'dart:math' as math;

import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:powersync/powersync.dart';
import 'package:workouts/services/powersync/postgrest_uploader.dart';

final _log = Logger('PowerSyncConnector');

String _jwtSecret() => dotenv.env['POWERSYNC_JWT_SECRET'] ?? '';

/// Generates an HS256 JWT for PowerSync authentication.
///
/// Claims follow the PowerSync custom auth spec:
/// https://docs.powersync.com/installation/authentication-setup/custom
String generatePowerSyncToken({String userId = 'default'}) {
  final jwt = JWT(
    {
      'sub': userId,
      'aud': 'powersync',
      'iat': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'exp':
          DateTime.now()
              .add(const Duration(hours: 24))
              .millisecondsSinceEpoch ~/
          1000,
    },
    header: {'kid': 'workouts-dev-key'},
  );
  return jwt.sign(SecretKey(_jwtSecret()), algorithm: JWTAlgorithm.HS256);
}

class WorkoutsBackendConnector extends PowerSyncBackendConnector {
  WorkoutsBackendConnector(this.powersyncUrl, String postgrestUrl)
      : _uploader = PostgRestUploader(postgrestUrl);

  final String powersyncUrl;
  final PostgRestUploader _uploader;

  static const _chunkConcurrency = 30;

  @override
  Future<PowerSyncCredentials?> fetchCredentials() async {
    final token = generatePowerSyncToken();
    return PowerSyncCredentials(
      endpoint: powersyncUrl,
      token: token,
      userId: 'default',
    );
  }

  @override
  Future<void> uploadData(PowerSyncDatabase database) async {
    final batch = await database.getCrudBatch(limit: 1000);
    if (batch == null) {
      _logEmptyBatch(await _queueDepth(database));
      return;
    }

    final queueDepth = await _queueDepth(database);
    _log.info(
      'Processing upload batch: ${batch.crud.length} ops, '
      '$queueDepth total remaining in queue.',
    );

    final (uploaded, discarded) = await _processBatch(batch);
    await batch.complete();

    _log.info(
      'Batch complete: $uploaded uploaded, $discarded discarded. '
      '${queueDepth - batch.crud.length} ops still queued.',
    );
  }

  void _logEmptyBatch(int queueDepth) {
    if (queueDepth == 0) {
      _log.info('Upload: no batch, queue empty.');
    } else {
      _log.info(
        'Upload: no batch available, but $queueDepth ops still in queue.',
      );
    }
  }

  Future<int> _queueDepth(PowerSyncDatabase database) async {
    final rows = await database.execute(
      'SELECT COUNT(*) AS cnt FROM ps_crud',
    );
    return rows.first['cnt'] as int? ?? 0;
  }

  /// Uploads ops tier-by-tier so FK parent rows exist before their children.
  /// Within each tier, ops are uploaded in concurrent chunks.
  Future<(int, int)> _processBatch(CrudBatch batch) async {
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

      final knownTables = _UploadGraph.allTables;
      final unknownOps =
          batch.crud.where((op) => !knownTables.contains(op.table)).toList();
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
      final chunk = ops.sublist(
        i,
        math.min(i + _chunkConcurrency, ops.length),
      );
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

  /// table → tables it holds foreign keys to.
  static const dependencies = <String, Set<String>>{
    'exercises': {},
    'workout_templates': {},
    'fitness_goals': {},
    'runs': {},
    'training_influences': {},
    'workout_blocks': {'workout_templates'},
    'sessions': {'workout_templates'},
    'background_notes': {'fitness_goals'},
    'run_route_points': {'runs'},
    'run_heart_rate_samples': {'runs'},
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
