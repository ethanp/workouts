import 'package:flutter_test/flutter_test.dart';
import 'package:workouts/models/activity_calendar_day.dart';
import 'package:workouts/utils/momentum_scorer.dart';

const _scorer = MomentumScorer();
final _today = DateTime(2026, 3, 8);

ActivityCalendarDay _fullRunDay(DateTime date) => ActivityCalendarDay(
      date: date,
      totalRunDistanceMeters: 5000,
      totalRunDurationSeconds: 1800,
      runZone2Minutes: 30,
      runTrimp: 50.0,
      runHasHrData: true,
      runCount: 1,
      totalSessionDurationSeconds: 0,
      sessionZone2Minutes: 0,
      sessionTrimp: 0,
      sessionCount: 0,
    );

ActivityCalendarDay _lightRunDay(DateTime date) => ActivityCalendarDay(
      date: date,
      totalRunDistanceMeters: 1000,
      totalRunDurationSeconds: 600,
      runZone2Minutes: 5,
      runTrimp: 10.0,
      runHasHrData: true,
      runCount: 1,
      totalSessionDurationSeconds: 0,
      sessionZone2Minutes: 0,
      sessionTrimp: 0,
      sessionCount: 0,
    );

ActivityCalendarDay _sessionDay(DateTime date) => ActivityCalendarDay(
      date: date,
      totalRunDistanceMeters: 0,
      totalRunDurationSeconds: 0,
      runZone2Minutes: 0,
      runTrimp: 0,
      runHasHrData: false,
      runCount: 0,
      totalSessionDurationSeconds: 2700,
      sessionZone2Minutes: 0,
      sessionTrimp: 0,
      sessionCount: 1,
    );

ActivityCalendarDay _inactiveDay(DateTime date) => ActivityCalendarDay(
      date: date,
      totalRunDistanceMeters: 0,
      totalRunDurationSeconds: 0,
      runZone2Minutes: 0,
      runTrimp: 0,
      runHasHrData: false,
      runCount: 0,
      totalSessionDurationSeconds: 0,
      sessionZone2Minutes: 0,
      sessionTrimp: 0,
      sessionCount: 0,
    );

/// Builds a 60-day history ending at [_today] using [dayBuilder] for each date.
List<ActivityCalendarDay> _history(
    ActivityCalendarDay Function(DateTime) dayBuilder) {
  return List.generate(60, (i) => dayBuilder(DateTime(2026, 1, 8 + i)));
}

double _latestScore(List<MomentumDayScore> scores) => scores.last.score;

