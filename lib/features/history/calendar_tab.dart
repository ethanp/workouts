import 'package:ethan_utils/ethan_utils.dart';
import 'package:ethan_ui/ethan_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workouts/models/activity_item.dart';
import 'package:workouts/models/cardio_workout.dart';
import 'package:workouts/models/session.dart';
import 'package:workouts/features/history/activity_provider.dart';
import 'package:workouts/features/library/templates_provider.dart';
import 'package:workouts/features/cardio/cardio_detail_screen.dart';
import 'package:workouts/features/active_session/session_detail/session_detail_screen.dart';
import 'package:workouts/utils/run_formatting.dart';
import 'package:workouts/features/history/activity_calendar.dart';

class const HistoryCalendarTab() extends ConsumerStatefulWidget {
  @override
  ConsumerState<HistoryCalendarTab> createState() => _HistoryCalendarTabState();
}

class _HistoryCalendarTabState() extends ConsumerState<HistoryCalendarTab> {
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
    final calendarAsync = ref.watch(activityCalendarDaysProvider);

    return calendarAsync.when(
      data: (days) {
        final activityData = {for (final day in days) day.date: day};
        _scrollToBottom();
        return ListView(
          controller: _scrollController,
          padding: const EdgeInsets.all(ELayout.spaceLg),
          children: [
            ActivityCalendar(
              activityData: activityData,
              onDateSelected: (date) => _showDayDetail(context, date),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Text(
          'Unable to load calendar: $error',
          style: EText.body.medium.copyWith(color: EColors.danger),
        ),
      ),
    );
  }

  void _showDayDetail(BuildContext context, DateTime date) {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => DayDetailSheet(date: date),
    );
  }
}

class const DayDetailSheet({required final DateTime date})
    extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(activityForDateProvider(date));

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(ELayout.spaceLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(Format.dateFull(date), style: EText.section),
            const SizedBox(height: ELayout.spaceMd),
            itemsAsync.when(
              data: (items) => items.isEmpty
                  ? const Text('No activity on this day')
                  : ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 300),
                      child: SingleChildScrollView(
                        child: DayDetailItemList(items: items),
                      ),
                    ),
              loading: () => const CircularProgressIndicator(),
              error: (_, _) => const Text('Unable to load'),
            ),
            const SizedBox(height: ELayout.spaceMd),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }
}

class const DayDetailItemList({required final List<ActivityItem> items})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: items.map((item) {
        return switch (item) {
          ActivityCardio(:final workout) => InkWell(
            onTap: () {
              Navigator.of(context).pop();
              context.push(CardioDetailScreen(workout: workout));
            },
            child: DayDetailCardioRow(workout: workout),
          ),
          ActivitySession(:final session) => InkWell(
            onTap: () {
              Navigator.of(context).pop();
              context.push(SessionDetailScreen(session: session));
            },
            child: DayDetailSessionRow(session: session),
          ),
        };
      }).toList(),
    );
  }
}

class const DayDetailCardioRow({required final CardioWorkout workout})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: ELayout.spaceSm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.local_fire_department, size: 20),
              const SizedBox(width: ELayout.spaceSm),
              Text(_label(), style: EText.body.medium),
            ],
          ),
          Text(
            Format.durationShort(workout.durationSeconds),
            style: EText.caption,
          ),
        ],
      ),
    );
  }

  String _label() {
    if (workout.activityType.hasDistance && workout.distanceMeters > 0) {
      return '${workout.activityType.displayName} · ${Format.distance(workout.distanceMeters)}';
    }
    return workout.activityType.displayName;
  }
}

class const DayDetailSessionRow({required final Session session})
    extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templatesMapAsync = ref.watch(templatesMapProvider);
    final duration = session.duration != null
        ? '${session.duration!.inMinutes}m'
        : '—';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: ELayout.spaceSm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.schedule, size: 20),
              const SizedBox(width: ELayout.spaceSm),
              templatesMapAsync.when(
                data: (templatesMap) {
                  final template = templatesMap[session.templateId];
                  return Text(
                    template?.name ?? 'Session',
                    style: EText.body.medium,
                  );
                },
                loading: () => Text('…', style: EText.body.medium),
                error: (_, _) =>
                    Text('Session', style: EText.body.medium),
              ),
            ],
          ),
          Text(duration, style: EText.caption),
        ],
      ),
    );
  }
}
