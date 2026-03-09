import 'dart:math' as math;

import 'package:workouts/models/activity_calendar_day.dart';

class MomentumDayScore {
  const MomentumDayScore({required this.date, required this.score});

  final DateTime date;
  final double score;
}

/// Extracts a normalized 0–1 value from an [ActivityCalendarDay].
///
/// [extract] returns null when the aspect doesn't apply to the day
/// (e.g. run aspects on a session-only day) — these are excluded from the
/// weighted average. A return of 0.0 means the aspect applies but has no
/// value (e.g. session TRIMP without HR data) and counts as zero.
class MomentumAspect {
  const MomentumAspect({
    required this.name,
    required this.weight,
    required this.extract,
    required this.target,
  });

  final String name;
  final double weight;
  final double? Function(ActivityCalendarDay day) extract;
  final double target;

  double normalized(double raw) =>
      target > 0 ? (raw / target).clamp(0.0, 1.0) : 0.0;
}

const defaultAspects = [
  MomentumAspect(
    name: 'Run TRIMP',
    weight: 3.0,
    extract: _runTrimp,
    target: 50.0,
  ),
  MomentumAspect(
    name: 'Run Distance',
    weight: 2.0,
    extract: _runDistance,
    target: 5000.0,
  ),
  MomentumAspect(
    name: 'Run Duration',
    weight: 1.0,
    extract: _runDuration,
    target: 1800.0,
  ),
  MomentumAspect(
    name: 'Run >= Zone 2',
    weight: 2.0,
    extract: _runGteZone2,
    target: 30.0,
  ),
  MomentumAspect(
    name: 'Session TRIMP',
    weight: 2.0,
    extract: _sessionTrimp,
    target: 40.0,
  ),
  MomentumAspect(
    name: 'Session Duration',
    weight: 1.5,
    extract: _sessionDuration,
    target: 2700.0,
  ),
];

double? _runTrimp(ActivityCalendarDay day) =>
    day.runCount > 0 ? day.runTrimp : null;
double? _runDistance(ActivityCalendarDay day) =>
    day.runCount > 0 ? day.totalRunDistanceMeters : null;
double? _runDuration(ActivityCalendarDay day) =>
    day.runCount > 0 ? day.totalRunDurationSeconds.toDouble() : null;
double? _runGteZone2(ActivityCalendarDay day) =>
    day.runCount > 0 ? day.runGteZone2Minutes.toDouble() : null;
double? _sessionTrimp(ActivityCalendarDay day) =>
    day.sessionCount > 0 ? day.sessionTrimp : null;
double? _sessionDuration(ActivityCalendarDay day) =>
    day.sessionCount > 0 ? day.totalSessionDurationSeconds.toDouble() : null;

/// Computes a fitness momentum score over a trailing window of days.
///
/// Each day's intensity is a weighted combination of [MomentumAspect]s.
/// Only aspects whose raw value is > 0 contribute (so session aspects
/// don't dilute a run-only day and vice versa).
///
/// The raw scores are then Gaussian-smoothed for a readable chart line.
/// Smoothing is purely presentational.
class MomentumScorer {
  const MomentumScorer({
    this.windowDays = 30,
    this.fullWeightDays = 7,
    this.smoothingSigma = 1.5,
    this.aspects = defaultAspects,
  });

  final int windowDays;
  final int fullWeightDays;
  final double smoothingSigma;
  final List<MomentumAspect> aspects;

  List<MomentumDayScore> compute(
    List<ActivityCalendarDay> days, {
    DateTime? today,
  }) {
    if (days.isEmpty) return [];

    final dateRange = _DateRange.from(days, today);
    if (dateRange == null) return [];

    final intensityByDate = _buildIntensityMap(days);
    final rawScores = _scoreEachDay(dateRange, intensityByDate);
    return _smooth(rawScores);
  }

  Map<DateTime, double> _buildIntensityMap(List<ActivityCalendarDay> days) {
    final map = <DateTime, double>{};
    for (final day in days) {
      final intensity = _dayIntensity(day);
      if (intensity > 0) {
        map[DateTime(day.date.year, day.date.month, day.date.day)] = intensity;
      }
    }
    return map;
  }

