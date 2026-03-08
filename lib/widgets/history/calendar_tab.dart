import 'package:ethan_utils/ethan_utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workouts/models/activity_item.dart';
import 'package:workouts/models/fitness_run.dart';
import 'package:workouts/models/session.dart';
import 'package:workouts/providers/activity_provider.dart';
import 'package:workouts/providers/templates_provider.dart';
import 'package:workouts/providers/unit_system_provider.dart';
import 'package:workouts/screens/run_detail_screen.dart';
import 'package:workouts/screens/session_detail_screen.dart';
import 'package:workouts/theme/app_theme.dart';
import 'package:workouts/utils/run_formatting.dart';
import 'package:workouts/widgets/activity_calendar/activity_calendar.dart';

class HistoryCalendarTab extends ConsumerStatefulWidget {
  const HistoryCalendarTab({super.key});

  @override
  ConsumerState<HistoryCalendarTab> createState() => _HistoryCalendarTabState();
}

class _HistoryCalendarTabState extends ConsumerState<HistoryCalendarTab> {
  final _scrollController = ScrollController();
  bool _hasScrolledToBottom = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_hasScrolledToBottom) return;
    _hasScrolledToBottom = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(activityMetricsBackfillProvider);

    final calendarAsync = ref.watch(activityCalendarDaysProvider);
    final unitSystem = ref.watch(unitSystemProvider);

    return calendarAsync.when(
      data: (days) {
        final activityData = {for (final day in days) day.date: day};
        _scrollToBottom();
        return ListView(
          controller: _scrollController,
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            ActivityCalendar(
              activityData: activityData,
              unitSystem: unitSystem,
              onDateTap: (date) => _showDayDetail(context, date),
            ),
          ],
        );
      },
      loading: () => const Center(child: CupertinoActivityIndicator()),
      error: (error, _) => Center(
        child: Text(
          'Unable to load calendar: $error',
          style: AppTypography.body.copyWith(color: AppColors.error),
        ),
      ),
    );
  }

  void _showDayDetail(BuildContext context, DateTime date) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (_) => DayDetailSheet(date: date),
    );
  }
}

class DayDetailSheet extends ConsumerWidget {
  const DayDetailSheet({super.key, required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(activityForDateProvider(date));
    final unitSystem = ref.watch(unitSystemProvider);

    return CupertinoActionSheet(
      title: Text(Format.dateFull(date)),
      message: itemsAsync.when(
        data: (items) => items.isEmpty
            ? const Text('No activity on this day')
            : ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 300),
                child: SingleChildScrollView(
                  child:
                      DayDetailItemList(items: items, unitSystem: unitSystem),
                ),
              ),
        loading: () => const CupertinoActivityIndicator(),
        error: (_, __) => const Text('Unable to load'),
      ),
      cancelButton: CupertinoActionSheetAction(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Close'),
      ),
    );
  }

}

class DayDetailItemList extends StatelessWidget {
  const DayDetailItemList({
    super.key,
    required this.items,
    required this.unitSystem,
  });

  final List<ActivityItem> items;
  final UnitSystem unitSystem;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: items.map((item) {
        return switch (item) {
          ActivityRun(:final run) => CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () {
                Navigator.of(context).pop();
                context.push((_) => RunDetailScreen(run: run));
              },
              child: DayDetailRunRow(run: run, unitSystem: unitSystem),
            ),
          ActivitySession(:final session) => CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () {
                Navigator.of(context).pop();
                context.push((_) => SessionDetailScreen(session: session));
              },
              child: DayDetailSessionRow(session: session),
            ),
        };
      }).toList(),
    );
  }
}

class DayDetailRunRow extends StatelessWidget {
  const DayDetailRunRow({
    super.key,
    required this.run,
    required this.unitSystem,
  });

  final FitnessRun run;
  final UnitSystem unitSystem;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(CupertinoIcons.location_solid, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Text(
                Format.distance(run.distanceMeters, unitSystem),
                style: AppTypography.body,
              ),
            ],
          ),
          Text(
            Format.durationShort(run.durationSeconds),
            style: AppTypography.caption,
          ),
        ],
      ),
    );
  }
}

class DayDetailSessionRow extends ConsumerWidget {
  const DayDetailSessionRow({super.key, required this.session});

  final Session session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templatesMapAsync = ref.watch(templatesMapProvider);
    final duration = session.duration != null
        ? '${session.duration!.inMinutes}m'
        : '—';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(CupertinoIcons.clock, size: 20),
              const SizedBox(width: AppSpacing.sm),
              templatesMapAsync.when(
                data: (templatesMap) {
                  final template = templatesMap[session.templateId];
                  return Text(
                    template?.name ?? 'Session',
                    style: AppTypography.body,
                  );
                },
                loading: () =>
                    const Text('…', style: AppTypography.body),
                error: (_, __) =>
                    const Text('Session', style: AppTypography.body),
              ),
            ],
          ),
          Text(duration, style: AppTypography.caption),
        ],
      ),
    );
  }
}
