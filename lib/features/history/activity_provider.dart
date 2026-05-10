import 'dart:async';

import 'package:ethan_utils/ethan_utils.dart';
import 'package:flutter/material.dart' show DateTimeRange;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:workouts/models/activity_calendar_day.dart';
import 'package:workouts/models/activity_item.dart';
import 'package:workouts/models/cardio_calendar_day.dart';
import 'package:workouts/models/cardio_workout.dart';
import 'package:workouts/models/hr_zone_time.dart';
import 'package:workouts/models/session.dart';
import 'package:workouts/models/session_calendar_day.dart';
import 'package:workouts/features/settings/unit_system_provider.dart';
import 'package:workouts/services/powersync/powersync_database_provider.dart';
import 'package:workouts/services/repositories/cardio_repository_powersync.dart';
import 'package:workouts/services/repositories/session/session_repository_powersync.dart';
import 'package:workouts/services/repositories/templates/template_repository_powersync.dart';
import 'package:workouts/utils/training_load_calculator.dart';

part 'activity_provider.g.dart';

Stream<T> _pendingStream<T>(Ref ref) {
  final streamController = StreamController<T>();
  ref.onDispose(streamController.close);
  return streamController.stream;
}

@riverpod
Stream<List<ActivityItem>> activityList(Ref ref) {
  final powerSyncDatabase = ref.watch(powerSyncDatabaseProvider).value;
  if (powerSyncDatabase == null) return _pendingStream(ref);

  final cardioRepository = CardioRepositoryPowerSync(powerSyncDatabase);
  final sessionRepository = SessionRepositoryPowerSync(
    powerSyncDatabase,
    ref.watch(templateRepositoryPowerSyncProvider),
  );

  List<CardioWorkout>? lastCardioWorkouts;
  List<Session>? lastSessions;
  final streamController = StreamController<List<ActivityItem>>();
  ref.onDispose(streamController.close);

  void emit() {
    if (lastCardioWorkouts != null && lastSessions != null) {
      final activityItems = <ActivityItem>[
        ...lastCardioWorkouts!.map(
          (cardioWorkout) => ActivityCardio(cardioWorkout),
        ),
        ...lastSessions!.map((session) => ActivitySession(session)),
      ];
      activityItems.sort(
        (newerActivity, olderActivity) =>
            olderActivity.startedAt.compareTo(newerActivity.startedAt),
      );
      streamController.add(activityItems);
    }
  }

  final sub1 = cardioRepository.watchCardioWorkouts().listen((cardioWorkouts) {
    lastCardioWorkouts = cardioWorkouts;
    emit();
  });
  final sub2 = sessionRepository.watchSessions().listen((sessions) {
    lastSessions = sessions;
    emit();
  });
  ref.onDispose(() {
    sub1.cancel();
    sub2.cancel();
  });

  return streamController.stream;
}

