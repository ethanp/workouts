import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:workouts/models/hr_zone_time.dart';
import 'package:workouts/utils/training_load_calculator.dart';

TimestampedHeartRate _hr(DateTime t, int bpm) =>
    TimestampedHeartRate(timestamp: t, bpm: bpm);

void main() {
  final base = DateTime(2026, 1, 1, 8, 0, 0);
  Duration sec(int s) => Duration(seconds: s);

  final calc = TrainingLoadCalculator(maxHeartRate: 190, restingHeartRate: 60);

  group('zone boundaries', () {
    test('5-zone boundaries are correct percentages of max HR', () {
      expect(calc.zoneBoundaries, [95, 114, 133, 152, 171]);
    });

    test('zone2Lower is the zone 2 boundary', () {
      expect(calc.zone2Lower, 114);
    });
  });

  group('zone bucketing', () {
    test('below zone 1 contributes to no zone', () {
      final samples = [
        _hr(base, 80),
        _hr(base.add(sec(10)), 80),
      ];
      final zone = calc.compute(samples).zoneTime;
      expect(zone.total, 0);
    });

    test('zone 1 BPM (95-113) lands in zone 1', () {
      final samples = [
        _hr(base, 100),
        _hr(base.add(sec(10)), 100),
      ];
      final zone = calc.compute(samples).zoneTime;
      expect(zone.zone1, 10);
      expect(zone.zone2, 0);
    });

    test('zone 2 BPM (114-132) lands in zone 2', () {
      final samples = [
        _hr(base, 120),
        _hr(base.add(sec(10)), 120),
      ];
      final zone = calc.compute(samples).zoneTime;
      expect(zone.zone1, 0);
      expect(zone.zone2, 10);
      expect(zone.zone3, 0);
    });

    test('zone 3 BPM (133-151) lands in zone 3', () {
      final samples = [
        _hr(base, 140),
        _hr(base.add(sec(10)), 140),
      ];
      final zone = calc.compute(samples).zoneTime;
      expect(zone.zone3, 10);
    });

    test('zone 4 BPM (152-170) lands in zone 4', () {
      final samples = [
        _hr(base, 160),
        _hr(base.add(sec(10)), 160),
      ];
      final zone = calc.compute(samples).zoneTime;
      expect(zone.zone4, 10);
    });

    test('zone 5 BPM (171+) lands in zone 5', () {
      final samples = [
        _hr(base, 180),
        _hr(base.add(sec(10)), 180),
      ];
      final zone = calc.compute(samples).zoneTime;
      expect(zone.zone5, 10);
    });

    test('exactly at zone boundary lands in the higher zone', () {
      final samples = [
        _hr(base, 114),
        _hr(base.add(sec(10)), 114),
      ];
      final zone = calc.compute(samples).zoneTime;
      expect(zone.zone2, 10);
      expect(zone.zone1, 0);
    });

    test('mixed samples bucket into correct zones', () {
      final samples = [
        _hr(base, 120),
        _hr(base.add(sec(10)), 120),
        _hr(base.add(sec(20)), 160),
        _hr(base.add(sec(30)), 115),
        _hr(base.add(sec(40)), 115),
        _hr(base.add(sec(50)), 80),
      ];
      final zone = calc.compute(samples).zoneTime;
      expect(zone.zone2, 40);
      expect(zone.zone4, 10);
      expect(zone.zone1, 0);
      expect(zone.zone3, 0);
      expect(zone.zone5, 0);
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
      final zone = calc.compute(samples).zoneTime;
      expect(zone.gteZone2,
          zone.zone2 + zone.zone3 + zone.zone4 + zone.zone5);
      expect(zone.gteZone2, 40);
    });

    test('excludes zone 1', () {
      final samples = [
        _hr(base, 100),
        _hr(base.add(sec(10)), 100),
      ];
      final zone = calc.compute(samples).zoneTime;
      expect(zone.zone1, 10);
      expect(zone.gteZone2, 0);
    });
  });

  group('TRIMP computation', () {
    test('empty or single sample returns 0', () {
      expect(calc.compute([]).trimp, 0.0);
      expect(calc.compute([_hr(base, 120)]).trimp, 0.0);
    });

    test('BPM at or below resting HR produces 0 TRIMP', () {
      final samples = [
        _hr(base, 60),
        _hr(base.add(sec(60)), 55),
      ];
      expect(calc.compute(samples).trimp, 0.0);
    });

    test('single interval matches Banister formula', () {
      final samples = [
        _hr(base, 150),
        _hr(base.add(sec(10)), 150),
      ];
      final result = calc.compute(samples);

      final hrRatio = (150 - 60) / (190 - 60);
      final expectedTrimp =
          (10 / 60) * hrRatio * 0.64 * math.exp(1.92 * hrRatio);
      expect(result.trimp, closeTo(expectedTrimp, 0.001));
    });

    test('higher HR produces higher TRIMP for same duration', () {
      final lowHR = [
        _hr(base, 120),
        _hr(base.add(sec(600)), 120),
      ];
      final highHR = [
        _hr(base, 170),
        _hr(base.add(sec(600)), 170),
      ];
      expect(calc.compute(highHR).trimp, greaterThan(calc.compute(lowHR).trimp));
    });

    test('longer duration produces higher TRIMP at same HR', () {
      final shortContinuous = List.generate(
        31,
        (i) => _hr(base.add(sec(i * 10)), 140),
      );
      final longContinuous = List.generate(
        61,
        (i) => _hr(base.add(sec(i * 10)), 140),
      );
      expect(
        calc.compute(longContinuous).trimp,
        greaterThan(calc.compute(shortContinuous).trimp),
      );
    });

    test('TRIMP accumulates across multiple intervals', () {
      final samples = [
        _hr(base, 140),
        _hr(base.add(sec(10)), 160),
        _hr(base.add(sec(20)), 160),
      ];
      final result = calc.compute(samples);

      final hrRatio140 = (140 - 60) / (190 - 60);
      final hrRatio160 = (160 - 60) / (190 - 60);
      final trimp140 =
          (10 / 60) * hrRatio140 * 0.64 * math.exp(1.92 * hrRatio140);
      final trimp160 =
          (10 / 60) * hrRatio160 * 0.64 * math.exp(1.92 * hrRatio160);
      expect(result.trimp, closeTo(trimp140 + trimp160, 0.001));
    });

    test('gaps capped at maxGapSeconds', () {
      final samples = [
        _hr(base, 150),
        _hr(base.add(const Duration(minutes: 5)), 150),
      ];
      final capped = [
        _hr(base, 150),
        _hr(base.add(sec(30)), 150),
      ];
      expect(calc.compute(samples).trimp, calc.compute(capped).trimp);
    });

    test('realistic 30-min run produces expected TRIMP range', () {
      final samples = List.generate(
        181,
        (i) => _hr(base.add(sec(i * 10)), 155),
      );
      final result = calc.compute(samples);
      expect(result.trimp, greaterThan(40));
      expect(result.trimp, lessThan(80));
    });
  });

  group('zone time and TRIMP computed together', () {
    test('zone 2 BPM contributes to both metrics', () {
      final samples = [
        _hr(base, 120),
        _hr(base.add(sec(10)), 120),
      ];
      final result = calc.compute(samples);
      expect(result.zoneTime.zone2, 10);
      expect(result.trimp, greaterThan(0));
    });

    test('high-intensity intervals have TRIMP but land in zone 4/5', () {
      final samples = [
        _hr(base, 170),
        _hr(base.add(sec(10)), 170),
      ];
      final result = calc.compute(samples);
      expect(result.zoneTime.zone2, 0);
      expect(result.zoneTime.zone4, 10);
      expect(result.trimp, greaterThan(0));
    });
  });

  group('HrZoneTime', () {
    test('index operator returns correct zone', () {
      const zone = HrZoneTime(
        zone1: 1,
        zone2: 2,
        zone3: 3,
        zone4: 4,
        zone5: 5,
      );
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
