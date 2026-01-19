import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:workouts/app/app.dart';

Future<void> main() async {
  // Set up logging first
  _setupLogging();

  final log = Logger('Main');
  log.info('App starting...');

  WidgetsFlutterBinding.ensureInitialized();
  log.info('Flutter binding initialized');

  try {
    await dotenv.load();
    log.info('.env loaded successfully');
    log.fine('POWERSYNC_URL: ${dotenv.env['POWERSYNC_URL']}');
    log.fine('POSTGREST_URL: ${dotenv.env['POSTGREST_URL']}');
  } catch (e, stack) {
    log.severe('Failed to load .env file', e, stack);
    // Continue anyway - will fail later with clearer error
  }

  runApp(const ProviderScope(child: WorkoutsApp()));
}

void _setupLogging() {
  Logger.root.level = kDebugMode ? Level.ALL : Level.WARNING;
  Logger.root.onRecord.listen((record) {
    final emoji = switch (record.level) {
      Level.SEVERE => '🔴',
      Level.WARNING => '🟡',
      Level.INFO => '🔵',
      _ => '⚪',
    };
    debugPrint('$emoji [${record.loggerName}] ${record.message}');
    if (record.error != null) {
      debugPrint('   Error: ${record.error}');
    }
    if (record.stackTrace != null && record.level >= Level.WARNING) {
      debugPrint('   Stack: ${record.stackTrace}');
    }
  });
}
