import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workouts/features/active_session/exercise_history/exercise_history_provider.dart';
import 'package:workouts/features/active_session/session_detail/session_detail_screen.dart';
import 'package:workouts/features/active_session/session_detail/session_set_log_row.dart';
import 'package:workouts/models/exercise_history_entry.dart';
import 'package:workouts/models/session.dart';
import 'package:workouts/models/workout_exercise.dart';
import 'package:workouts/services/repositories/session/session_repository_powersync.dart';
import 'package:workouts/theme/app_theme.dart';
import 'package:workouts/utils/run_formatting.dart';

class ExerciseHistoryScreen extends ConsumerWidget {
  const ExerciseHistoryScreen({super.key, required this.exercise});

  final WorkoutExercise exercise;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(exerciseHistoryProvider(exercise.id));
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text('History: ${exercise.name}'),
      ),
      child: SafeArea(child: _body(historyAsync)),
    );
  }

  Widget _body(AsyncValue<List<ExerciseHistoryEntry>> historyAsync) {
    return historyAsync.when(
      data: (entries) => entries.isEmpty
          ? _emptyState()
          : _historyList(entries),
      loading: () => const Center(child: CupertinoActivityIndicator()),
      error: (error, _) => _errorView(error),
    );
  }

  Widget _emptyState() => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Text(
        'No completed sessions with ${exercise.name} yet.',
        textAlign: TextAlign.center,
        style: AppTypography.body.copyWith(color: AppColors.textColor3),
      ),
    ),
  );

  Widget _errorView(Object error) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Text(
        'Could not load history.\n$error',
        textAlign: TextAlign.center,
        style: AppTypography.body.copyWith(color: AppColors.error),
      ),
    ),
  );

  Widget _historyList(List<ExerciseHistoryEntry> entries) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      itemCount: entries.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (_, index) =>
          _SessionSection(entry: entries[index], exercise: exercise),
    );
  }
}

class _SessionSection extends ConsumerStatefulWidget {
  const _SessionSection({required this.entry, required this.exercise});

  final ExerciseHistoryEntry entry;
  final WorkoutExercise exercise;

  @override
  ConsumerState<_SessionSection> createState() => _SessionSectionState();
}

class _SessionSectionState extends ConsumerState<_SessionSection> {
  bool _isOpening = false;

  ExerciseHistoryEntry get entry => widget.entry;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.backgroundDepth2,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.borderDepth1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sessionDateHeader(),
          if (entry.sets.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            ..._setRows(),
            const SizedBox(height: AppSpacing.sm),
          ],
        ],
      ),
    );
  }

  Widget _sessionDateHeader() {
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      onPressed: _isOpening ? null : _openSessionDetail,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  Format.dateRelative(entry.completedAt),
                  style: AppTypography.subtitle,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(_subtitle, style: AppTypography.caption),
              ],
            ),
          ),
          _isOpening
              ? const CupertinoActivityIndicator(radius: 10)
              : const Icon(
                  CupertinoIcons.chevron_right,
                  size: 18,
                  color: AppColors.textColor3,
                ),
        ],
      ),
    );
  }

  String get _subtitle {
    final setCount = entry.sets.length;
    final setLabel = '$setCount ${setCount == 1 ? 'set' : 'sets'}';
    final templateName = entry.templateName;
    if (templateName == null || templateName.isEmpty) return setLabel;
    return '$templateName · $setLabel';
  }

  Iterable<Widget> _setRows() {
    return entry.sets.map(
      (log) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
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
        entry.sessionId,
      );
      if (!mounted) return;
      navigator.push<void>(
        CupertinoPageRoute(builder: (_) => SessionDetailScreen(session: session)),
      );
    } finally {
      if (mounted) setState(() => _isOpening = false);
    }
  }
}
