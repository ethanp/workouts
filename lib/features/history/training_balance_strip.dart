import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workouts/models/activity_calendar_day.dart';
import 'package:workouts/models/fitness_goal.dart';
import 'package:workouts/models/polarization_week.dart';
import 'package:workouts/models/session.dart';
import 'package:workouts/features/history/activity_provider.dart';
import 'package:workouts/features/goals/goals_provider.dart';
import 'package:workouts/features/history/history_provider.dart';
import 'package:workouts/theme/app_theme.dart';

const _kMaxGoalRows = 5;
const _kWeekCount = 8;
const _kDotSize = 7.0;
const _kDotSpacing = 2.0;

/// A compact weekly grid answering: "Am I consistently training toward my
/// active fitness goals?"
///
/// Rows: one fixed Cardio row, then one row per active [FitnessGoal] ordered
/// by priority (capped at [_kMaxGoalRows]). A session dot appears in a goal
/// row iff [Session.coversGoal] is true for that goal.
///
/// The same session can appear in multiple goal rows, which is correct — a
/// deadlift session tagged with "knee longevity" and "spine health" exercises
/// lights up both rows.
class TrainingBalanceStrip extends ConsumerStatefulWidget {
  const TrainingBalanceStrip({super.key});

  @override
  ConsumerState<TrainingBalanceStrip> createState() =>
      _TrainingBalanceStripState();
}

