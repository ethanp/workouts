import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workouts/models/fitness_run.dart';
import 'package:workouts/models/run_calendar_day.dart';
import 'package:workouts/providers/runs_provider.dart';
import 'package:workouts/providers/unit_system_provider.dart';
import 'package:workouts/services/repositories/runs_repository_powersync.dart';
import 'package:workouts/theme/app_theme.dart';
import 'package:workouts/utils/run_formatting.dart';
import 'package:workouts/widgets/run_activity_calendar.dart';

class RunCalendarScreen extends ConsumerWidget {
  const RunCalendarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Trigger backfill lazily on first calendar view.
    ref.watch(runMetricsBackfillProvider);

    final calendarAsync = ref.watch(runCalendarDaysProvider);
    final unitSystem = ref.watch(unitSystemProvider);

    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('Calendar')),
      child: SafeArea(
        child: calendarAsync.when(
          data: (days) => _CalendarContent(
            days: days,
            unitSystem: unitSystem,
            ref: ref,
          ),
          loading: () => const Center(child: CupertinoActivityIndicator()),
          error: (error, _) => Center(
            child: Text(
              'Unable to load calendar: $error',
              style: AppTypography.body.copyWith(color: AppColors.error),
            ),
          ),
        ),
      ),
    );
  }
}

class _CalendarContent extends StatelessWidget {
  const _CalendarContent({
    required this.days,
    required this.unitSystem,
    required this.ref,
  });

  final List<RunCalendarDay> days;
  final UnitSystem unitSystem;
  final WidgetRef ref;

  Map<DateTime, RunCalendarDay> get _activityData =>
      {for (final day in days) day.date: day};

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        RunActivityCalendar(
          activityData: _activityData,
          unitSystem: unitSystem,
          onDateTap: (date) => _showDayDetail(context, date),
        ),
      ],
    );
  }

  void _showDayDetail(BuildContext context, DateTime date) {
    final repo = ref.read(runsRepositoryPowerSyncProvider);
    showCupertinoModalPopup<void>(
      context: context,
      builder: (_) => _DayDetailSheet(date: date, repo: repo),
    );
  }
}

class _DayDetailSheet extends StatefulWidget {
  const _DayDetailSheet({required this.date, required this.repo});

  final DateTime date;
  final dynamic repo;

  @override
  State<_DayDetailSheet> createState() => _DayDetailSheetState();
}

class _DayDetailSheetState extends State<_DayDetailSheet> {
  List<FitnessRun>? _runs;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final runs = await widget.repo.getRunsForDate(widget.date) as List<FitnessRun>;
    if (mounted) setState(() => _runs = runs);
  }

  @override
  Widget build(BuildContext context) {
    final dayLabel = _formatDate(widget.date);
    return CupertinoActionSheet(
      title: Text(dayLabel),
      message: _runs == null
          ? const CupertinoActivityIndicator()
          : _runs!.isEmpty
              ? const Text('No runs on this day')
              : _runList(),
      cancelButton: CupertinoActionSheetAction(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Close'),
      ),
    );
  }

  Widget _runList() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: _runs!.map(_runRow).toList(),
    );
  }

  Widget _runRow(FitnessRun run) {
    final durationSeconds = run.durationSeconds;
    final hours = durationSeconds ~/ 3600;
    final minutes = (durationSeconds % 3600) ~/ 60;
    final seconds = durationSeconds % 60;
    final duration = hours > 0
        ? '${hours}h ${minutes.toString().padLeft(2, '0')}m'
        : '${minutes}m ${seconds.toString().padLeft(2, '0')}s';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            formatDistance(run.distanceMeters, UnitSystem.imperial),
            style: AppTypography.body,
          ),
          Text(duration, style: AppTypography.caption),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}
