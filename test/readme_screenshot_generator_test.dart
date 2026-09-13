import 'dart:convert';
import 'dart:io';

import 'package:ethan_ui/ethan_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workouts/features/cardio/cardio_provider.dart';
import 'package:workouts/features/history/activity_provider.dart';
import 'package:workouts/features/history/history_screen.dart';
import 'package:workouts/models/activity_calendar_day.dart';
import 'package:workouts/models/activity_item.dart';
import 'package:workouts/models/cardio_best_effort.dart';
import 'package:workouts/models/cardio_calendar_day.dart';
import 'package:workouts/models/cardio_workout.dart';
import 'package:workouts/models/hr_zone_time.dart';
import 'package:workouts/providers/sync_provider.dart';
import 'package:workouts/services/powersync/powersync_database_provider.dart';
import 'package:workouts/utils/run_formatting.dart';

const _phoneSize = Size(390, 844);

late _LocalHistorySnapshot _readmeHistory;

void main() {
  setUpAll(() async {
    await ETheme.loadFontsForWidgetTests();
    _readmeHistory = _LocalHistorySnapshot.load();
  });

  testWidgets('writes History charts for README', (tester) async {
    await _writeHistoryReadmeScreenshot(
      tester,
      screenshotFilename: 'history-charts.png',
    );
  });

  testWidgets('writes History list for README', (tester) async {
    await _writeHistoryReadmeScreenshot(
      tester,
      tabLabel: 'List',
      screenshotFilename: 'history.png',
    );
  });

  testWidgets('writes History calendar for README', (tester) async {
    await _writeHistoryReadmeScreenshot(
      tester,
      tabLabel: 'Calendar',
      screenshotFilename: 'history-calendar.png',
    );
  });
}

