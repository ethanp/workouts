import 'dart:io';

import 'package:ethan_utils/ethan_utils.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

const _log = ELogger('TimerNotif');

/// Single-slot iOS local-notification scheduler for the workout interval
/// timer. Owns:
/// - one-time plugin initialization
/// - the timezone database init required by `zonedSchedule`
/// - lazy iOS notification-permission request on first `scheduleAt` call
/// - a fixed notification id, since the [ActiveExerciseTimer] coordinator
///   already enforces that only one interval timer can run at a time
///
/// Designed to be a no-op on non-iOS platforms (the app ships iOS-only,
/// matching HealthKit/Watch guards used elsewhere) and to silently no-op
/// when the user denies notification permission, so the in-app countdown
/// is never gated on the alert.
class TimerNotificationService {
  TimerNotificationService();

  static const int _notificationId = 1001;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool _permissionRequested = false;
  bool _permissionGranted = false;

  /// Idempotent: safe to call from app boot. Initializes the timezone
  /// database (needed for `zonedSchedule`) and the FLN plugin without
  /// requesting iOS permissions yet — that's deferred to first
  /// [scheduleAt] so the prompt feels contextual.
  Future<void> init() async {
    if (_initialized) return;
    if (!Platform.isIOS) {
      _initialized = true;
      return;
    }
    try {
      tz_data.initializeTimeZones();
      final String localTimeZone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(localTimeZone));
      await _plugin.initialize(
        settings: const InitializationSettings(
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
      );
      _initialized = true;
    } catch (error, stackTrace) {
      _log.error('init failed', error, stackTrace);
    }
  }

  /// Schedules the single timer notification to fire at [endsAt]. Cancels
  /// any prior scheduled notification first so adjust/resume flows don't
  /// leave stale alerts behind. On the very first call, prompts for
  /// notification permission; if the user denies, this and all future
  /// calls become no-ops.
  Future<void> scheduleAt({
    required DateTime endsAt,
    required String body,
  }) async {
    if (!Platform.isIOS) return;
    await init();
    await _ensurePermission();
    if (!_permissionGranted) return;
    if (!endsAt.isAfter(DateTime.now())) return;
    try {
      await _plugin.cancel(id: _notificationId);
      await _plugin.zonedSchedule(
        id: _notificationId,
        title: 'Workouts',
        body: body,
        scheduledDate: tz.TZDateTime.from(endsAt, tz.local),
        notificationDetails: const NotificationDetails(
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentSound: true,
            interruptionLevel: InterruptionLevel.timeSensitive,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } catch (error, stackTrace) {
      _log.error('scheduleAt failed', error, stackTrace);
    }
  }

  /// Cancels the pending timer notification, if any. Safe to call when
  /// none is scheduled.
  Future<void> cancel() async {
    if (!Platform.isIOS) return;
    if (!_initialized) return;
    try {
      await _plugin.cancel(id: _notificationId);
    } catch (error, stackTrace) {
      _log.error('cancel failed', error, stackTrace);
    }
  }

  Future<void> _ensurePermission() async {
    if (_permissionRequested) return;
    _permissionRequested = true;
    try {
      final IOSFlutterLocalNotificationsPlugin? iosPlugin = _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>();
      final bool? granted = await iosPlugin?.requestPermissions(
        alert: true,
        sound: true,
      );
      _permissionGranted = granted ?? false;
    } catch (error, stackTrace) {
      _log.error('permission request failed', error, stackTrace);
      _permissionGranted = false;
    }
  }
}
