import 'package:workouts/models/activity_calendar_day.dart';
import 'package:workouts/models/hr_zone_time.dart';

/// Aggregated HR zone time for one week, grouped into three functional buckets
/// relevant to longevity and broad athleticism.
///
/// Aerobic Base (Z1+Z2): mitochondrial efficiency, fat oxidation, metabolic health.
/// Gray Zone (Z3): minimize — high fatigue, poor adaptation specificity.
/// VO₂max Stimulus (Z4+Z5): maintains VO₂max, the strongest all-cause mortality predictor.
class PolarizationWeek {
  const PolarizationWeek({
    required this.aerobicBaseSeconds,
    required this.grayZoneSeconds,
    required this.vo2maxSeconds,
  });

  static const zero = PolarizationWeek(
    aerobicBaseSeconds: 0,
    grayZoneSeconds: 0,
    vo2maxSeconds: 0,
  );

  final int aerobicBaseSeconds;
  final int grayZoneSeconds;
  final int vo2maxSeconds;

  int get totalZoneSeconds =>
      aerobicBaseSeconds + grayZoneSeconds + vo2maxSeconds;

  bool get hasData => totalZoneSeconds > 0;

  double get aerobicFraction =>
      hasData ? aerobicBaseSeconds / totalZoneSeconds : 0;

  double get grayFraction => hasData ? grayZoneSeconds / totalZoneSeconds : 0;

  double get vo2maxFraction => hasData ? vo2maxSeconds / totalZoneSeconds : 0;

  int get aerobicBaseMinutes => aerobicBaseSeconds ~/ 60;
  int get grayZoneMinutes => grayZoneSeconds ~/ 60;
  int get vo2maxMinutes => vo2maxSeconds ~/ 60;
  int get totalZoneMinutes => totalZoneSeconds ~/ 60;

  factory PolarizationWeek.fromHrZoneTime(HrZoneTime zoneTime) =>
      PolarizationWeek(
        aerobicBaseSeconds: zoneTime.zone1 + zoneTime.zone2,
        grayZoneSeconds: zoneTime.zone3,
        vo2maxSeconds: zoneTime.zone4 + zoneTime.zone5,
      );

  factory PolarizationWeek.fromWeekOfDays(List<ActivityCalendarDay> days) {
    var zone1 = 0;
    var zone2 = 0;
    var zone3 = 0;
    var zone4 = 0;
    var zone5 = 0;

    for (final day in days) {
      zone1 += day.totalZoneTime.zone1;
      zone2 += day.totalZoneTime.zone2;
      zone3 += day.totalZoneTime.zone3;
      zone4 += day.totalZoneTime.zone4;
      zone5 += day.totalZoneTime.zone5;
    }

    return PolarizationWeek(
      aerobicBaseSeconds: zone1 + zone2,
      grayZoneSeconds: zone3,
      vo2maxSeconds: zone4 + zone5,
    );
  }

  PolarizationWeek operator +(PolarizationWeek other) => PolarizationWeek(
    aerobicBaseSeconds: aerobicBaseSeconds + other.aerobicBaseSeconds,
    grayZoneSeconds: grayZoneSeconds + other.grayZoneSeconds,
    vo2maxSeconds: vo2maxSeconds + other.vo2maxSeconds,
  );

  String get qualityLabel {
    if (!hasData) return 'No HR data';
    final grayPercent = (grayFraction * 100).round();
    final aerobicPercent = (aerobicFraction * 100).round();
    if (grayPercent >= 35) return 'Gray-zone heavy';
    if (aerobicPercent >= 70 && grayPercent <= 15) return 'Well polarized';
    return 'Moderate polarization';
  }
}
