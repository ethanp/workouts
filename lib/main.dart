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

String _pad2(int n) => n.toString().padLeft(2, '0');

void _setupLogging() {
  Logger.root.level = kDebugMode ? Level.ALL : Level.WARNING;
  Logger.root.onRecord.listen((record) {
    final emojiByLevel = <Level, String>{
      Level.ALL: '⚪',
      Level.FINEST: '🔵',
      Level.FINER: '🔵',
      Level.FINE: '🔵',
      Level.CONFIG: '🔵',
      Level.INFO: '🟢',
      Level.WARNING: '🟡',
      Level.SEVERE: '🔴',
      Level.SHOUT: '🟣',
      Level.OFF: '⚫',
    };
    final emoji = emojiByLevel[record.level];
    if (emoji == null) {
      throw StateError('Unhandled log level: ${record.level.name}');
    }
    final t = record.time;
    final ts =
        '${t.year % 100}${_pad2(t.month)}${_pad2(t.day)}'
        '-${_pad2(t.hour)}:${_pad2(t.minute)}:${_pad2(t.second)}'
        ':${(t.millisecond ~/ 100)}';
    debugPrint('$emoji $ts [${record.loggerName}] ${record.message}');
    if (record.error != null) {
      debugPrint('   Error: ${record.error}');
    }
    if (record.stackTrace != null && record.level >= Level.WARNING) {
      debugPrint('   Stack: ${record.stackTrace}');
    }
  });
}
