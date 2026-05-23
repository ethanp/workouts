import 'dart:async';

import 'package:ethan_utils/ethan_utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workouts/app/app.dart';
import 'package:workouts/features/settings/unit_system_provider.dart';
import 'package:workouts/services/backend/backend_host_probe_scheduler.dart';
import 'package:workouts/services/backend/hostname_notifier.dart';
import 'package:workouts/utils/error_bus.dart';

const _log = ELogger('Main');

Future<void> main() async {
  _log.log('App starting...');

  await runZonedGuarded(_bootstrap, _reportUncaughtZoneError);
}

Future<void> _bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  _installGlobalErrorHandlers();

  try {
    await dotenv.load();
    _log.log('.env loaded');
  } catch (error, stackTrace) {
    _log.error('Failed to load .env file', error, stackTrace);
  }

  final prefs = await SharedPreferences.getInstance();

  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );

  // Probe before runApp so the very first PowerSync connector targets a
  // reachable host — no transient bad-host attempt before the after-first-
  // frame re-probe lands.
  await container.read(hostnameProvider.notifier).refineByTcpProbe();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const WorkoutsApp(),
    ),
  );

  // Re-probe after first frame to catch e.g. networking that took a moment
  // to come up (Tailscale just-launched, Wi-Fi association still settling).
  BackendHostProbeScheduler(container).scheduleAfterFirstFrame();
}

void _installGlobalErrorHandlers() {
  final priorFlutterErrorHandler = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    _reportError(
      'Flutter framework error',
      details.exceptionAsString(),
      details.exception,
      details.stack,
    );
    if (priorFlutterErrorHandler != null) priorFlutterErrorHandler(details);
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    _reportError('Uncaught async error', error.toString(), error, stack);
    return true;
  };
}

void _reportUncaughtZoneError(Object error, StackTrace stack) {
  _reportError('Uncaught zone error', error.toString(), error, stack);
}

void _reportError(
  String label,
  String message,
  Object error,
  StackTrace? stack,
) {
  _log.error(label, error, stack);
  errorBus.add('$label: $message');
}
