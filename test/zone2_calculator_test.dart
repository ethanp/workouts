import 'package:flutter_test/flutter_test.dart';
import 'package:workouts/utils/zone2_calculator.dart';

void main() {
  group('zone2Bounds', () {
    test('returns 60–70% of max HR', () {
      final bounds = zone2Bounds(190);
      expect(bounds.lower, 114); // floor(190 * 0.60)
      expect(bounds.upper, 133); // ceil(190 * 0.70)
    });

    test('handles lower max HR', () {
      final bounds = zone2Bounds(160);
      expect(bounds.lower, 96); // floor(160 * 0.60)
      expect(bounds.upper, 112); // ceil(160 * 0.70)
    });

    test('lower is always less than or equal to upper', () {
      for (var hr = 130; hr <= 220; hr++) {
        final bounds = zone2Bounds(hr);
        expect(bounds.lower, lessThanOrEqualTo(bounds.upper));
      }
    });
  });

  group('computeZone2Seconds', () {
    final base = DateTime(2026, 1, 1, 8, 0, 0);

    test('returns 0 for empty sample list', () {
      expect(
        computeZone2Seconds([], lowerBpm: 114, upperBpm: 133),
        equals(0),
      );
    });

    test('returns 0 for single sample', () {
      final samples = [(timestamp: base, bpm: 120)];
      expect(
        computeZone2Seconds(samples, lowerBpm: 114, upperBpm: 133),
        equals(0),
      );
    });

    test('counts gap when BPM is within zone', () {
      final samples = [
        (timestamp: base, bpm: 120),
        (timestamp: base.add(const Duration(seconds: 10)), bpm: 120),
      ];
      expect(
        computeZone2Seconds(samples, lowerBpm: 114, upperBpm: 133),
        equals(10),
      );
    });

    test('does not count gap when BPM is below zone', () {
      final samples = [
        (timestamp: base, bpm: 100),
        (timestamp: base.add(const Duration(seconds: 10)), bpm: 120),
      ];
      expect(
        computeZone2Seconds(samples, lowerBpm: 114, upperBpm: 133),
        equals(0),
      );
    });

    test('does not count gap when BPM is above zone', () {
      final samples = [
        (timestamp: base, bpm: 160),
        (timestamp: base.add(const Duration(seconds: 10)), bpm: 120),
      ];
      expect(
        computeZone2Seconds(samples, lowerBpm: 114, upperBpm: 133),
        equals(0),
      );
    });

    test('counts both boundary BPM values (inclusive)', () {
      final samplesAtLower = [
        (timestamp: base, bpm: 114),
        (timestamp: base.add(const Duration(seconds: 5)), bpm: 114),
      ];
      final samplesAtUpper = [
        (timestamp: base, bpm: 133),
        (timestamp: base.add(const Duration(seconds: 5)), bpm: 133),
      ];
      expect(
        computeZone2Seconds(samplesAtLower, lowerBpm: 114, upperBpm: 133),
        equals(5),
      );
      expect(
        computeZone2Seconds(samplesAtUpper, lowerBpm: 114, upperBpm: 133),
        equals(5),
      );
    });

    test('caps large gaps at maxGapSeconds', () {
      final samples = [
        (timestamp: base, bpm: 120),
        // 5-minute gap — should be capped at 30 seconds by default
        (timestamp: base.add(const Duration(minutes: 5)), bpm: 120),
      ];
      expect(
        computeZone2Seconds(samples, lowerBpm: 114, upperBpm: 133),
        equals(30),
      );
    });

    test('respects custom maxGapSeconds', () {
      final samples = [
        (timestamp: base, bpm: 120),
        (timestamp: base.add(const Duration(seconds: 60)), bpm: 120),
      ];
      expect(
        computeZone2Seconds(
          samples,
          lowerBpm: 114,
          upperBpm: 133,
          maxGapSeconds: 45,
        ),
        equals(45),
      );
    });

    test('accumulates multiple zone 2 intervals', () {
      final samples = [
        (timestamp: base, bpm: 120),                                    // in zone
        (timestamp: base.add(const Duration(seconds: 10)), bpm: 120),   // in zone
        (timestamp: base.add(const Duration(seconds: 20)), bpm: 160),   // above — gap not counted
        (timestamp: base.add(const Duration(seconds: 30)), bpm: 115),   // in zone
        (timestamp: base.add(const Duration(seconds: 40)), bpm: 115),   // in zone
        (timestamp: base.add(const Duration(seconds: 50)), bpm: 80),    // below — end
      ];
      // Gaps counted: [0→10]=10s, [10→20]=10s (120 in zone), [30→40]=10s (160 above, not counted)
      // Wait: sample at index 2 (bpm=160) → gap to index 3 NOT counted (bpm above)
      // sample at index 3 (bpm=115) → gap to index 4 = 10s (in zone)
      // sample at index 4 (bpm=115) → gap to index 5 = 10s (in zone)
      // Total: 10 (0→10) + 10 (10→20) + 10 (30→40) + 10 (40→50) = 40s
      expect(
        computeZone2Seconds(samples, lowerBpm: 114, upperBpm: 133),
        equals(40),
      );
    });

    test('handles zero-length gap gracefully', () {
      final samples = [
        (timestamp: base, bpm: 120),
        (timestamp: base, bpm: 120), // same timestamp
      ];
      expect(
        computeZone2Seconds(samples, lowerBpm: 114, upperBpm: 133),
        equals(0),
      );
    });
  });
}
