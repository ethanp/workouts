import 'package:flutter_test/flutter_test.dart';
import 'package:workouts/models/activity_calendar_day.dart';
import 'package:workouts/models/hr_zone_time.dart';
import 'package:workouts/utils/momentum_scorer.dart';

const _scorer = MomentumScorer();
final _today = DateTime(2026, 3, 8);

ActivityCalendarDay _fullCardioDay(DateTime date) => ActivityCalendarDay(
  date: date,
  totalCardioDistanceMeters: 5000,
  totalCardioDurationSeconds: 1800,
  cardioZoneTime: const HrZoneTime(
    zone1: 300,
    zone2: 1200,
    zone3: 300,
  ),
  cardioTrimp: 50.0,
  cardioHasHrData: true,
  cardioCount: 1,
  totalSessionDurationSeconds: 0,
  sessionZoneTime: HrZoneTime.zero,
  sessionTrimp: 0,
  sessionCount: 0,
);

ActivityCalendarDay _lightCardioDay(DateTime date) => ActivityCalendarDay(
  date: date,
  totalCardioDistanceMeters: 1000,
  totalCardioDurationSeconds: 600,
  cardioZoneTime: const HrZoneTime(
    zone1: 180,
    zone2: 300,
  ),
  cardioTrimp: 10.0,
  cardioHasHrData: true,
  cardioCount: 1,
  totalSessionDurationSeconds: 0,
  sessionZoneTime: HrZoneTime.zero,
  sessionTrimp: 0,
  sessionCount: 0,
);

ActivityCalendarDay _sessionDay(DateTime date) => ActivityCalendarDay(
  date: date,
  totalCardioDistanceMeters: 0,
  totalCardioDurationSeconds: 0,
  cardioZoneTime: HrZoneTime.zero,
  cardioTrimp: 0,
  cardioHasHrData: false,
  cardioCount: 0,
  totalSessionDurationSeconds: 2700,
  sessionZoneTime: HrZoneTime.zero,
  sessionTrimp: 0,
  sessionCount: 1,
);

ActivityCalendarDay _inactiveDay(DateTime date) => ActivityCalendarDay(
  date: date,
  totalCardioDistanceMeters: 0,
  totalCardioDurationSeconds: 0,
  cardioZoneTime: HrZoneTime.zero,
  cardioTrimp: 0,
  cardioHasHrData: false,
  cardioCount: 0,
  totalSessionDurationSeconds: 0,
  sessionZoneTime: HrZoneTime.zero,
  sessionTrimp: 0,
  sessionCount: 0,
);

List<ActivityCalendarDay> _history(
  ActivityCalendarDay Function(DateTime) dayBuilder,
) {
  return List.generate(60, (i) => dayBuilder(DateTime(2026, 1, 8 + i)));
}

double _latestScore(List<MomentumDayScore> scores) => scores.last.score;

