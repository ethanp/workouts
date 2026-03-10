import 'package:flutter_test/flutter_test.dart';
import 'package:workouts/models/activity_calendar_day.dart';
import 'package:workouts/models/hr_zone_time.dart';

ActivityCalendarDay _day({
  HrZoneTime cardioZoneTime = HrZoneTime.zero,
  double cardioTrimp = 0,
  bool cardioHasHrData = false,
  int cardioCount = 0,
  double cardioDistance = 0,
  int cardioDuration = 0,
  HrZoneTime sessionZoneTime = HrZoneTime.zero,
  double sessionTrimp = 0,
  int sessionCount = 0,
  int sessionDuration = 0,
}) =>
    ActivityCalendarDay(
      date: DateTime(2026, 3, 1),
      totalCardioDistanceMeters: cardioDistance,
      totalCardioDurationSeconds: cardioDuration,
      cardioZoneTime: cardioZoneTime,
      cardioTrimp: cardioTrimp,
      cardioHasHrData: cardioHasHrData,
      cardioCount: cardioCount,
      totalSessionDurationSeconds: sessionDuration,
      sessionZoneTime: sessionZoneTime,
      sessionTrimp: sessionTrimp,
      sessionCount: sessionCount,
    );

void main() {
  group('ActivityCalendarDay', () {
    test('hasActivity is true when cardioCount > 0', () {
      final day = _day(
        cardioDistance: 5000,
        cardioDuration: 1800,
        cardioZoneTime: const HrZoneTime(zone2: 600),
        cardioTrimp: 30.0,
        cardioHasHrData: true,
        cardioCount: 1,
      );
      expect(day.hasActivity, isTrue);
    });

    test('hasActivity is true when sessionCount > 0', () {
      final day = _day(
        sessionDuration: 2700,
        sessionZoneTime: const HrZoneTime(zone2: 300),
        sessionTrimp: 15.0,
        sessionCount: 1,
      );
      expect(day.hasActivity, isTrue);
    });

    test('totalZoneTime.gteZone2Minutes sums cardio and session zones 2-5', () {
      final day = _day(
        cardioZoneTime: const HrZoneTime(
          zone1: 300,
          zone2: 600,
          zone3: 180,
          zone4: 120,
          zone5: 60,
        ),
        cardioHasHrData: true,
        cardioCount: 1,
        sessionZoneTime: const HrZoneTime(zone2: 240, zone3: 120),
        sessionCount: 1,
        sessionDuration: 1800,
      );
      expect(day.totalZoneTime.gteZone2Minutes, 22);
      expect(day.totalZoneTime.zone2Minutes, 14);
      expect(day.totalTrimp, 0.0);
    });

    test('hasActivity is false when no cardio workouts or sessions', () {
      expect(_day().hasActivity, isFalse);
    });
  });
}
