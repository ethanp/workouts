import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:logging/logging.dart';
import 'package:powersync/powersync.dart';
import 'package:workouts/services/powersync/postgrest_uploader.dart';
import 'package:workouts/services/powersync/tiered_batch_uploader.dart';

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
      : _batchUploader =
            TieredBatchUploader(PostgRestUploader(postgrestUrl));

  final String powersyncUrl;
  final TieredBatchUploader _batchUploader;

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

    final (uploaded, discarded) = await _batchUploader.upload(batch);
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
    final rows = await database.execute('SELECT COUNT(*) AS cnt FROM ps_crud');
    return rows.first['cnt'] as int? ?? 0;
  }
}