void main() {
  group('intensity via compute', () {
    test('all full-run days yields near 100%', () {
      final scores = _scorer.compute(_history(_fullRunDay), today: _today);
      expect(_latestScore(scores), greaterThan(95.0));
    });

    test('light runs yield lower momentum than full runs', () {
      final fullScores = _scorer.compute(_history(_fullRunDay), today: _today);
      final lightScores =
          _scorer.compute(_history(_lightRunDay), today: _today);
      expect(_latestScore(fullScores), greaterThan(_latestScore(lightScores)));
      expect(_latestScore(lightScores), greaterThan(0));
    });

    test('full sessions at target yield near 100%', () {
      final scores = _scorer.compute(_history(_sessionDay), today: _today);
      expect(_latestScore(scores), greaterThan(95.0));
    });

    test('short sessions score lower than full sessions', () {
      ActivityCalendarDay shortSession(DateTime date) => ActivityCalendarDay(
            date: date,
            totalRunDistanceMeters: 0,
            totalRunDurationSeconds: 0,
            runZone2Minutes: 0,
            runTrimp: 0,
            runHasHrData: false,
            runCount: 0,
            totalSessionDurationSeconds: 900,
            sessionZone2Minutes: 0,
            sessionTrimp: 0,
            sessionCount: 1,
          );

      final fullScores = _scorer.compute(_history(_sessionDay), today: _today);
      final shortScores =
          _scorer.compute(_history(shortSession), today: _today);
      expect(_latestScore(fullScores), greaterThan(_latestScore(shortScores)));
      expect(_latestScore(shortScores), greaterThan(0));
    });

    test('short run duration lowers score even with good distance', () {
      ActivityCalendarDay shortFastRun(DateTime date) => ActivityCalendarDay(
            date: date,
            totalRunDistanceMeters: 5000,
            totalRunDurationSeconds: 600,
            runZone2Minutes: 0,
            runTrimp: 0,
            runHasHrData: false,
            runCount: 1,
            totalSessionDurationSeconds: 0,
            sessionZone2Minutes: 0,
            sessionTrimp: 0,
            sessionCount: 0,
          );

      final fullScores = _scorer.compute(_history(_fullRunDay), today: _today);
      final shortScores =
          _scorer.compute(_history(shortFastRun), today: _today);
      expect(_latestScore(fullScores), greaterThan(_latestScore(shortScores)));
    });

    test('exceeding all targets still caps near 100%', () {
      ActivityCalendarDay bigDay(DateTime date) => ActivityCalendarDay(
            date: date,
            totalRunDistanceMeters: 15000,
            totalRunDurationSeconds: 5400,
            runZone2Minutes: 60,
            runTrimp: 120.0,
            runHasHrData: true,
            runCount: 1,
            totalSessionDurationSeconds: 0,
            sessionZone2Minutes: 0,
            sessionTrimp: 0,
            sessionCount: 0,
          );

      final scores = _scorer.compute(_history(bigDay), today: _today);
      expect(_latestScore(scores), greaterThan(95.0));
    });

    test('inactive days yield 0%', () {
      final scores = _scorer.compute(_history(_inactiveDay), today: _today);
      expect(_latestScore(scores), 0.0);
    });
  });

  group('compute', () {
    test('empty days returns empty', () {
      expect(_scorer.compute([], today: _today), isEmpty);
    });

    test('fewer than 7 days of history returns empty', () {
      final days = [_fullRunDay(DateTime(2026, 3, 5))];
      expect(_scorer.compute(days, today: _today), isEmpty);
    });

    test('last score date equals today', () {
      final scores = _scorer.compute(_history(_fullRunDay), today: _today);
      expect(scores.last.date, _today);
    });

    test('score dates are midnight-normalized', () {
      final scores = _scorer.compute(
          _history(_fullRunDay), today: DateTime(2026, 3, 8, 14, 30));
      for (final score in scores) {
        expect(score.date.hour, 0);
        expect(score.date.minute, 0);
        expect(score.date.second, 0);
      }
    });

    test('lookups work across DST spring-forward boundary', () {
      final days = <ActivityCalendarDay>[];
      for (var i = 0; i < 45; i++) {
        final date = DateTime(2026, 2, 1 + i);
        days.add(i.isEven ? _fullRunDay(date) : _inactiveDay(date));
      }

      final scores = _scorer.compute(days, today: DateTime(2026, 3, 15));
      expect(scores, isNotEmpty);
      expect(scores.last.date, DateTime(2026, 3, 15));
      expect(scores.last.score, greaterThan(30.0));
    });

    test('lookups work across DST fall-back boundary', () {
      final days = <ActivityCalendarDay>[];
      for (var i = 0; i < 45; i++) {
        final date = DateTime(2026, 9, 25 + i);
        days.add(i.isEven ? _fullRunDay(date) : _inactiveDay(date));
      }

      final scores = _scorer.compute(days, today: DateTime(2026, 11, 8));
      expect(scores, isNotEmpty);
      expect(scores.last.date, DateTime(2026, 11, 8));
      expect(scores.last.score, greaterThan(30.0));
    });

    test('session-only days contribute based on duration', () {
      final days = [
        ...List.generate(50, (i) => _fullRunDay(DateTime(2026, 1, 15 + i))),
        _sessionDay(DateTime(2026, 3, 7)),
      ];
      final scores = _scorer.compute(days, today: _today);
      final march7Score =
          scores.firstWhere((score) => score.date == DateTime(2026, 3, 7));
      expect(march7Score.score, greaterThan(0));
    });

    test('recent activity weighs more than old activity', () {
      final recentOnly = [
        ...List.generate(
            50, (i) => _inactiveDay(DateTime(2026, 1, 15 + i))),
        ...List.generate(7, (i) => _fullRunDay(DateTime(2026, 3, 2 + i))),
      ];
      final oldOnly = [
        ...List.generate(
            50, (i) => _inactiveDay(DateTime(2026, 1, 15 + i))),
        ...List.generate(7, (i) => _fullRunDay(DateTime(2026, 2, 9 + i))),
      ];

      final recentScores = _scorer.compute(recentOnly, today: _today);
      final oldScores = _scorer.compute(oldOnly, today: _today);
      expect(_latestScore(recentScores), greaterThan(_latestScore(oldScores)));
    });

    test('smoothing spreads activity intensity across neighbors', () {
      final days = [
        ...List.generate(
            50, (i) => _inactiveDay(DateTime(2026, 1, 15 + i))),
        _fullRunDay(DateTime(2026, 3, 1)),
      ];
      final scores = _scorer.compute(days, today: _today);

      final feb28 =
          scores.firstWhere((score) => score.date == DateTime(2026, 2, 28));
      final march1 =
          scores.firstWhere((score) => score.date == DateTime(2026, 3, 1));
      final feb20 =
          scores.firstWhere((score) => score.date == DateTime(2026, 2, 20));

      expect(feb28.score, greaterThan(0),
          reason: 'Gaussian smear should give neighbors a non-zero score');
      expect(march1.score, greaterThan(0));
      expect(feb20.score, 0.0,
          reason: 'Days far from any activity should remain at 0');
    });
  });
}
