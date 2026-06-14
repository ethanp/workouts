import 'dart:async';

import 'package:ethan_sync/ethan_sync.dart';
import 'package:ethan_utils/ethan_utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workouts/app/app.dart';
import 'package:workouts/services/backend/backend_host_probe_scheduler.dart';
import 'package:workouts/services/backend/hostname_notifier.dart';
import 'package:workouts/services/backend/sync_config.dart';
import 'package:workouts/services/notifications/timer_notification_service_provider.dart';
import 'package:workouts/services/powersync/powersync_database_provider.dart';
import 'package:workouts/services/preferences_provider.dart';
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
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      syncConfigProvider.overrideWith((ref) => buildWorkoutsSyncConfig(prefs)),
    ],
  );

  // Probe before runApp so the very first PowerSync connector targets a
  // reachable host — no transient bad-host attempt before the after-first-
  // frame re-probe lands.
  await container.read(hostnameProvider.notifier).refineByTcpProbe();

  // Warm up the local-notification plugin (timezone DB + plugin init) so
  // the first interval-timer start doesn't pay that cost. Permission is
  // still requested lazily inside `scheduleAt` on first use.
  await container.read(timerNotificationServiceProvider).init();

  // Pre-open the local PowerSync DB before runApp so the synchronous
  // `xxxRepositoryPowerSyncProvider` family (which throws when
  // `powerSyncDatabaseProvider.value == null`) never observes the
  // AsyncLoading state. `initPowerSync` is local SQLite open + schema
  // setup; `connectPowerSync` only registers the connector and does not
  // block on network. Failures here are surfaced to the error banner so
  // they're copy-pasteable instead of just rendered as a blank/error
  // first frame.
  try {
    await container.read(powerSyncDatabaseProvider.future);
  } catch (error, stackTrace) {
    _log.error('PowerSync pre-warm failed', error, stackTrace);
    errorBus.add('PowerSync init: $error');
  }

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