void main() {
  group('intensity via compute', () {
    test('all full-cardio days yields near 100%', () {
      final scores = _scorer.compute(_history(_fullCardioDay), today: _today);
      expect(_latestScore(scores), greaterThan(95.0));
    });

    test('light cardio yields lower momentum than full cardio', () {
      final fullScores =
          _scorer.compute(_history(_fullCardioDay), today: _today);
      final lightScores = _scorer.compute(
        _history(_lightCardioDay),
        today: _today,
      );
      expect(_latestScore(fullScores), greaterThan(_latestScore(lightScores)));
      expect(_latestScore(lightScores), greaterThan(0));
    });

    test('sessions without HR data are penalized by missing TRIMP', () {
      final scores = _scorer.compute(_history(_sessionDay), today: _today);
      expect(_latestScore(scores), greaterThan(30.0));
      expect(_latestScore(scores), lessThan(55.0));
    });

    test('short sessions score lower than full sessions', () {
      ActivityCalendarDay shortSession(DateTime date) => ActivityCalendarDay(
        date: date,
        totalCardioDistanceMeters: 0,
        totalCardioDurationSeconds: 0,
        cardioZoneTime: HrZoneTime.zero,
        cardioTrimp: 0,
        cardioHasHrData: false,
        cardioCount: 0,
        totalSessionDurationSeconds: 900,
        sessionZoneTime: HrZoneTime.zero,
        sessionTrimp: 0,
        sessionCount: 1,
      );

      final fullScores = _scorer.compute(_history(_sessionDay), today: _today);
      final shortScores = _scorer.compute(
        _history(shortSession),
        today: _today,
      );
      expect(_latestScore(fullScores), greaterThan(_latestScore(shortScores)));
      expect(_latestScore(shortScores), greaterThan(0));
    });

    test('short cardio duration lowers score even with good distance', () {
      ActivityCalendarDay shortFastCardio(DateTime date) =>
          ActivityCalendarDay(
        date: date,
        totalCardioDistanceMeters: 5000,
        totalCardioDurationSeconds: 600,
        cardioZoneTime: HrZoneTime.zero,
        cardioTrimp: 0,
        cardioHasHrData: false,
        cardioCount: 1,
        totalSessionDurationSeconds: 0,
        sessionZoneTime: HrZoneTime.zero,
        sessionTrimp: 0,
        sessionCount: 0,
      );

      final fullScores =
          _scorer.compute(_history(_fullCardioDay), today: _today);
      final shortScores = _scorer.compute(
        _history(shortFastCardio),
        today: _today,
      );
      expect(_latestScore(fullScores), greaterThan(_latestScore(shortScores)));
    });

    test('exceeding all targets still caps near 100%', () {
      ActivityCalendarDay bigDay(DateTime date) => ActivityCalendarDay(
        date: date,
        totalCardioDistanceMeters: 15000,
        totalCardioDurationSeconds: 5400,
        cardioZoneTime: const HrZoneTime(
          zone1: 600,
          zone2: 1800,
          zone3: 900,
          zone4: 300,
        ),
        cardioTrimp: 120.0,
        cardioHasHrData: true,
        cardioCount: 1,
        totalSessionDurationSeconds: 0,
        sessionZoneTime: HrZoneTime.zero,
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
      final days = [_fullCardioDay(DateTime(2026, 3, 5))];
      expect(_scorer.compute(days, today: _today), isEmpty);
    });

    test('last score date equals today', () {
      final scores = _scorer.compute(_history(_fullCardioDay), today: _today);
      expect(scores.last.date, _today);
    });

    test('score dates are midnight-normalized', () {
      final scores = _scorer.compute(
        _history(_fullCardioDay),
        today: DateTime(2026, 3, 8, 14, 30),
      );
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
        days.add(i.isEven ? _fullCardioDay(date) : _inactiveDay(date));
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
        days.add(i.isEven ? _fullCardioDay(date) : _inactiveDay(date));
      }

      final scores = _scorer.compute(days, today: DateTime(2026, 11, 8));
      expect(scores, isNotEmpty);
      expect(scores.last.date, DateTime(2026, 11, 8));
      expect(scores.last.score, greaterThan(30.0));
    });

    test('session-only days contribute based on duration', () {
      final days = [
        ...List.generate(
            50, (i) => _fullCardioDay(DateTime(2026, 1, 15 + i))),
        _sessionDay(DateTime(2026, 3, 7)),
      ];
      final scores = _scorer.compute(days, today: _today);
      final march7Score = scores.firstWhere(
        (score) => score.date == DateTime(2026, 3, 7),
      );
      expect(march7Score.score, greaterThan(0));
    });

    test('recent activity weighs more than old activity', () {
      final recentOnly = [
        ...List.generate(50, (i) => _inactiveDay(DateTime(2026, 1, 15 + i))),
        ...List.generate(7, (i) => _fullCardioDay(DateTime(2026, 3, 2 + i))),
      ];
      final oldOnly = [
        ...List.generate(50, (i) => _inactiveDay(DateTime(2026, 1, 15 + i))),
        ...List.generate(7, (i) => _fullCardioDay(DateTime(2026, 2, 9 + i))),
      ];

      final recentScores = _scorer.compute(recentOnly, today: _today);
      final oldScores = _scorer.compute(oldOnly, today: _today);
      expect(_latestScore(recentScores), greaterThan(_latestScore(oldScores)));
    });

    test('smoothing spreads activity intensity across neighbors', () {
      final days = [
        ...List.generate(50, (i) => _inactiveDay(DateTime(2026, 1, 15 + i))),
        _fullCardioDay(DateTime(2026, 3, 1)),
      ];
      final scores = _scorer.compute(days, today: _today);

      final feb28 = scores.firstWhere(
        (score) => score.date == DateTime(2026, 2, 28),
      );
      final march1 = scores.firstWhere(
        (score) => score.date == DateTime(2026, 3, 1),
      );
      final feb20 = scores.firstWhere(
        (score) => score.date == DateTime(2026, 2, 20),
      );

      expect(
        feb28.score,
        greaterThan(0),
        reason: 'Gaussian smear should give neighbors a non-zero score',
      );
      expect(march1.score, greaterThan(0));
      expect(
        feb20.score,
        0.0,
        reason: 'Days far from any activity should remain at 0',
      );
    });
  });
}
