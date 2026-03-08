import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:workouts/utils/training_load_calculator.dart';

TimestampedHeartRate _hr(DateTime t, int bpm) =>
    TimestampedHeartRate(timestamp: t, bpm: bpm);

void main() {
  final base = DateTime(2026, 1, 1, 8, 0, 0);
  Duration sec(int s) => Duration(seconds: s);

  final calc = TrainingLoadCalculator(maxHeartRate: 190, restingHeartRate: 60);

  group('zone 2 computation', () {
    test('zone 2 bounds are 60-70% of max HR', () {
      expect(calc.zone2Lower, 114); // floor(190 * 0.60)
      expect(calc.zone2Upper, 133); // ceil(190 * 0.70)
    });

    test('counts zone 2 seconds for mixed samples', () {
      final samples = [
        _hr(base, 120),
        _hr(base.add(sec(10)), 120),
        _hr(base.add(sec(20)), 160),
        _hr(base.add(sec(30)), 115),
        _hr(base.add(sec(40)), 115),
        _hr(base.add(sec(50)), 80),
      ];
      // 120 in zone (10s), 120 in zone (10s), 160 out (0s),
      // 115 in zone (10s), 115 in zone (10s) = 40s
      expect(calc.compute(samples).zone2Seconds, 40);
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
      final expectedTrimp = (10 / 60) * hrRatio * 0.64 * math.exp(1.92 * hrRatio);
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
      final trimp140 = (10 / 60) * hrRatio140 * 0.64 * math.exp(1.92 * hrRatio140);
      final trimp160 = (10 / 60) * hrRatio160 * 0.64 * math.exp(1.92 * hrRatio160);
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
      // 30 min at 155 bpm (HR reserve ratio ~0.73)
      // Expected TRIMP ~= 30 * 0.73 * 0.64 * e^(1.92*0.73) ≈ 30 * 0.73 * 0.64 * 4.07 ≈ 57
      expect(result.trimp, greaterThan(40));
      expect(result.trimp, lessThan(80));
    });
  });

  group('zone 2 and TRIMP computed together', () {
    test('zone 2 BPM contributes to both metrics', () {
      final samples = [
        _hr(base, 120),
        _hr(base.add(sec(10)), 120),
      ];
      final result = calc.compute(samples);
      expect(result.zone2Seconds, 10);
      expect(result.trimp, greaterThan(0));
    });

    test('high-intensity intervals have TRIMP but no zone 2', () {
      final samples = [
        _hr(base, 170),
        _hr(base.add(sec(10)), 170),
      ];
      final result = calc.compute(samples);
      expect(result.zone2Seconds, 0);
      expect(result.trimp, greaterThan(0));
    });
  });
}