@riverpod
Stream<List<ActivityCalendarDay>> activityCalendarDays(Ref ref) {
  final powerSyncDatabase = ref.watch(powerSyncDatabaseProvider).value;
  if (powerSyncDatabase == null) return _pendingStream(ref);

  final cardioRepository = CardioRepositoryPowerSync(powerSyncDatabase);
  final sessionRepository = SessionRepositoryPowerSync(
    powerSyncDatabase,
    ref.watch(templateRepositoryPowerSyncProvider),
  );

  List<CardioCalendarDay>? lastCardioDays;
  List<SessionCalendarDay>? lastSessionDays;
  final streamController = StreamController<List<ActivityCalendarDay>>();
  ref.onDispose(streamController.close);

  ActivityCalendarDay activityDayFromCardio(CardioCalendarDay cardioDay) =>
      ActivityCalendarDay(
        date: cardioDay.date,
        outdoorRunDistanceMeters: cardioDay.outdoorRunDistanceMeters,
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
    ActivityCalendarDay existingActivityDay,
    SessionCalendarDay sessionDay,
  ) => ActivityCalendarDay(
    date: existingActivityDay.date,
    outdoorRunDistanceMeters: existingActivityDay.outdoorRunDistanceMeters,
    totalCardioDurationSeconds: existingActivityDay.totalCardioDurationSeconds,
    cardioZoneTime: existingActivityDay.cardioZoneTime,
    cardioTrimp: existingActivityDay.cardioTrimp,
    cardioHasHrData: existingActivityDay.cardioHasHrData,
    cardioCount: existingActivityDay.cardioCount,
    totalSessionDurationSeconds: sessionDay.totalDurationSeconds,
    sessionZoneTime: sessionDay.zoneTime,
    sessionTrimp: sessionDay.trimp,
    sessionCount: sessionDay.sessionCount,
  );

  ActivityCalendarDay activityDayFromSession(SessionCalendarDay sessionDay) =>
      ActivityCalendarDay(
        date: sessionDay.date,
        outdoorRunDistanceMeters: 0,
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
          (existingActivityDay) =>
              mergeSessionInto(existingActivityDay, sessionDay),
          ifAbsent: () => activityDayFromSession(sessionDay),
        );
      }
      final days = byDate.values.toList().sortedOn(
        (activityDay) => activityDay.date,
      );
      streamController.add(days);
    }
  }

  final sub1 = cardioRepository.watchCalendarDays().listen((
    cardioCalendarDays,
  ) {
    lastCardioDays = cardioCalendarDays;
    emit();
  });
  final sub2 = sessionRepository.watchSessionCalendarDays().listen((
    sessionCalendarDays,
  ) {
    lastSessionDays = sessionCalendarDays;
    emit();
  });
  ref.onDispose(() {
    sub1.cancel();
    sub2.cancel();
  });

  return streamController.stream;
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
  return DateTimeRange(start: earliest.startOfDay, end: now.startOfDay);
}

@riverpod
Future<List<ActivityItem>> activityForDate(Ref ref, DateTime date) async {
  final powerSyncDatabase = ref.watch(powerSyncDatabaseProvider).value;
  if (powerSyncDatabase == null) return [];

  final cardioRepository = CardioRepositoryPowerSync(powerSyncDatabase);
  final sessionRepository = SessionRepositoryPowerSync(
    powerSyncDatabase,
    ref.watch(templateRepositoryPowerSyncProvider),
  );

  final cardioWorkouts = await cardioRepository.getWorkoutsForDate(date);
  final sessions = await sessionRepository.getSessionsForDate(date);
  final activityItems = <ActivityItem>[
    ...cardioWorkouts.map((cardioWorkout) => ActivityCardio(cardioWorkout)),
    ...sessions.map((session) => ActivitySession(session)),
  ];
  activityItems.sort(
    (olderActivity, newerActivity) =>
        olderActivity.startedAt.compareTo(newerActivity.startedAt),
  );
  return activityItems;
}

@riverpod
class MetricsBackfillController extends _$MetricsBackfillController {
  bool _disposed = false;

  @override
  MetricsBackfillStatus build() {
    _disposed = false;
    ref.onDispose(() => _disposed = true);
    return const MetricsBackfillStatus.idle();
  }

  Future<void> runBackfill() async {
    if (state.inProgress) return;
    final powerSyncDatabase = ref.read(powerSyncDatabaseProvider).value;
    if (powerSyncDatabase == null) return;

    state = const MetricsBackfillStatus(
      inProgress: true,
      label: 'Backfilling zone metrics...',
    );
    final restingHeartRate = ref.read(restingHeartRateProvider);
    final trainingLoad = TrainingLoadCalculator(
      restingHeartRate: restingHeartRate,
    );
    final cardioRepository = CardioRepositoryPowerSync(powerSyncDatabase);
    await cardioRepository.backfillMissingMetrics(trainingLoad: trainingLoad);

    state = const MetricsBackfillStatus(
      inProgress: true,
      label: 'Backfilling best efforts...',
    );
    await cardioRepository.backfillMissingBestEfforts();

    state = const MetricsBackfillStatus(
      inProgress: true,
      label: 'Backfilling session metrics...',
    );
    final templateRepo = ref.read(templateRepositoryPowerSyncProvider);
    await SessionRepositoryPowerSync(
      powerSyncDatabase,
      templateRepo,
    ).backfillMissingMetrics(trainingLoad: trainingLoad);

    state = const MetricsBackfillStatus(inProgress: false, label: 'Done');
    Future.delayed(const Duration(seconds: 3), () {
      if (!_disposed) {
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
