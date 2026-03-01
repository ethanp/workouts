import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:workouts/models/activity_calendar_day.dart';
import 'package:workouts/models/activity_item.dart';
import 'package:workouts/models/fitness_run.dart';
import 'package:workouts/models/run_calendar_day.dart';
import 'package:workouts/models/session.dart';
import 'package:workouts/models/session_calendar_day.dart';
import 'package:workouts/providers/unit_system_provider.dart';
import 'package:workouts/services/powersync/powersync_database_provider.dart';
import 'package:workouts/services/repositories/runs_repository_powersync.dart';
import 'package:workouts/services/repositories/session_repository_powersync.dart';
import 'package:workouts/services/repositories/template_repository_powersync.dart';
import 'package:workouts/utils/zone2_calculator.dart';

part 'activity_provider.g.dart';

Stream<T> _pendingStream<T>(Ref ref) {
  final ctrl = StreamController<T>();
  ref.onDispose(ctrl.close);
  return ctrl.stream;
}

@riverpod
Stream<List<ActivityItem>> activityList(Ref ref) {
  final db = ref.watch(powerSyncDatabaseProvider).value;
  if (db == null) return _pendingStream(ref);

  final runsRepo = RunsRepositoryPowerSync(db);
  final sessionRepo = SessionRepositoryPowerSync(
    db,
    ref.watch(templateRepositoryPowerSyncProvider),
  );

  List<FitnessRun>? lastRuns;
  List<Session>? lastSessions;
  final ctrl = StreamController<List<ActivityItem>>();
  ref.onDispose(ctrl.close);

  void emit() {
    if (lastRuns != null && lastSessions != null) {
      final items = <ActivityItem>[
        ...lastRuns!.map((r) => ActivityRun(r)),
        ...lastSessions!
            .where((s) => s.completedAt != null)
            .map((s) => ActivitySession(s)),
      ];
      items.sort((a, b) => b.startedAt.compareTo(a.startedAt));
      ctrl.add(items);
    }
  }

  runsRepo.watchRuns().listen((r) {
    lastRuns = r;
    emit();
  });
  sessionRepo.watchSessions().listen((s) {
    lastSessions = s;
    emit();
  });

  return ctrl.stream;
}

@riverpod
Stream<List<ActivityCalendarDay>> activityCalendarDays(Ref ref) {
  final db = ref.watch(powerSyncDatabaseProvider).value;
  if (db == null) return _pendingStream(ref);

  final runsRepo = RunsRepositoryPowerSync(db);
  final sessionRepo = SessionRepositoryPowerSync(
    db,
    ref.watch(templateRepositoryPowerSyncProvider),
  );

  List<RunCalendarDay>? lastRunDays;
  List<SessionCalendarDay>? lastSessionDays;
  final ctrl = StreamController<List<ActivityCalendarDay>>();
  ref.onDispose(ctrl.close);

  void emit() {
    if (lastRunDays != null && lastSessionDays != null) {
      final byDate = <DateTime, ActivityCalendarDay>{};
      for (final rd in lastRunDays!) {
        byDate[rd.date] = ActivityCalendarDay(
          date: rd.date,
          totalRunDistanceMeters: rd.totalDistanceMeters,
          totalRunDurationSeconds: rd.totalDurationSeconds,
          runZone2Minutes: rd.zone2Minutes,
          runHasHrData: rd.hasHrData,
          runCount: rd.runCount,
          totalSessionDurationSeconds: 0,
          sessionCount: 0,
        );
      }
      for (final sd in lastSessionDays!) {
        byDate.update(
          sd.date,
          (a) => ActivityCalendarDay(
            date: a.date,
            totalRunDistanceMeters: a.totalRunDistanceMeters,
            totalRunDurationSeconds: a.totalRunDurationSeconds,
            runZone2Minutes: a.runZone2Minutes,
            runHasHrData: a.runHasHrData,
            runCount: a.runCount,
            totalSessionDurationSeconds: sd.totalDurationSeconds,
            sessionCount: sd.sessionCount,
          ),
          ifAbsent: () => ActivityCalendarDay(
            date: sd.date,
            totalRunDistanceMeters: 0,
            totalRunDurationSeconds: 0,
            runZone2Minutes: 0,
            runHasHrData: false,
            runCount: 0,
            totalSessionDurationSeconds: sd.totalDurationSeconds,
            sessionCount: sd.sessionCount,
          ),
        );
      }
      final days = byDate.values.toList()..sort((a, b) => a.date.compareTo(b.date));
      ctrl.add(days);
    }
  }

  runsRepo.watchCalendarDays().listen((r) {
    lastRunDays = r;
    emit();
  });
  sessionRepo.watchSessionCalendarDays().listen((s) {
    lastSessionDays = s;
    emit();
  });

  return ctrl.stream;
}

@riverpod
Future<List<ActivityItem>> activityForDate(Ref ref, DateTime date) async {
  final db = ref.watch(powerSyncDatabaseProvider).value;
  if (db == null) return [];

  final runsRepo = RunsRepositoryPowerSync(db);
  final sessionRepo = SessionRepositoryPowerSync(
    db,
    ref.watch(templateRepositoryPowerSyncProvider),
  );

  final runs = await runsRepo.getRunsForDate(date);
  final sessions = await sessionRepo.getSessionsForDate(date);
  final items = <ActivityItem>[
    ...runs.map((r) => ActivityRun(r)),
    ...sessions.map((s) => ActivitySession(s)),
  ];
  items.sort((a, b) => a.startedAt.compareTo(b.startedAt));
  return items;
}

@riverpod
Future<void> activityMetricsBackfill(Ref ref) async {
  final db = ref.watch(powerSyncDatabaseProvider).value;
  if (db == null) return;

  final maxHR = ref.watch(maxHeartRateProvider);
  final bounds = zone2Bounds(maxHR);
  await RunsRepositoryPowerSync(db).backfillMissingMetrics(
    lowerBpm: bounds.lower,
    upperBpm: bounds.upper,
  );
}
