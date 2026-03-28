import 'package:ethan_utils/ethan_utils.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workouts/app/app.dart';
import 'package:workouts/providers/unit_system_provider.dart';

const _log = ELogger('Main');

Future<void> main() async {
  _log.log('App starting...');

  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load();
    _log.log('.env loaded');
  } catch (error, stackTrace) {
    _log.error('Failed to load .env file', error, stackTrace);
  }

  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const WorkoutsApp(),
    ),
  );
}
