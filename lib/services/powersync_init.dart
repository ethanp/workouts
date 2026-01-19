import 'dart:convert';
import 'dart:io';

import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:powersync/powersync.dart';

import 'powersync_schema.dart';

final _log = Logger('PowerSyncInit');

// Server configuration from .env
String get _powersyncUrl => dotenv.env['POWERSYNC_URL'] ?? '';
String get _postgrestUrl => dotenv.env['POSTGREST_URL'] ?? '';
String get _jwtSecret => dotenv.env['POWERSYNC_JWT_SECRET'] ?? '';

/// Initialize PowerSync database.
Future<PowerSyncDatabase> initPowerSync() async {
  _log.info('Starting PowerSync initialization...');

  // Log environment configuration (without secrets)
  _log.info('PowerSync URL: $_powersyncUrl');
  _log.info('PostgREST URL: $_postgrestUrl');
  _log.info('JWT Secret configured: ${_jwtSecret.isNotEmpty}');

  if (_powersyncUrl.isEmpty || _postgrestUrl.isEmpty || _jwtSecret.isEmpty) {
    final error =
        'Missing required .env configuration. '
        'POWERSYNC_URL=${_powersyncUrl.isEmpty ? "MISSING" : "OK"}, '
        'POSTGREST_URL=${_postgrestUrl.isEmpty ? "MISSING" : "OK"}, '
        'POWERSYNC_JWT_SECRET=${_jwtSecret.isEmpty ? "MISSING" : "OK"}';
    _log.severe(error);
    throw StateError(error);
  }

  final dbPath = await getDatabasePath();
  _log.info('Database path: $dbPath');

  // Check if directory exists
  final dbDir = Directory(p.dirname(dbPath));
  if (!dbDir.existsSync()) {
    _log.info('Creating database directory: ${dbDir.path}');
    dbDir.createSync(recursive: true);
  }

  // Create a logger that forwards to debugPrint for visibility
  final logger = Logger.detached('PowerSync');
  logger.level = kDebugMode ? Level.INFO : Level.WARNING;
  logger.onRecord.listen((record) {
    debugPrint(
      '[${record.level.name}] ${record.loggerName}: ${record.message}',
    );
    if (record.error != null) {
      debugPrint('  Error: ${record.error}');
    }
    if (record.stackTrace != null) {
      debugPrint('  Stack: ${record.stackTrace}');
    }
  });

  try {
    _log.info('Creating PowerSyncDatabase instance...');
    final db = PowerSyncDatabase(schema: schema, path: dbPath, logger: logger);

    _log.info('Initializing database...');
    await db.initialize();
    _log.info('Database initialized successfully');

    _log.info('Connecting to PowerSync service...');
    await reconnectPowerSync(db);
    _log.info('PowerSync connection established');

    return db;
  } catch (e, stack) {
    _log.severe('PowerSync initialization failed', e, stack);
    debugPrint('[PowerSync] FATAL: Initialization failed');
    debugPrint('[PowerSync] Error: $e');
    debugPrint('[PowerSync] Stack trace:\n$stack');
    debugPrint('[PowerSync] Database path: $dbPath');
    debugPrint(
      '[PowerSync] Platform: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}',
    );
    rethrow;
  }
}

/// Reconnect to PowerSync (creates fresh connector).
Future<void> reconnectPowerSync(PowerSyncDatabase db) async {
  await db.connect(
    connector: WorkoutsBackendConnector(_powersyncUrl, _postgrestUrl),
  );
}

Future<String> getDatabasePath() async {
  final dir = await getApplicationDocumentsDirectory();
  return p.join(dir.path, 'powersync.db');
}

/// Generate a JWT token for PowerSync authentication.
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

  return jwt.sign(SecretKey(_jwtSecret), algorithm: JWTAlgorithm.HS256);
}

/// Backend connector for PowerSync.
///
/// Handles authentication and write-back to Postgres via PostgREST.
class WorkoutsBackendConnector extends PowerSyncBackendConnector {
  final String powersyncUrl;
  final String postgrestUrl;

  WorkoutsBackendConnector(this.powersyncUrl, this.postgrestUrl);

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
    final batch = await database.getCrudBatch();
    if (batch == null) return;

    for (final op in batch.crud) {
      await _uploadOperation(op);
    }

    await batch.complete();
  }

  Future<void> _uploadOperation(CrudEntry op) async {
    final table = op.table;
    final data = op.opData;

    try {
      switch (op.op) {
        case UpdateType.put:
          final response = await http.post(
            Uri.parse('$postgrestUrl/$table'),
            headers: {
              'Content-Type': 'application/json',
              'Prefer': 'resolution=merge-duplicates',
            },
            body: jsonEncode({...?data, 'id': op.id}),
          );
          if (response.statusCode >= 400) {
            throw Exception(
              'PostgREST error: ${response.statusCode} ${response.body}',
            );
          }

        case UpdateType.patch:
          await http.patch(
            Uri.parse('$postgrestUrl/$table?id=eq.${op.id}'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(data),
          );

        case UpdateType.delete:
          await http.delete(Uri.parse('$postgrestUrl/$table?id=eq.${op.id}'));
      }
    } catch (e) {
      print('[PowerSync] Upload error for $table ${op.id}: $e');
      rethrow;
    }
  }
}
