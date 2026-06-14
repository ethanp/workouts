import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:workouts/features/history/charts/rolling_daily_point.dart';
import 'package:workouts/features/history/charts/rolling_daily_series_factory.dart';
import 'package:workouts/models/activity_calendar_day.dart';
import 'package:workouts/models/hr_zone_time.dart';

ActivityCalendarDay _activityDay(DateTime date, {int gteZone2Seconds = 0}) =>
    ActivityCalendarDay(
      date: date,
      outdoorRunDistanceMeters: 0,
      totalCardioDurationSeconds: gteZone2Seconds,
      cardioZoneTime: HrZoneTime(zone2: gteZone2Seconds),
      cardioHasHrData: gteZone2Seconds > 0,
      cardioCount: gteZone2Seconds > 0 ? 1 : 0,
      totalSessionDurationSeconds: 0,
      sessionZoneTime: HrZoneTime.zero,
      sessionCount: 0,
    );

RollingDailyPoint _pointOn(List<RollingDailyPoint> points, DateTime date) =>
    points.firstWhere(
      (point) =>
          point.date.year == date.year &&
          point.date.month == date.month &&
          point.date.day == date.day,
    );

double _z2LoadMinutes(ActivityCalendarDay day) =>
    day.totalZoneTime.gteZone2 / 60;

double _activeDay(ActivityCalendarDay day) => day.hasActivity ? 1.0 : 0.0;

void main() {
  const factory = RollingDailySeriesFactory();

  group('RollingDailySeriesFactory (Z2-5 load minutes)', () {
    test('returns empty when there are no days', () {
      expect(
        factory.build(
          days: [],
          endDate: DateTime(2026, 1, 20),
          dailyValue: _z2LoadMinutes,
        ),
        isEmpty,
      );
    });

    test('returns empty when no day has activity', () {
      final points = factory.build(
        days: [_activityDay(DateTime(2026, 1, 5))],
        endDate: DateTime(2026, 1, 20),
        dailyValue: _z2LoadMinutes,
      );
      expect(points, isEmpty);
    });

    test('one active day contributes to the trailing 7-day window', () {
      final points = factory.build(
        days: [_activityDay(DateTime(2026, 1, 5), gteZone2Seconds: 3600)],
        endDate: DateTime(2026, 1, 20),
        dailyValue: _z2LoadMinutes,
      );

      expect(_pointOn(points, DateTime(2026, 1, 5)).rollingValue, 60);
      expect(_pointOn(points, DateTime(2026, 1, 11)).rollingValue, 60);
      expect(_pointOn(points, DateTime(2026, 1, 12)).rollingValue, 0);
    });

    test('multiple active days inside the window are summed', () {
      final points = factory.build(
        days: [
          _activityDay(DateTime(2026, 1, 5), gteZone2Seconds: 1800),
          _activityDay(DateTime(2026, 1, 7), gteZone2Seconds: 1200),
        ],
        endDate: DateTime(2026, 1, 20),
        dailyValue: _z2LoadMinutes,
      );

      expect(_pointOn(points, DateTime(2026, 1, 8)).rollingValue, 50);
    });

    test('converts seconds to minutes', () {
      final points = factory.build(
        days: [_activityDay(DateTime(2026, 1, 5), gteZone2Seconds: 90)],
        endDate: DateTime(2026, 1, 6),
        dailyValue: _z2LoadMinutes,
      );

      expect(_pointOn(points, DateTime(2026, 1, 5)).rollingValue, 1.5);
    });

    test('leaves a wide steady plateau unchanged after repeated smoothing', () {
      // Daily activity makes the trailing 7-day total a constant 70 once the
      // window fills (Jan 7 onward). A point well inside that plateau is
      // unaffected by either smoothing pass.
      final steadyDays = [
        for (var dayOfMonth = 1; dayOfMonth <= 25; dayOfMonth++)
          _activityDay(DateTime(2026, 1, dayOfMonth), gteZone2Seconds: 600),
      ];
      final points = factory.build(
        days: steadyDays,
        endDate: DateTime(2026, 1, 25),
        dailyValue: _z2LoadMinutes,
      );

      expect(_pointOn(points, DateTime(2026, 1, 20)).smoothedValue, 70);
    });

    test(
      'repeated smoothing attenuates an isolated spike below its raw peak',
      () {
        // A lone workout day creates a narrow 7-day plateau in the raw series;
        // the two centered averaging passes pull in the surrounding zeros, so the
        // smoothed peak is strictly below the 70-minute raw peak.
        final points = factory.build(
          days: [_activityDay(DateTime(2026, 1, 10), gteZone2Seconds: 4200)],
          endDate: DateTime(2026, 1, 31),
          dailyValue: _z2LoadMinutes,
        );

        final smoothedPeak = points
            .map((point) => point.smoothedValue)
            .reduce(math.max);
        expect(smoothedPeak, greaterThan(0));
        expect(smoothedPeak, lessThan(70));
      },
    );

    test('counts post-transition activity when series starts before '
        'spring-forward DST', () {
      final points = factory.build(
        days: [
          _activityDay(DateTime(2026, 2, 1), gteZone2Seconds: 1800),
          _activityDay(DateTime(2026, 3, 20), gteZone2Seconds: 3600),
        ],
        endDate: DateTime(2026, 3, 25),
        dailyValue: _z2LoadMinutes,
      );

      expect(_pointOn(points, DateTime(2026, 3, 22)).rollingValue, 60);
    });

    test('counts post-transition activity when series starts before '
        'fall-back DST', () {
      final points = factory.build(
        days: [
          _activityDay(DateTime(2025, 10, 1), gteZone2Seconds: 1800),
          _activityDay(DateTime(2025, 11, 10), gteZone2Seconds: 3600),
        ],
        endDate: DateTime(2025, 11, 15),
        dailyValue: _z2LoadMinutes,
      );

      expect(_pointOn(points, DateTime(2025, 11, 12)).rollingValue, 60);
    });
  });

  group('RollingDailySeriesFactory (active days)', () {
    test('rolling window counts the number of active days in the last 7', () {
      final points = factory.build(
        days: [
          _activityDay(DateTime(2026, 1, 5), gteZone2Seconds: 600),
          _activityDay(DateTime(2026, 1, 6), gteZone2Seconds: 600),
          _activityDay(DateTime(2026, 1, 9), gteZone2Seconds: 600),
        ],
        endDate: DateTime(2026, 1, 20),
        dailyValue: _activeDay,
      );

      expect(_pointOn(points, DateTime(2026, 1, 9)).rollingValue, 3);
      expect(_pointOn(points, DateTime(2026, 1, 13)).rollingValue, 1);
      expect(_pointOn(points, DateTime(2026, 1, 16)).rollingValue, 0);
    });
  });
}
