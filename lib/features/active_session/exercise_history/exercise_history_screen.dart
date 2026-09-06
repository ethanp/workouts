import 'package:flutter/material.dart';
import 'package:ethan_ui/ethan_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workouts/features/active_session/exercise_history/exercise_history_provider.dart';
import 'package:workouts/features/active_session/session_detail/session_detail_screen.dart';
import 'package:workouts/features/active_session/session_detail/session_set_log_row.dart';
import 'package:workouts/models/exercise_history_entry.dart';
import 'package:workouts/models/session.dart';
import 'package:workouts/models/workout_exercise.dart';
import 'package:workouts/services/repositories/session/session_repository_powersync.dart';
import 'package:workouts/utils/run_formatting.dart';

class const ExerciseHistoryScreen({required final WorkoutExercise exercise})
    extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(exerciseHistoryProvider(exercise.id));
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: EAppHeader(title: 'History: ${exercise.name}'),
      body: SafeArea(child: _body(historyAsync)),
    );
  }

  Widget _body(AsyncValue<List<ExerciseHistoryEntry>> historyAsync) {
    return historyAsync.when(
      data: (entries) =>
          entries.isEmpty ? _emptyState() : _historyList(entries),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _errorView(error),
    );
  }

  Widget _emptyState() => Center(
    child: Padding(
      padding: const EdgeInsets.all(ELayout.spaceLg),
      child: Text(
        'No completed sessions with ${exercise.name} yet.',
        textAlign: TextAlign.center,
        style: EText.body.medium.copyWith(color: EColors.textTertiary),
      ),
    ),
  );

  Widget _errorView(Object error) => Center(
    child: Padding(
      padding: const EdgeInsets.all(ELayout.spaceLg),
      child: Text(
        'Could not load history.\n$error',
        textAlign: TextAlign.center,
        style: EText.body.medium.copyWith(color: EColors.danger),
      ),
    ),
  );

  Widget _historyList(List<ExerciseHistoryEntry> entries) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(
        horizontal: ELayout.spaceMd,
        vertical: ELayout.spaceMd,
      ),
      itemCount: entries.length,
      separatorBuilder: (_, _) => const SizedBox(height: ELayout.spaceMd),
      itemBuilder: (_, index) =>
          _SessionSection(entry: entries[index], exercise: exercise),
    );
  }
}

class const _SessionSection({
  required final ExerciseHistoryEntry entry,
  required final WorkoutExercise exercise,
}) extends ConsumerStatefulWidget {
  @override
  ConsumerState<_SessionSection> createState() => _SessionSectionState();
}

class _SessionSectionState() extends ConsumerState<_SessionSection> {
  bool _isOpening = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: EColors.backgroundLift,
        borderRadius: BorderRadius.circular(ELayout.radiusXl),
        border: Border.all(color: EColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sessionDateHeader(),
          if (widget.entry.sets.isNotEmpty) ...[
            const SizedBox(height: ELayout.spaceXs),
            ..._setRows(),
            const SizedBox(height: ELayout.spaceSm),
          ],
        ],
      ),
    );
  }

  Widget _sessionDateHeader() {
    return InkWell(
      onTap: _isOpening ? null : _openSessionDetail,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: ELayout.spaceMd,
          vertical: ELayout.spaceSm,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    Format.dateRelative(widget.entry.completedAt),
                    style: EText.section,
                  ),
                  const SizedBox(height: ELayout.spaceXs),
                  Text(_subtitle, style: EText.caption),
                ],
              ),
            ),
            _isOpening
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: EColors.textTertiary,
                  ),
          ],
        ),
      ),
    );
  }

  String get _subtitle {
    final setCount = widget.entry.sets.length;
    final setLabel = '$setCount ${setCount == 1 ? 'set' : 'sets'}';
    final templateName = widget.entry.templateName;
    if (templateName == null || templateName.isEmpty) return setLabel;
    return '$templateName · $setLabel';
  }

  Iterable<Widget> _setRows() {
    return widget.entry.sets.map(
      (log) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: ELayout.spaceMd),
        child: SessionSetLogRow(log: log, exercise: widget.exercise),
      ),
    );
  }

  Future<void> _openSessionDetail() async {
    setState(() => _isOpening = true);
    final NavigatorState navigator = Navigator.of(context);
    final repository = ref.read(sessionRepositoryPowerSyncProvider);
    try {
      final Session session = await repository.fetchSessionById(
        widget.entry.sessionId,
      );
      if (!mounted) return;
      navigator.push<void>(
        MaterialPageRoute(
          builder: (_) => SessionDetailScreen(session: session),
        ),
      );
    } finally {
      if (mounted) setState(() => _isOpening = false);
    }
  }
}
