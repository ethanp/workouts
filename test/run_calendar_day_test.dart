import 'package:flutter_test/flutter_test.dart';
import 'package:workouts/models/run_calendar_day.dart';

void main() {
  group('RunCalendarDay', () {
    test('hasActivity is true when runCount > 0', () {
      final day = RunCalendarDay(
        date: DateTime(2026, 3, 1),
        totalDistanceMeters: 8045,
        totalDurationSeconds: 2400,
        zone2Minutes: 18,
        trimp: 45.0,
        hasHrData: true,
        runCount: 1,
      );
      expect(day.hasActivity, isTrue);
    });

    test('hasActivity is false when runCount is 0', () {
      final day = RunCalendarDay(
        date: DateTime(2026, 3, 1),
        totalDistanceMeters: 0,
        totalDurationSeconds: 0,
        zone2Minutes: 0,
        trimp: 0,
        hasHrData: false,
        runCount: 0,
      );
      expect(day.hasActivity, isFalse);
    });

    test('zone2Minutes can be zero even with HR data (easy run)', () {
      final day = RunCalendarDay(
        date: DateTime(2026, 3, 15),
        totalDistanceMeters: 16090,
        totalDurationSeconds: 5400,
        zone2Minutes: 0,
        trimp: 20.0,
        hasHrData: true,
        runCount: 1,
      );
      expect(day.hasHrData, isTrue);
      expect(day.zone2Minutes, equals(0));
    });

    test('multiple runs on same day aggregate correctly by construction', () {
      final day = RunCalendarDay(
        date: DateTime(2026, 3, 20),
        totalDistanceMeters: 8045 + 4023,
        totalDurationSeconds: 2400 + 1200,
        zone2Minutes: 18 + 12,
        trimp: 45.0 + 30.0,
        hasHrData: true,
        runCount: 2,
      );
      expect(day.runCount, equals(2));
      expect(day.totalDistanceMeters, closeTo(12068, 1));
      expect(day.zone2Minutes, equals(30));
    });
  });
}
