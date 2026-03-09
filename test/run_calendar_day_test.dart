import 'package:flutter_test/flutter_test.dart';
import 'package:workouts/models/run_calendar_day.dart';

RunCalendarDay _day({
  int zone1 = 0,
  int zone2 = 0,
  int zone3 = 0,
  int zone4 = 0,
  int zone5 = 0,
  double trimp = 0,
  bool hasHrData = false,
  int runCount = 0,
  double distance = 0,
  int duration = 0,
}) =>
    RunCalendarDay(
      date: DateTime(2026, 3, 1),
      totalDistanceMeters: distance,
      totalDurationSeconds: duration,
      zone1Minutes: zone1,
      zone2Minutes: zone2,
      zone3Minutes: zone3,
      zone4Minutes: zone4,
      zone5Minutes: zone5,
      trimp: trimp,
      hasHrData: hasHrData,
      runCount: runCount,
    );

void main() {
  group('RunCalendarDay', () {
    test('hasActivity is true when runCount > 0', () {
      final day = _day(
        distance: 8045,
        duration: 2400,
        zone2: 18,
        trimp: 45.0,
        hasHrData: true,
        runCount: 1,
      );
      expect(day.hasActivity, isTrue);
    });

    test('hasActivity is false when runCount is 0', () {
      expect(_day().hasActivity, isFalse);
    });

    test('gteZone2Minutes sums zones 2-5', () {
      final day = _day(
        zone1: 5,
        zone2: 10,
        zone3: 8,
        zone4: 3,
        zone5: 1,
        hasHrData: true,
        runCount: 1,
      );
      expect(day.gteZone2Minutes, 22);
    });

    test('gteZone2Minutes excludes zone 1', () {
      final day = _day(zone1: 15, hasHrData: true, runCount: 1);
      expect(day.gteZone2Minutes, 0);
    });

    test('zone2Minutes can be zero even with HR data', () {
      final day = _day(
        distance: 16090,
        duration: 5400,
        zone1: 20,
        trimp: 20.0,
        hasHrData: true,
        runCount: 1,
      );
      expect(day.hasHrData, isTrue);
      expect(day.zone2Minutes, 0);
      expect(day.gteZone2Minutes, 0);
    });
  });
}
