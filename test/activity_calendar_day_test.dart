import 'package:flutter_test/flutter_test.dart';
import 'package:workouts/models/activity_calendar_day.dart';

void main() {
  group('ActivityCalendarDay', () {
    test('hasActivity is true when runCount > 0', () {
      final day = ActivityCalendarDay(
        date: DateTime(2026, 3, 1),
        totalRunDistanceMeters: 5000,
        totalRunDurationSeconds: 1800,
        runZone2Minutes: 10,
        runHasHrData: true,
        runCount: 1,
        totalSessionDurationSeconds: 0,
        sessionCount: 0,
      );
      expect(day.hasActivity, isTrue);
    });

    test('hasActivity is true when sessionCount > 0', () {
      final day = ActivityCalendarDay(
        date: DateTime(2026, 3, 1),
        totalRunDistanceMeters: 0,
        totalRunDurationSeconds: 0,
        runZone2Minutes: 0,
        runHasHrData: false,
        runCount: 0,
        totalSessionDurationSeconds: 2700,
        sessionCount: 1,
      );
      expect(day.hasActivity, isTrue);
    });

    test('hasActivity is true when both runs and sessions', () {
      final day = ActivityCalendarDay(
        date: DateTime(2026, 3, 15),
        totalRunDistanceMeters: 8045,
        totalRunDurationSeconds: 2400,
        runZone2Minutes: 18,
        runHasHrData: true,
        runCount: 1,
        totalSessionDurationSeconds: 1800,
        sessionCount: 1,
      );
      expect(day.hasActivity, isTrue);
    });

    test('hasActivity is false when no runs or sessions', () {
      final day = ActivityCalendarDay(
        date: DateTime(2026, 3, 1),
        totalRunDistanceMeters: 0,
        totalRunDurationSeconds: 0,
        runZone2Minutes: 0,
        runHasHrData: false,
        runCount: 0,
        totalSessionDurationSeconds: 0,
        sessionCount: 0,
      );
      expect(day.hasActivity, isFalse);
    });
  });
}
