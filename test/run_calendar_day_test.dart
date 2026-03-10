import 'package:flutter_test/flutter_test.dart';
import 'package:workouts/models/cardio_calendar_day.dart';
import 'package:workouts/models/hr_zone_time.dart';

CardioCalendarDay _day({
  HrZoneTime zoneTime = HrZoneTime.zero,
  double trimp = 0,
  bool hasHrData = false,
  int workoutCount = 0,
  double distance = 0,
  int duration = 0,
}) =>
    CardioCalendarDay(
      date: DateTime(2026, 3, 1),
      totalDistanceMeters: distance,
      totalDurationSeconds: duration,
      zoneTime: zoneTime,
      trimp: trimp,
      hasHrData: hasHrData,
      workoutCount: workoutCount,
    );

void main() {
  group('CardioCalendarDay', () {
    test('hasActivity is true when workoutCount > 0', () {
      final day = _day(
        distance: 8045,
        duration: 2400,
        zoneTime: const HrZoneTime(zone2: 1080),
        trimp: 45.0,
        hasHrData: true,
        workoutCount: 1,
      );
      expect(day.hasActivity, isTrue);
    });

    test('hasActivity is false when workoutCount is 0', () {
      expect(_day().hasActivity, isFalse);
    });

    test('zoneTime.gteZone2Minutes sums zones 2-5 in minutes', () {
      final day = _day(
        zoneTime: const HrZoneTime(
          zone1: 300,
          zone2: 600,
          zone3: 480,
          zone4: 180,
          zone5: 60,
        ),
        hasHrData: true,
        workoutCount: 1,
      );
      expect(day.zoneTime.gteZone2, 1320);
      expect(day.zoneTime.gteZone2Minutes, 22);
    });

    test('gteZone2 excludes zone 1', () {
      final day = _day(
        zoneTime: const HrZoneTime(zone1: 900),
        hasHrData: true,
        workoutCount: 1,
      );
      expect(day.zoneTime.gteZone2, 0);
    });

    test('zone2 can be zero even with HR data', () {
      final day = _day(
        distance: 16090,
        duration: 5400,
        zoneTime: const HrZoneTime(zone1: 1200),
        trimp: 20.0,
        hasHrData: true,
        workoutCount: 1,
      );
      expect(day.hasHrData, isTrue);
      expect(day.zoneTime.zone2, 0);
      expect(day.zoneTime.gteZone2, 0);
    });
  });
}
