import 'dart:convert';

import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:powersync/powersync.dart';

import 'powersync_schema.dart';

// Server configuration from .env
String get _powersyncUrl => dotenv.env['POWERSYNC_URL']!;
String get _postgrestUrl => dotenv.env['POSTGREST_URL']!;
String get _jwtSecret => dotenv.env['POWERSYNC_JWT_SECRET']!;

/// Initialize PowerSync database.
Future<PowerSyncDatabase> initPowerSync() async {
  final dbPath = await getDatabasePath();

  // Create a silent logger to suppress verbose FINE logs in debug mode
  final silentLogger = Logger.detached('PowerSync')..level = Level.WARNING;

  final db = PowerSyncDatabase(
    schema: schema,
    path: dbPath,
    logger: silentLogger,
  );

  await db.initialize();

  await reconnectPowerSync(db);

  return db;
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
