import 'package:ethan_ui/ethan_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workouts/features/history/activity_calendar.dart';
import 'package:workouts/models/activity_calendar_day.dart';
import 'package:workouts/models/hr_zone_time.dart';

ActivityCalendarDay _day({
  required DateTime date,
  double outdoorRunDistanceMeters = 0,
  int totalCardioDurationSeconds = 0,
  HrZoneTime cardioZoneTime = HrZoneTime.zero,
  bool cardioHasHrData = false,
  int cardioCount = 0,
  int totalSessionDurationSeconds = 0,
  int sessionCount = 0,
}) => ActivityCalendarDay(
  date: date,
  outdoorRunDistanceMeters: outdoorRunDistanceMeters,
  totalCardioDurationSeconds: totalCardioDurationSeconds,
  cardioZoneTime: cardioZoneTime,
  cardioHasHrData: cardioHasHrData,
  cardioCount: cardioCount,
  totalSessionDurationSeconds: totalSessionDurationSeconds,
  sessionZoneTime: HrZoneTime.zero,
  sessionCount: sessionCount,
);

void main() {
  const twentyZ25 = HrZoneTime(zone2: 20 * 60);

  test('equal cardio Z2–5 minutes yield the same intensity across types', () {
    final walk = AerobicLoadCalendar.day(
      DateTime(2026, 9, 8),
      _day(
        date: DateTime(2026, 9, 8),
        outdoorRunDistanceMeters: 8000,
        cardioHasHrData: true,
        cardioCount: 1,
        cardioZoneTime: twentyZ25,
      ),
    );
    final elliptical = AerobicLoadCalendar.day(
      DateTime(2026, 9, 8),
      _day(
        date: DateTime(2026, 9, 8),
        totalCardioDurationSeconds: 2400,
        cardioHasHrData: true,
        cardioCount: 1,
        cardioZoneTime: twentyZ25,
      ),
    );
    expect(walk.visual, isA<ECalendarDayMeasuredHeat>());
    expect(
      (walk.visual as ECalendarDayMeasuredHeat).intensity,
      (elliptical.visual as ECalendarDayMeasuredHeat).intensity,
    );
    expect((walk.visual as ECalendarDayMeasuredHeat).fill, isNot(EHeatmapIntensity.none.color));
  });

  test('distance and strength duration do not change fill', () {
    final shortStrength = AerobicLoadCalendar.day(
      DateTime(2026, 9, 8),
      _day(
        date: DateTime(2026, 9, 8),
        outdoorRunDistanceMeters: 1000,
        cardioHasHrData: true,
        cardioCount: 1,
        cardioZoneTime: twentyZ25,
        sessionCount: 1,
        totalSessionDurationSeconds: 600,
      ),
    );
    final longStrength = AerobicLoadCalendar.day(
      DateTime(2026, 9, 8),
      _day(
        date: DateTime(2026, 9, 8),
        outdoorRunDistanceMeters: 20000,
        cardioHasHrData: true,
        cardioCount: 1,
        cardioZoneTime: twentyZ25,
        sessionCount: 1,
        totalSessionDurationSeconds: 7200,
      ),
    );
    expect(
      (shortStrength.visual as ECalendarDayMeasuredHeat).intensity,
      (longStrength.visual as ECalendarDayMeasuredHeat).intensity,
    );
  });

  test('missing HR and strength-only days are recorded without measure', () {
    final cardioWithoutHr = AerobicLoadCalendar.day(
      DateTime(2026, 9, 8),
      _day(
        date: DateTime(2026, 9, 8),
        outdoorRunDistanceMeters: 5000,
        cardioCount: 1,
        totalCardioDurationSeconds: 1800,
      ),
    );
    final strengthOnly = AerobicLoadCalendar.day(
      DateTime(2026, 9, 8),
      _day(
        date: DateTime(2026, 9, 8),
        sessionCount: 1,
        totalSessionDurationSeconds: 3600,
      ),
    );
    expect(cardioWithoutHr.visual, isA<ECalendarDayRecordedWithoutMeasure>());
    expect(strengthOnly.visual, isA<ECalendarDayRecordedWithoutMeasure>());
  });

  test('month totals sum cardio Z2–5 minutes and active days', () {
    final month = AerobicLoadCalendar.month(DateTime(2026, 9, 1), {
      DateTime(2026, 9, 8): _day(
        date: DateTime(2026, 9, 8),
        cardioHasHrData: true,
        cardioCount: 1,
        cardioZoneTime: twentyZ25,
      ),
      DateTime(2026, 9, 9): _day(
        date: DateTime(2026, 9, 9),
        sessionCount: 1,
        totalSessionDurationSeconds: 3600,
      ),
    });
    expect(month.activeDays, 2);
    expect(month.measureCaption, '20m');
  });

  test('46m+ is peak regardless of other loaded history', () {
    final presentation = AerobicLoadCalendar.day(
      DateTime(2026, 9, 8),
      _day(
        date: DateTime(2026, 9, 8),
        cardioHasHrData: true,
        cardioCount: 1,
        cardioZoneTime: const HrZoneTime(zone2: 46 * 60),
      ),
    );
    expect((presentation.visual as ECalendarDayMeasuredHeat).intensity, 1);
  });
}
