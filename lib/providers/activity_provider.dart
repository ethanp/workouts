import 'dart:async';

import 'package:flutter/material.dart' show DateTimeRange;
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
import 'package:workouts/utils/training_load_calculator.dart';

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
      for (final runDay in lastRunDays!) {
        byDate[runDay.date] = ActivityCalendarDay(
          date: runDay.date,
          totalRunDistanceMeters: runDay.totalDistanceMeters,
          totalRunDurationSeconds: runDay.totalDurationSeconds,
          runZone2Minutes: runDay.zone2Minutes,
          runTrimp: runDay.trimp,
          runHasHrData: runDay.hasHrData,
          runCount: runDay.runCount,
          totalSessionDurationSeconds: 0,
          sessionZone2Minutes: 0,
          sessionTrimp: 0,
          sessionCount: 0,
        );
      }
      for (final sessionDay in lastSessionDays!) {
        byDate.update(
          sessionDay.date,
          (existing) => ActivityCalendarDay(
            date: existing.date,
            totalRunDistanceMeters: existing.totalRunDistanceMeters,
            totalRunDurationSeconds: existing.totalRunDurationSeconds,
            runZone2Minutes: existing.runZone2Minutes,
            runTrimp: existing.runTrimp,
            runHasHrData: existing.runHasHrData,
            runCount: existing.runCount,
            totalSessionDurationSeconds: sessionDay.totalDurationSeconds,
            sessionZone2Minutes: sessionDay.zone2Minutes,
            sessionTrimp: sessionDay.trimp,
            sessionCount: sessionDay.sessionCount,
          ),
          ifAbsent: () => ActivityCalendarDay(
            date: sessionDay.date,
            totalRunDistanceMeters: 0,
            totalRunDurationSeconds: 0,
            runZone2Minutes: 0,
            runTrimp: 0,
            runHasHrData: false,
            runCount: 0,
            totalSessionDurationSeconds: sessionDay.totalDurationSeconds,
            sessionZone2Minutes: sessionDay.zone2Minutes,
            sessionTrimp: sessionDay.trimp,
            sessionCount: sessionDay.sessionCount,
          ),
        );
      }
      final days = byDate.values.toList()
        ..sort((dayA, dayB) => dayA.date.compareTo(dayB.date));
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

/// Shared display date range derived from activity data.
/// All charts should use this so their x-axes are aligned.
@riverpod
DateTimeRange? chartDateRange(Ref ref) {
  final days = ref.watch(activityCalendarDaysProvider).value;
  if (days == null || days.isEmpty) return null;

  DateTime? earliest;
  for (final day in days) {
    if (!day.hasActivity) continue;
    if (earliest == null || day.date.isBefore(earliest)) earliest = day.date;
  }
  if (earliest == null) return null;

  final now = DateTime.now();
  return DateTimeRange(
    start: DateTime(earliest.year, earliest.month, earliest.day),
    end: DateTime(now.year, now.month, now.day),
  );
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
  final restingHR = ref.watch(restingHeartRateProvider);
  final trainingLoad = TrainingLoadCalculator(
    maxHeartRate: maxHR,
    restingHeartRate: restingHR,
  );
  await RunsRepositoryPowerSync(db).backfillMissingMetrics(trainingLoad: trainingLoad);

  final templateRepo = ref.watch(templateRepositoryPowerSyncProvider);
  await SessionRepositoryPowerSync(db, templateRepo)
      .backfillMissingMetrics(trainingLoad: trainingLoad);
}
