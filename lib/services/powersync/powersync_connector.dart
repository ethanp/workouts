import 'dart:convert';
import 'dart:math' as math;

import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:powersync/powersync.dart';

final _log = Logger('PowerSyncConnector');

String _jwtSecret() => dotenv.env['POWERSYNC_JWT_SECRET'] ?? '';

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
  WorkoutsBackendConnector(this.powersyncUrl, this.postgrestUrl);

  final String powersyncUrl;
  final String postgrestUrl;

  // Run-table ops must precede child-table ops in every batch to satisfy FK
  // constraints (run_route_points.run_id and run_heart_rate_samples.run_id
  // reference runs.id). Child ops within a batch are uploaded concurrently.
  static const _childUploadConcurrency = 30;

  static const _runChildTables = {'run_route_points', 'run_heart_rate_samples'};

  // Natural unique keys used by PostgREST to resolve duplicate-key conflicts
  // without generating a DELETE event on the server.
  static const _childTableConflictColumns = {
    'run_route_points': 'run_id,point_index',
    'run_heart_rate_samples': 'run_id,timestamp',
  };

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
    if (batch == null) return;

    final totalInBatch = batch.crud.length;
    final remainingRows = await database.execute(
      'SELECT COUNT(*) AS cnt FROM ps_crud',
    );
    final totalRemaining = remainingRows.first['cnt'] as int? ?? 0;

    _log.info(
      'Processing upload batch: $totalInBatch ops in this batch, '
      '$totalRemaining total remaining in queue.',
    );

    var uploaded = 0;
    var discarded = 0;

    // Reuse a single HTTP client across all ops so connections are kept alive
    // and pooled rather than opened/closed per request.
    final client = http.Client();
    try {
      final runOps = batch.crud.where((op) => op.table == 'runs').toList();
      final childOps = batch.crud.where((op) => op.table != 'runs').toList();

      for (final op in runOps) {
        if (await _uploadOperation(op, client)) {
          discarded++;
        } else {
          uploaded++;
        }
      }

      for (var i = 0; i < childOps.length; i += _childUploadConcurrency) {
        final chunk = childOps.sublist(
          i,
          math.min(i + _childUploadConcurrency, childOps.length),
        );
        final results = await Future.wait(
          chunk.map((op) => _uploadOperation(op, client)),
        );
        for (final wasDiscarded in results) {
          if (wasDiscarded) {
            discarded++;
          } else {
            uploaded++;
          }
        }
      }
    } finally {
      client.close();
    }

    await batch.complete();

    _log.info(
      'Batch complete: $uploaded uploaded, $discarded discarded. '
      '${totalRemaining - totalInBatch} ops still queued.',
    );
  }

  /// Returns true if the entry was discarded rather than uploaded.
  Future<bool> _uploadOperation(CrudEntry op, http.Client client) async {
    final table = op.table;
    final data = op.opData;

    try {
      switch (op.op) {
        case UpdateType.put:
          final conflictColumns = _childTableConflictColumns[table];
          final putUrl = conflictColumns != null
              ? '$postgrestUrl/$table?on_conflict=$conflictColumns'
              : '$postgrestUrl/$table';
          final response = await client.post(
            Uri.parse(putUrl),
            headers: {
              'Content-Type': 'application/json',
              'Prefer': 'resolution=merge-duplicates',
            },
            body: jsonEncode({...?data, 'id': op.id}),
          );
          if (response.statusCode == 409) {
            final body = response.body;
            if (body.contains('"23505"') && table == 'runs') {
              // Server has this run under an old random UUID. Delete it
              // (cascades child rows) then reinsert with the deterministic UUID.
              final externalId = data?['external_workout_id'] as String?;
              if (externalId != null) {
                await client.delete(
                  Uri.parse(
                    '$postgrestUrl/$table?external_workout_id=eq.$externalId',
                  ),
                  headers: {'Content-Type': 'application/json'},
                );
                final retryResponse = await client.post(
                  Uri.parse('$postgrestUrl/$table'),
                  headers: {
                    'Content-Type': 'application/json',
                    'Prefer': 'resolution=merge-duplicates',
                  },
                  body: jsonEncode({...?data, 'id': op.id}),
                );
                if (retryResponse.statusCode >= 400) {
                  throw Exception(
                    'PostgREST error on retry after DELETE: '
                    '${retryResponse.statusCode} ${retryResponse.body}',
                  );
                }
              }
            } else if (body.contains('"23503"') &&
                _runChildTables.contains(table)) {
              // FK violation: child row references a run_id that no longer
              // exists on the server. Discard — modifying the DB here would
              // generate new CRUD entries and cause an upload loop.
              return true;
            } else {
              throw Exception('PostgREST error: ${response.statusCode} $body');
            }
          } else if (response.statusCode >= 400) {
            throw Exception(
              'PostgREST error: ${response.statusCode} ${response.body}',
            );
          }

        case UpdateType.patch:
          await client.patch(
            Uri.parse('$postgrestUrl/$table?id=eq.${op.id}'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(data),
          );

        case UpdateType.delete:
          await client.delete(
            Uri.parse('$postgrestUrl/$table?id=eq.${op.id}'),
          );
      }
    } catch (e) {
      _log.severe('Upload error for $table ${op.id}: $e');
      rethrow;
    }
    return false;
  }
}
