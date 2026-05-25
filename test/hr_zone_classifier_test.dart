import 'package:flutter_test/flutter_test.dart';
import 'package:workouts/models/hr_zone_time.dart';
import 'package:workouts/utils/hr_zone_classifier.dart';

TimestampedHeartRate _hr(DateTime t, int bpm) =>
    TimestampedHeartRate(timestamp: t, bpm: bpm);

void main() {
  final base = DateTime(2026, 1, 1, 8, 0, 0);
  Duration sec(int s) => Duration(seconds: s);

  group('zone boundaries', () {
    test('5-zone boundaries are correct', () {
      expect(HrZoneClassifier.zoneBoundaries, [93, 115, 146, 163, 176]);
    });

    test('zone2Lower is the zone 2 boundary', () {
      expect(HrZoneClassifier.zone2Lower, 115);
    });
  });

  group('zone bucketing', () {
    test('below zone 1 contributes to no zone', () {
      final samples = [_hr(base, 80), _hr(base.add(sec(10)), 80)];
      final zone = HrZoneClassifier.compute(samples);
      expect(zone.total, 0);
    });

    test('zone 1 BPM (93-114) lands in zone 1', () {
      final samples = [_hr(base, 100), _hr(base.add(sec(10)), 100)];
      final zone = HrZoneClassifier.compute(samples);
      expect(zone.zone1, 10);
      expect(zone.zone2, 0);
    });

    test('zone 2 BPM (115-145) lands in zone 2', () {
      final samples = [_hr(base, 120), _hr(base.add(sec(10)), 120)];
      final zone = HrZoneClassifier.compute(samples);
      expect(zone.zone1, 0);
      expect(zone.zone2, 10);
      expect(zone.zone3, 0);
    });

    test('zone 3 BPM (146-162) lands in zone 3', () {
      final samples = [_hr(base, 150), _hr(base.add(sec(10)), 150)];
      final zone = HrZoneClassifier.compute(samples);
      expect(zone.zone3, 10);
    });

    test('zone 4 BPM (163-175) lands in zone 4', () {
      final samples = [_hr(base, 170), _hr(base.add(sec(10)), 170)];
      final zone = HrZoneClassifier.compute(samples);
      expect(zone.zone4, 10);
    });

    test('zone 5 BPM (176+) lands in zone 5', () {
      final samples = [_hr(base, 180), _hr(base.add(sec(10)), 180)];
      final zone = HrZoneClassifier.compute(samples);
      expect(zone.zone5, 10);
    });

    test('exactly at zone boundary lands in the higher zone', () {
      final samples = [_hr(base, 115), _hr(base.add(sec(10)), 115)];
      final zone = HrZoneClassifier.compute(samples);
      expect(zone.zone2, 10);
      expect(zone.zone1, 0);
    });

    test('mixed samples bucket into correct zones', () {
      final samples = [
        _hr(base, 120),
        _hr(base.add(sec(10)), 120),
        _hr(base.add(sec(20)), 165),
        _hr(base.add(sec(30)), 115),
        _hr(base.add(sec(40)), 115),
        _hr(base.add(sec(50)), 80),
      ];
      final zone = HrZoneClassifier.compute(samples);
      expect(zone.zone2, 40);
      expect(zone.zone4, 10);
      expect(zone.zone1, 0);
      expect(zone.zone3, 0);
      expect(zone.zone5, 0);
    });
  });

  group('gap handling', () {
    test('gaps capped at maxGapSeconds', () {
      final samples = [
        _hr(base, 150),
        _hr(base.add(const Duration(minutes: 5)), 150),
      ];
      final capped = [_hr(base, 150), _hr(base.add(sec(30)), 150)];
      expect(
        HrZoneClassifier.compute(samples),
        equals(HrZoneClassifier.compute(capped)),
      );
    });

    test('empty or single sample produces zero zone time', () {
      expect(HrZoneClassifier.compute([]), HrZoneTime.zero);
      expect(HrZoneClassifier.compute([_hr(base, 120)]), HrZoneTime.zero);
    });
  });

  group('gteZone2', () {
    test('sums zones 2-5', () {
      final samples = [
        _hr(base, 120),
        _hr(base.add(sec(10)), 140),
        _hr(base.add(sec(20)), 160),
        _hr(base.add(sec(30)), 180),
        _hr(base.add(sec(40)), 180),
      ];
      final zone = HrZoneClassifier.compute(samples);
      expect(zone.gteZone2, zone.zone2 + zone.zone3 + zone.zone4 + zone.zone5);
      expect(zone.gteZone2, 40);
    });

    test('excludes zone 1', () {
      final samples = [_hr(base, 100), _hr(base.add(sec(10)), 100)];
      final zone = HrZoneClassifier.compute(samples);
      expect(zone.zone1, 10);
      expect(zone.gteZone2, 0);
    });
  });

  group('HrZoneTime', () {
    test('index operator returns correct zone', () {
      const zone = HrZoneTime(zone1: 1, zone2: 2, zone3: 3, zone4: 4, zone5: 5);
      expect(zone[0], 1);
      expect(zone[1], 2);
      expect(zone[2], 3);
      expect(zone[3], 4);
      expect(zone[4], 5);
      expect(zone[-1], 0);
      expect(zone[5], 0);
    });

    test('total sums all zones', () {
      const zone = HrZoneTime(
        zone1: 10,
        zone2: 20,
        zone3: 30,
        zone4: 40,
        zone5: 50,
      );
      expect(zone.total, 150);
    });

    test('operator+ adds corresponding zones', () {
      const a = HrZoneTime(zone1: 10, zone2: 20, zone3: 30);
      const b = HrZoneTime(zone1: 5, zone2: 15, zone4: 25);
      final sum = a + b;
      expect(sum.zone1, 15);
      expect(sum.zone2, 35);
      expect(sum.zone3, 30);
      expect(sum.zone4, 25);
      expect(sum.zone5, 0);
    });

    test('minutes getters truncate correctly', () {
      const zone = HrZoneTime(zone1: 90, zone2: 150, zone3: 59);
      expect(zone.zone1Minutes, 1);
      expect(zone.zone2Minutes, 2);
      expect(zone.zone3Minutes, 0);
    });

    test('gteZone2 excludes zone 1', () {
      const zone = HrZoneTime(zone1: 100, zone2: 60, zone3: 30);
      expect(zone.gteZone2, 90);
      expect(zone.gteZone2Minutes, 1);
    });
  });
}