  double _dayIntensity(ActivityCalendarDay day) {
    if (!day.hasActivity) return 0.0;

    var weightedSum = 0.0;
    var totalWeight = 0.0;

    for (final aspect in aspects) {
      final double? raw = aspect.extract(day);
      if (raw == null) continue; // aspect not applicable (e.g. run aspect on session-only day)
      totalWeight += aspect.weight;
      weightedSum += aspect.weight * aspect.normalized(raw);
    }

    return totalWeight > 0 ? weightedSum / totalWeight : 0.0;
  }

  List<MomentumDayScore> _scoreEachDay(
    _DateRange dateRange,
    Map<DateTime, double> intensityByDate,
  ) {
    final scores = <MomentumDayScore>[];
    var cursor = dateRange.start;
    while (!cursor.isAfter(dateRange.end)) {
      final percentage = _scoreForDay(cursor, intensityByDate);
      scores.add(MomentumDayScore(date: cursor, score: percentage));
      cursor = _addDays(cursor, 1);
    }
    return scores;
  }

  double _scoreForDay(DateTime day, Map<DateTime, double> intensityByDate) {
    var score = 0.0;
    var maxPossible = 0.0;

    for (var daysAgo = 0; daysAgo < windowDays; daysAgo++) {
      final checkDate = _addDays(day, -daysAgo);
      final weight = _recencyWeight(daysAgo);
      maxPossible += weight;

      final intensity = intensityByDate[checkDate];
      if (intensity != null) {
        score += weight * intensity.clamp(0.0, 1.0);
      }
    }

    return maxPossible > 0 ? (score / maxPossible) * 100 : 0.0;
  }

  /// Gaussian-smooth the score curve for visual presentation.
  List<MomentumDayScore> _smooth(List<MomentumDayScore> rawScores) {
    if (rawScores.length < 2) return rawScores;

    final kernelRadius = (smoothingSigma * 3).ceil();
    final kernel = _gaussianKernel(kernelRadius);
    final smoothed = <MomentumDayScore>[];

    for (var i = 0; i < rawScores.length; i++) {
      var weightedSum = 0.0;
      var kernelSum = 0.0;

      for (var k = -kernelRadius; k <= kernelRadius; k++) {
        final j = i + k;
        if (j < 0 || j >= rawScores.length) continue;
        final w = kernel[k + kernelRadius];
        weightedSum += w * rawScores[j].score;
        kernelSum += w;
      }

      smoothed.add(MomentumDayScore(
        date: rawScores[i].date,
        score: kernelSum > 0 ? weightedSum / kernelSum : rawScores[i].score,
      ));
    }

    return smoothed;
  }

  double _recencyWeight(int daysAgo) {
    if (daysAgo <= fullWeightDays) return 1.0;
    return 1.0 -
        ((daysAgo - fullWeightDays) / (windowDays - fullWeightDays) * 0.9);
  }

  List<double> _gaussianKernel(int radius) {
    final kernel = <double>[];
    var sum = 0.0;
    for (var i = -radius; i <= radius; i++) {
      final value =
          math.exp(-(i * i) / (2 * smoothingSigma * smoothingSigma));
      kernel.add(value);
      sum += value;
    }
    return kernel.map((val) => val / sum).toList();
  }

  static DateTime _addDays(DateTime date, int offset) =>
      DateTime(date.year, date.month, date.day + offset);
}

class _DateRange {
  const _DateRange({required this.start, required this.end});

  final DateTime start;
  final DateTime end;

  static const _windowDays = 30;

  static _DateRange? from(List<ActivityCalendarDay> days, DateTime? today) {
    final sortedDates = days.map((day) => day.date).toList()
      ..sort((dayA, dayB) => dayA.compareTo(dayB));
    final earliest = sortedDates.first;
    final now = today ?? DateTime.now();
    final todayDate = DateTime(now.year, now.month, now.day);

    if (todayDate.difference(earliest).inDays < 7) return null;

    final windowStart = MomentumScorer._addDays(earliest, _windowDays);
    final effectiveStart = windowStart.isAfter(todayDate)
        ? MomentumScorer._addDays(earliest, 7)
        : windowStart;

    return _DateRange(start: effectiveStart, end: todayDate);
  }
}
