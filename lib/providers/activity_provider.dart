import 'dart:async';

import 'package:flutter/material.dart' show DateTimeRange;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:workouts/models/activity_calendar_day.dart';
import 'package:workouts/models/activity_item.dart';
import 'package:workouts/models/cardio_calendar_day.dart';
import 'package:workouts/models/cardio_workout.dart';
import 'package:workouts/models/hr_zone_time.dart';
import 'package:workouts/models/session.dart';
import 'package:workouts/models/session_calendar_day.dart';
import 'package:workouts/providers/unit_system_provider.dart';
import 'package:workouts/services/powersync/powersync_database_provider.dart';
import 'package:workouts/services/repositories/cardio_repository_powersync.dart';
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

  final cardioRepo = CardioRepositoryPowerSync(db);
  final sessionRepo = SessionRepositoryPowerSync(
    db,
    ref.watch(templateRepositoryPowerSyncProvider),
  );

  List<CardioWorkout>? lastCardioWorkouts;
  List<Session>? lastSessions;
  final ctrl = StreamController<List<ActivityItem>>();
  ref.onDispose(ctrl.close);

  void emit() {
    if (lastCardioWorkouts != null && lastSessions != null) {
      final items = <ActivityItem>[
        ...lastCardioWorkouts!.map((w) => ActivityCardio(w)),
        ...lastSessions!
            .where((s) => s.completedAt != null)
            .map((s) => ActivitySession(s)),
      ];
      items.sort((a, b) => b.startedAt.compareTo(a.startedAt));
      ctrl.add(items);
    }
  }

  cardioRepo.watchCardioWorkouts().listen((w) {
    lastCardioWorkouts = w;
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

  final cardioRepo = CardioRepositoryPowerSync(db);
  final sessionRepo = SessionRepositoryPowerSync(
    db,
    ref.watch(templateRepositoryPowerSyncProvider),
  );

  List<CardioCalendarDay>? lastCardioDays;
  List<SessionCalendarDay>? lastSessionDays;
  final ctrl = StreamController<List<ActivityCalendarDay>>();
  ref.onDispose(ctrl.close);

  ActivityCalendarDay activityDayFromCardio(CardioCalendarDay cardioDay) =>
      ActivityCalendarDay(
        date: cardioDay.date,
        totalCardioDistanceMeters: cardioDay.totalDistanceMeters,
        totalCardioDurationSeconds: cardioDay.totalDurationSeconds,
        cardioZoneTime: cardioDay.zoneTime,
        cardioTrimp: cardioDay.trimp,
        cardioHasHrData: cardioDay.hasHrData,
        cardioCount: cardioDay.workoutCount,
        totalSessionDurationSeconds: 0,
        sessionZoneTime: HrZoneTime.zero,
        sessionTrimp: 0,
        sessionCount: 0,
      );

  ActivityCalendarDay mergeSessionInto(
    ActivityCalendarDay existing,
    SessionCalendarDay sessionDay,
  ) => ActivityCalendarDay(
    date: existing.date,
    totalCardioDistanceMeters: existing.totalCardioDistanceMeters,
    totalCardioDurationSeconds: existing.totalCardioDurationSeconds,
    cardioZoneTime: existing.cardioZoneTime,
    cardioTrimp: existing.cardioTrimp,
    cardioHasHrData: existing.cardioHasHrData,
    cardioCount: existing.cardioCount,
    totalSessionDurationSeconds: sessionDay.totalDurationSeconds,
    sessionZoneTime: sessionDay.zoneTime,
    sessionTrimp: sessionDay.trimp,
    sessionCount: sessionDay.sessionCount,
  );

  ActivityCalendarDay activityDayFromSession(SessionCalendarDay sessionDay) =>
      ActivityCalendarDay(
        date: sessionDay.date,
        totalCardioDistanceMeters: 0,
        totalCardioDurationSeconds: 0,
        cardioZoneTime: HrZoneTime.zero,
        cardioTrimp: 0,
        cardioHasHrData: false,
        cardioCount: 0,
        totalSessionDurationSeconds: sessionDay.totalDurationSeconds,
        sessionZoneTime: sessionDay.zoneTime,
        sessionTrimp: sessionDay.trimp,
        sessionCount: sessionDay.sessionCount,
      );

  void emit() {
    if (lastCardioDays != null && lastSessionDays != null) {
      final byDate = <DateTime, ActivityCalendarDay>{};
      for (final cardioDay in lastCardioDays!) {
        byDate[cardioDay.date] = activityDayFromCardio(cardioDay);
      }
      for (final sessionDay in lastSessionDays!) {
        byDate.update(
          sessionDay.date,
          (existing) => mergeSessionInto(existing, sessionDay),
          ifAbsent: () => activityDayFromSession(sessionDay),
        );
      }
      final days = byDate.values.toList()
        ..sort((dayA, dayB) => dayA.date.compareTo(dayB.date));
      ctrl.add(days);
    }
  }

  cardioRepo.watchCalendarDays().listen((c) {
    lastCardioDays = c;
    emit();
  });
  sessionRepo.watchSessionCalendarDays().listen((s) {
    lastSessionDays = s;
    emit();
  });

  return ctrl.stream;
}

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

  final cardioRepo = CardioRepositoryPowerSync(db);
  final sessionRepo = SessionRepositoryPowerSync(
    db,
    ref.watch(templateRepositoryPowerSyncProvider),
  );

  final cardioWorkouts = await cardioRepo.getWorkoutsForDate(date);
  final sessions = await sessionRepo.getSessionsForDate(date);
  final items = <ActivityItem>[
    ...cardioWorkouts.map((w) => ActivityCardio(w)),
    ...sessions.map((s) => ActivitySession(s)),
  ];
  items.sort((a, b) => a.startedAt.compareTo(b.startedAt));
  return items;
}

@riverpod
class MetricsBackfillController extends _$MetricsBackfillController {
  @override
  MetricsBackfillStatus build() => const MetricsBackfillStatus.idle();

  Future<void> runBackfill() async {
    if (state.inProgress) return;
    final db = ref.read(powerSyncDatabaseProvider).value;
    if (db == null) return;

    state = const MetricsBackfillStatus(inProgress: true, label: 'Backfilling zone metrics...');
    final maxHR = ref.read(maxHeartRateProvider);
    final restingHR = ref.read(restingHeartRateProvider);
    final trainingLoad = TrainingLoadCalculator(
      maxHeartRate: maxHR,
      restingHeartRate: restingHR,
    );
    final cardioRepository = CardioRepositoryPowerSync(db);
    await cardioRepository.backfillMissingMetrics(trainingLoad: trainingLoad);

    state = const MetricsBackfillStatus(inProgress: true, label: 'Backfilling best efforts...');
    await cardioRepository.backfillMissingBestEfforts();

    state = const MetricsBackfillStatus(inProgress: true, label: 'Backfilling session metrics...');
    final templateRepo = ref.read(templateRepositoryPowerSyncProvider);
    await SessionRepositoryPowerSync(db, templateRepo)
        .backfillMissingMetrics(trainingLoad: trainingLoad);

    state = const MetricsBackfillStatus(inProgress: false, label: 'Done');
    Future.delayed(const Duration(seconds: 3), () {
      if (ref.exists(metricsBackfillControllerProvider)) {
        state = const MetricsBackfillStatus.idle();
      }
    });
  }
}

class MetricsBackfillStatus {
  const MetricsBackfillStatus({this.inProgress = false, this.label = ''});
  const MetricsBackfillStatus.idle() : inProgress = false, label = '';

  final bool inProgress;
  final String label;
}
