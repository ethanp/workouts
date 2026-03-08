import 'package:flutter_test/flutter_test.dart';
import 'package:workouts/utils/zone2_calculator.dart';

TimestampedHeartRate _hr(DateTime t, int bpm) =>
    TimestampedHeartRate(timestamp: t, bpm: bpm);

void main() {
  group('Zone2Calculator bounds', () {
    test('returns 60–70% of max HR', () {
      final zone2 = Zone2Calculator(maxHeartRate: 190);
      expect(zone2.lowerBpm, 114); // floor(190 * 0.60)
      expect(zone2.upperBpm, 133); // ceil(190 * 0.70)
    });

    test('handles lower max HR', () {
      final zone2 = Zone2Calculator(maxHeartRate: 160);
      expect(zone2.lowerBpm, 96); // floor(160 * 0.60)
      expect(zone2.upperBpm, 112); // ceil(160 * 0.70)
    });

    test('lower is always less than or equal to upper', () {
      for (var hr = 130; hr <= 220; hr++) {
        final zone2 = Zone2Calculator(maxHeartRate: hr);
        expect(zone2.lowerBpm, lessThanOrEqualTo(zone2.upperBpm));
      }
    });
  });

  group('Zone2Calculator.seconds', () {
    final base = DateTime(2026, 1, 1, 8, 0, 0);
    final zone2 = Zone2Calculator(maxHeartRate: 190);

    Duration sec(int s) => Duration(seconds: s);

    test('returns 0 for empty sample list', () {
      expect(zone2.seconds([]), equals(0));
    });

    test('returns 0 for single sample', () {
      expect(zone2.seconds([_hr(base, 120)]), equals(0));
    });

    test('counts gap when BPM is within zone', () {
      final samples = [_hr(base, 120), _hr(base.add(sec(10)), 120)];
      expect(zone2.seconds(samples), equals(10));
    });

    test('does not count gap when BPM is below zone', () {
      final samples = [_hr(base, 100), _hr(base.add(sec(10)), 120)];
      expect(zone2.seconds(samples), equals(0));
    });

    test('does not count gap when BPM is above zone', () {
      final samples = [_hr(base, 160), _hr(base.add(sec(10)), 120)];
      expect(zone2.seconds(samples), equals(0));
    });

    test('counts both boundary BPM values (inclusive)', () {
      expect(
        zone2.seconds([_hr(base, 114), _hr(base.add(sec(5)), 114)]),
        equals(5),
      );
      expect(
        zone2.seconds([_hr(base, 133), _hr(base.add(sec(5)), 133)]),
        equals(5),
      );
    });

    test('caps large gaps at maxGapSeconds', () {
      final samples = [
        _hr(base, 120),
        _hr(base.add(const Duration(minutes: 5)), 120),
      ];
      expect(zone2.seconds(samples), equals(30));
    });

    test('respects custom maxGapSeconds', () {
      final samples = [_hr(base, 120), _hr(base.add(sec(60)), 120)];
      expect(zone2.seconds(samples, maxGapSeconds: 45), equals(45));
    });

    test('accumulates multiple zone 2 intervals', () {
      final samples = [
        _hr(base, 120),
        _hr(base.add(sec(10)), 120),
        _hr(base.add(sec(20)), 160),
        _hr(base.add(sec(30)), 115),
        _hr(base.add(sec(40)), 115),
        _hr(base.add(sec(50)), 80),
      ];
      // 0→10: 120 in zone (10s), 10→20: 120 in zone (10s),
      // 20→30: 160 above (0s), 30→40: 115 in zone (10s),
      // 40→50: 115 in zone (10s) = 40s
      expect(zone2.seconds(samples), equals(40));
    });

    test('handles zero-length gap gracefully', () {
      final samples = [_hr(base, 120), _hr(base, 120)];
      expect(zone2.seconds(samples), equals(0));
    });
  });
}