class _TrainingBalanceStripState
    extends ConsumerState<TrainingBalanceStrip> {
  String? _expandedDotKey;

  @override
  Widget build(BuildContext context) {
    final calendarAsync = ref.watch(activityCalendarDaysProvider);
    final sessionsAsync = ref.watch(sessionHistoryProvider);
    final goalsAsync = ref.watch(activeGoalsStreamProvider);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.backgroundDepth2,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.borderDepth1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Training Balance', style: AppTypography.subtitle),
          const SizedBox(height: AppSpacing.md),
          goalsAsync.when(
            data: (goals) => calendarAsync.when(
              data: (calendarDays) => sessionsAsync.when(
                data: (sessions) => _grid(
                  goals: _activeGoalsByPriority(goals),
                  calendarDays: calendarDays,
                  sessions: sessions,
                ),
                loading: () =>
                    const Center(child: CupertinoActivityIndicator()),
                error: (_, __) => _errorText('Unable to load sessions'),
              ),
              loading: () =>
                  const Center(child: CupertinoActivityIndicator()),
              error: (_, __) => _errorText('Unable to load activity'),
            ),
            loading: () =>
                const Center(child: CupertinoActivityIndicator()),
            error: (_, __) => _errorText('Unable to load goals'),
          ),
        ],
      ),
    );
  }

  Widget _errorText(String message) => Text(
    message,
    style: AppTypography.caption.copyWith(color: AppColors.textColor4),
  );

  List<FitnessGoal> _activeGoalsByPriority(List<FitnessGoal> goals) {
    final activeGoals = goals
        .where((goal) => goal.status == GoalStatus.active)
        .toList()
      ..sort(
        (firstGoal, secondGoal) =>
            firstGoal.priority.compareTo(secondGoal.priority),
      );
    return activeGoals.take(_kMaxGoalRows).toList();
  }

  Widget _grid({
    required List<FitnessGoal> goals,
    required List<ActivityCalendarDay> calendarDays,
    required List<Session> sessions,
  }) {
    final weekStarts = _recentWeekStarts();
    final daysByMonday = _indexDaysByMonday(calendarDays);
    final sessionsByMonday = _indexSessionsByMonday(sessions);

    final labelWidth = _labelWidth(goals);

    return Column(
      children: [
        _cardioRow(
          weekStarts: weekStarts,
          daysByMonday: daysByMonday,
          labelWidth: labelWidth,
        ),
        for (final goal in goals)
          _goalRow(
            goal: goal,
            weekStarts: weekStarts,
            sessionsByMonday: sessionsByMonday,
            labelWidth: labelWidth,
          ),
      ],
    );
  }

  Widget _cardioRow({
    required List<DateTime> weekStarts,
    required Map<DateTime, List<ActivityCalendarDay>> daysByMonday,
    required double labelWidth,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          SizedBox(
            width: labelWidth,
            child: Text(
              'Cardio',
              style: AppTypography.caption.copyWith(
                color: AppColors.textColor3,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Row(
              children: weekStarts.map((weekStart) {
                final weekDays = daysByMonday[weekStart] ?? [];
                final cardioDays = weekDays
                    .where((day) => day.cardioCount > 0)
                    .toList();
                return Expanded(
                  child: _cardioDotGroup(
                    cardioDays: cardioDays,
                    weekStart: weekStart,
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cardioDotGroup({
    required List<ActivityCalendarDay> cardioDays,
    required DateTime weekStart,
  }) {
    if (cardioDays.isEmpty) return const SizedBox(height: _kDotSize);

    return Wrap(
      spacing: _kDotSpacing,
      runSpacing: _kDotSpacing,
      children: cardioDays.map((day) {
        final polarization = PolarizationWeek.fromHrZoneTime(day.cardioZoneTime);
        final dotKey = 'cardio-${day.date.toIso8601String()}';
        final isExpanded = _expandedDotKey == dotKey;
        final dot = _cardioDot(
          color: _cardioDotColor(polarization, day.cardioHasHrData),
          dotKey: dotKey,
          isExpanded: isExpanded,
        );
        if (!isExpanded) return dot;
        return _expandedCardioDot(dot, day, polarization);
      }).toList(),
    );
  }

  Widget _cardioDot({
    required Color color,
    required String dotKey,
    required bool isExpanded,
  }) {
    return GestureDetector(
      onTap: () => setState(
        () => _expandedDotKey = isExpanded ? null : dotKey,
      ),
      child: Container(
        width: _kDotSize,
        height: _kDotSize,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }

  Widget _expandedCardioDot(
    Widget dot,
    ActivityCalendarDay day,
    PolarizationWeek polarization,
  ) {
    final durationMinutes = day.totalCardioDurationSeconds ~/ 60;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        dot,
        const SizedBox(height: 2),
        _dotDetailCard(
          title: '${day.date.month}/${day.date.day}',
          lines: [
            '${durationMinutes}m cardio',
            if (day.cardioHasHrData)
              '${polarization.aerobicBaseMinutes}m base · '
              '${polarization.grayZoneMinutes}m gray · '
              '${polarization.vo2maxMinutes}m VO₂max',
          ],
        ),
      ],
    );
  }

  Color _cardioDotColor(PolarizationWeek polarization, bool hasHrData) {
    if (!hasHrData || !polarization.hasData) {
      return AppColors.accentPrimary.withValues(alpha: 0.6);
    }
    // Interpolate from muted to vibrant green based on aerobic fraction.
    final aerobicFraction = polarization.aerobicFraction;
    return Color.lerp(
      AppColors.textColor4,
      AppColors.success,
      aerobicFraction,
    )!;
  }

  Widget _goalRow({
    required FitnessGoal goal,
    required List<DateTime> weekStarts,
    required Map<DateTime, List<Session>> sessionsByMonday,
    required double labelWidth,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          SizedBox(
            width: labelWidth,
            child: Text(
              goal.title,
              style: AppTypography.caption.copyWith(
                color: AppColors.textColor3,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Row(
              children: weekStarts.map((weekStart) {
                final weekSessions = sessionsByMonday[weekStart] ?? [];
                final coveringSessions = weekSessions
                    .where((session) => session.coversGoal(goal.id))
                    .toList();
                return Expanded(
                  child: _sessionDotGroup(
                    sessions: coveringSessions,
                    goal: goal,
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sessionDotGroup({
    required List<Session> sessions,
    required FitnessGoal goal,
  }) {
    if (sessions.isEmpty) return const SizedBox(height: _kDotSize);

    return Wrap(
      spacing: _kDotSpacing,
      runSpacing: _kDotSpacing,
      children: sessions.map((session) {
        final dotKey = 'session-${session.id}-${goal.id}';
        final isExpanded = _expandedDotKey == dotKey;
        final dot = _sessionDot(dotKey: dotKey, isExpanded: isExpanded);
        if (!isExpanded) return dot;
        return _expandedSessionDot(dot, session);
      }).toList(),
    );
  }

  Widget _sessionDot({required String dotKey, required bool isExpanded}) {
    return GestureDetector(
      onTap: () => setState(
        () => _expandedDotKey = isExpanded ? null : dotKey,
      ),
      child: Container(
        width: _kDotSize,
        height: _kDotSize,
        decoration: BoxDecoration(
          color: AppColors.accentSecondary.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _expandedSessionDot(Widget dot, Session session) {
    final durationMinutes = session.duration?.inMinutes ?? 0;
    final coveredGoalTitles = _coveredGoalTitlesForSession(session);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        dot,
        const SizedBox(height: 2),
        _dotDetailCard(
          title: _sessionTitle(session),
          lines: [
            if (durationMinutes > 0) '${durationMinutes}m',
            if (coveredGoalTitles.isNotEmpty)
              'Goals: ${coveredGoalTitles.join(', ')}',
          ],
        ),
      ],
    );
  }

  String _sessionTitle(Session session) {
    final date = session.completedAt ?? session.startedAt;
    return '${date.month}/${date.day}';
  }

  List<String> _coveredGoalTitlesForSession(Session session) {
    final goalsAsync = ref.read(activeGoalsStreamProvider);
    final allGoals = goalsAsync.value ?? [];
    final coveredGoalIds = session.coveredGoalIds;
    return allGoals
        .where((goal) => coveredGoalIds.contains(goal.id))
        .map((goal) => goal.title)
        .toList();
  }

  Widget _dotDetailCard({
    required String title,
    required List<String> lines,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.backgroundDepth3,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.borderDepth1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: AppTypography.caption.copyWith(
              color: AppColors.textColor2,
              fontWeight: FontWeight.w600,
            ),
          ),
          for (final line in lines)
            Text(
              line,
              style: AppTypography.caption.copyWith(
                color: AppColors.textColor4,
                fontSize: 11,
              ),
            ),
        ],
      ),
    );
  }

  double _labelWidth(List<FitnessGoal> goals) {
    if (goals.isEmpty) return 50;
    final longestLabel = goals.fold(
      'Cardio'.length,
      (maxLength, goal) => math.max(maxLength, goal.title.length),
    );
    // Approximate: 7px per character, capped at 90.
    return math.min(90, longestLabel * 7.0);
  }

  List<DateTime> _recentWeekStarts() {
    final now = DateTime.now();
    final currentMonday = _mondayOf(now);
    return List.generate(
      _kWeekCount,
      (weekIndex) => DateTime(
        currentMonday.year,
        currentMonday.month,
        currentMonday.day - 7 * (_kWeekCount - 1 - weekIndex),
      ),
    );
  }

  static DateTime _mondayOf(DateTime date) =>
      DateTime(date.year, date.month, date.day - (date.weekday - 1));

  Map<DateTime, List<ActivityCalendarDay>> _indexDaysByMonday(
    List<ActivityCalendarDay> days,
  ) {
    final indexed = <DateTime, List<ActivityCalendarDay>>{};
    for (final day in days) {
      final monday = _mondayOf(day.date);
      indexed.putIfAbsent(monday, () => []).add(day);
    }
    return indexed;
  }

  Map<DateTime, List<Session>> _indexSessionsByMonday(
    List<Session> sessions,
  ) {
    final indexed = <DateTime, List<Session>>{};
    for (final session in sessions) {
      final sessionDate = session.completedAt ?? session.startedAt;
      final monday = _mondayOf(sessionDate);
      indexed.putIfAbsent(monday, () => []).add(session);
    }
    return indexed;
  }
}
