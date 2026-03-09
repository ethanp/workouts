import 'package:flutter_test/flutter_test.dart';
import 'package:workouts/models/activity_calendar_day.dart';

ActivityCalendarDay _day({
  int runZone1 = 0,
  int runZone2 = 0,
  int runZone3 = 0,
  int runZone4 = 0,
  int runZone5 = 0,
  double runTrimp = 0,
  bool runHasHrData = false,
  int runCount = 0,
  double runDistance = 0,
  int runDuration = 0,
  int sessionZone1 = 0,
  int sessionZone2 = 0,
  int sessionZone3 = 0,
  int sessionZone4 = 0,
  int sessionZone5 = 0,
  double sessionTrimp = 0,
  int sessionCount = 0,
  int sessionDuration = 0,
}) =>
    ActivityCalendarDay(
      date: DateTime(2026, 3, 1),
      totalRunDistanceMeters: runDistance,
      totalRunDurationSeconds: runDuration,
      runZone1Minutes: runZone1,
      runZone2Minutes: runZone2,
      runZone3Minutes: runZone3,
      runZone4Minutes: runZone4,
      runZone5Minutes: runZone5,
      runTrimp: runTrimp,
      runHasHrData: runHasHrData,
      runCount: runCount,
      totalSessionDurationSeconds: sessionDuration,
      sessionZone1Minutes: sessionZone1,
      sessionZone2Minutes: sessionZone2,
      sessionZone3Minutes: sessionZone3,
      sessionZone4Minutes: sessionZone4,
      sessionZone5Minutes: sessionZone5,
      sessionTrimp: sessionTrimp,
      sessionCount: sessionCount,
    );

void main() {
  group('ActivityCalendarDay', () {
    test('hasActivity is true when runCount > 0', () {
      final day = _day(
        runDistance: 5000,
        runDuration: 1800,
        runZone2: 10,
        runTrimp: 30.0,
        runHasHrData: true,
        runCount: 1,
      );
      expect(day.hasActivity, isTrue);
    });

    test('hasActivity is true when sessionCount > 0', () {
      final day = _day(
        sessionDuration: 2700,
        sessionZone2: 5,
        sessionTrimp: 15.0,
        sessionCount: 1,
      );
      expect(day.hasActivity, isTrue);
    });

    test('totalGteZone2Minutes sums run and session zones 2-5', () {
      final day = _day(
        runZone1: 5,
        runZone2: 10,
        runZone3: 3,
        runZone4: 2,
        runZone5: 1,
        runHasHrData: true,
        runCount: 1,
        sessionZone2: 4,
        sessionZone3: 2,
        sessionCount: 1,
        sessionDuration: 1800,
      );
      expect(day.totalGteZone2Minutes, 22);
      expect(day.totalZone2Minutes, 14);
      expect(day.totalTrimp, 0.0);
    });

    test('hasActivity is false when no runs or sessions', () {
      expect(_day().hasActivity, isFalse);
    });
  });
}