Future<void> _writeHistoryReadmeScreenshot(
  WidgetTester tester, {
  String? tabLabel,
  required String screenshotFilename,
}) async {
  debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.binding.setSurfaceSize(_phoneSize);

  try {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activityListProvider.overrideWith(
            (ref) => Stream.value(_readmeHistory.activityList),
          ),
          activityCalendarDaysProvider.overrideWith(
            (ref) => Stream.value(_readmeHistory.calendarDays),
          ),
          cardioWorkoutsProvider.overrideWith(
            (ref) => Stream.value(_readmeHistory.cardioWorkouts),
          ),
          cardioBestEffortsProvider.overrideWith(
            (ref) => Stream.value(_readmeHistory.bestEfforts),
          ),
          powerSyncDatabaseProvider.overrideWith(
            (ref) => Future<Never>.error(
              StateError('unused in README screenshot'),
            ),
          ),
          syncStateProvider.overrideWith((ref) => SyncState.synced),
        ],
        child: MaterialApp(
          theme: ETheme.material3Dark,
          debugShowCheckedModeBanner: false,
          home: EScaffoldShell(
            contentMaxWidth: double.infinity,
            bottomBar: ETabBar(
              selectedIndex: 0,
              tabs: const [
                ETab(icon: Icons.history, label: 'History'),
                ETab(icon: Icons.menu_book_outlined, label: 'Library'),
                ETab(icon: Icons.settings_outlined, label: 'Settings'),
              ],
              onSelected: (_) {},
            ),
            body: const ColoredBox(
              color: EColors.background,
              child: HistoryScreen(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    if (tabLabel != null) {
      await tester.tap(find.text(tabLabel));
      await tester.pumpAndSettle();
    }
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../screenshots/$screenshotFilename'),
    );
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}

class _LocalHistorySnapshot {
  const _LocalHistorySnapshot({
    required this.cardioWorkouts,
    required this.calendarDays,
    required this.bestEfforts,
  });

  final List<CardioWorkout> cardioWorkouts;
  final List<ActivityCalendarDay> calendarDays;
  final List<CardioBestEffort> bestEfforts;

  List<ActivityItem> get activityList => [
    for (final workout in cardioWorkouts) ActivityCardio(workout),
  ];

  static _LocalHistorySnapshot load() {
    final dbPath = _mostRecentlyWrittenPowerSyncFile().path;
    final workouts = _query(dbPath, _cardioWorkoutsSql)
        .map(_intsFromSqliteJson)
        .map(CardioWorkout.fromRow)
        .toList();
    final calendarDays = _query(dbPath, _calendarDaysSql)
        .map(_intsFromSqliteJson)
        .map(CardioCalendarDay.fromRow)
        .map(_activityDayFromCardio)
        .toList();
    final bestEfforts = [
      for (final row in _query(dbPath, _bestEffortsSql).map(_intsFromSqliteJson))
        if (DistanceBucket.fromMeters((row['distance_meters'] as num).toDouble()) !=
            null)
          CardioBestEffort.fromRow(row),
    ];
    return _LocalHistorySnapshot(
      cardioWorkouts: workouts,
      calendarDays: calendarDays,
      bestEfforts: bestEfforts,
    );
  }

  static ActivityCalendarDay _activityDayFromCardio(CardioCalendarDay day) =>
      ActivityCalendarDay(
        date: day.date,
        outdoorRunDistanceMeters: day.outdoorRunDistanceMeters,
        totalCardioDurationSeconds: day.totalDurationSeconds,
        cardioZoneTime: day.zoneTime,
        cardioHasHrData: day.hasHrData,
        cardioCount: day.workoutCount,
        totalSessionDurationSeconds: 0,
        sessionZoneTime: HrZoneTime.zero,
        sessionCount: 0,
      );

  static List<Map<String, dynamic>> _query(String dbPath, String sql) {
    final result = Process.runSync('sqlite3', ['-json', dbPath, sql]);
    if (result.exitCode != 0) {
      throw StateError('sqlite3 failed: ${result.stderr}');
    }
    final stdout = result.stdout.toString().trim();
    if (stdout.isEmpty) return const [];
    return (jsonDecode(stdout) as List<dynamic>).cast<Map<String, dynamic>>();
  }

  static Map<String, dynamic> _intsFromSqliteJson(Map<String, dynamic> row) {
    return {
      for (final entry in row.entries)
        entry.key: switch (entry.value) {
          final double number when number == number.roundToDouble() =>
            number.toInt(),
          _ => entry.value,
        },
    };
  }

  static const _cardioWorkoutsSql = '''
        SELECT
          w.*,
          COALESCE(m.zone1_seconds, 0) AS zone1_seconds,
          COALESCE(m.zone2_seconds, 0) AS zone2_seconds,
          COALESCE(m.zone3_seconds, 0) AS zone3_seconds,
          COALESCE(m.zone4_seconds, 0) AS zone4_seconds,
          COALESCE(m.zone5_seconds, 0) AS zone5_seconds,
          COALESCE(m.has_hr_samples, 0) AS has_hr_samples,
          m.pace_seconds_per_mile,
          m.meters_per_heartbeat,
          m.cardiac_drift_percent,
          COALESCE(m.has_distance_samples, 0) AS has_distance_samples,
          m.distance_origin,
          m.fitness_confidence
        FROM cardio_workouts w
        LEFT JOIN cardio_computed_metrics m ON m.id = w.id
        ORDER BY w.started_at DESC
        ''';

  static const _calendarDaysSql = '''
        SELECT
          DATE(w.started_at, 'localtime') AS day,
          COALESCE(SUM(CASE WHEN w.activity_type = 'outdoorRun' THEN w.distance_meters END), 0) AS outdoor_run_distance_meters,
          SUM(w.duration_seconds)           AS total_duration_seconds,
          COALESCE(SUM(m.zone1_seconds), 0) AS total_zone1_seconds,
          COALESCE(SUM(m.zone2_seconds), 0) AS total_zone2_seconds,
          COALESCE(SUM(m.zone3_seconds), 0) AS total_zone3_seconds,
          COALESCE(SUM(m.zone4_seconds), 0) AS total_zone4_seconds,
          COALESCE(SUM(m.zone5_seconds), 0) AS total_zone5_seconds,
          MAX(COALESCE(m.has_hr_samples, 0)) AS has_hr_data,
          COUNT(w.id)                       AS workout_count
        FROM cardio_workouts w
        LEFT JOIN cardio_computed_metrics m ON m.id = w.id
        GROUP BY day
        ORDER BY day ASC
        ''';

  static const _bestEffortsSql = '''
        SELECT be.distance_meters, be.elapsed_seconds, w.started_at, w.activity_type
        FROM cardio_best_efforts be
        JOIN cardio_workouts w ON w.id = be.workout_id
        ORDER BY w.started_at ASC
        ''';

  static File _mostRecentlyWrittenPowerSyncFile() {
    final home = Platform.environment['HOME'];
    if (home == null || home.isEmpty) {
      throw StateError('HOME is unset; cannot find the local workouts DB.');
    }
    final found = Process.runSync('find', [
      '$home/Documents',
      '$home/Library/Developer/CoreSimulator/Devices',
      '-name',
      'powersync.db',
    ]);
    if (found.exitCode != 0) {
      throw StateError('find powersync.db failed: ${found.stderr}');
    }
    final paths = found.stdout
        .toString()
        .split('\n')
        .map((path) => path.trim())
        .where((path) => path.isNotEmpty)
        .map(File.new)
        .where((file) => file.existsSync())
        .toList();
    if (paths.isEmpty) {
      throw StateError(
        'No local powersync.db found. Run Workouts on this Mac or the '
        'simulator once so README screenshots can read real history.',
      );
    }
    paths.sort(
      (left, right) =>
          right.statSync().modified.compareTo(left.statSync().modified),
    );
    return paths.first;
  }
}
