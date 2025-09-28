import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workouts/models/session.dart';
import 'package:workouts/models/workout_block.dart';
import 'package:workouts/models/workout_exercise.dart';
import 'package:workouts/providers/active_session_provider.dart';
import 'package:workouts/theme/app_theme.dart';

class SessionResumeScreen extends ConsumerWidget {
  const SessionResumeScreen({super.key, required this.sessionId});

  final String sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionAsync = ref.watch(activeSessionNotifierProvider);

    return sessionAsync.when(
      data: (session) => session == null
          ? const CupertinoPageScaffold(
              child: Center(child: Text('No active session.')),
            )
          : _SessionView(session: session),
      loading: () => const CupertinoPageScaffold(
        child: Center(child: CupertinoActivityIndicator()),
      ),
      error: (error, _) => CupertinoPageScaffold(
        child: Center(child: Text('Error loading session: $error')),
      ),
    );
  }
}

class _SessionView extends ConsumerStatefulWidget {
  const _SessionView({required this.session});

  final Session session;

  @override
  ConsumerState<_SessionView> createState() => _SessionViewState();
}

class _SessionViewState extends ConsumerState<_SessionView> {
  final pageController = PageController();
  Timer? _timer;
  int _currentBlockIndex = 0;

  @override
  void initState() {
    super.initState();
    // Update timer every second to show elapsed time
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final active = ref.watch(activeSessionNotifierProvider).value;
    final session = active ?? widget.session;
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () =>
              ref.read(sessionUIVisibilityNotifierProvider.notifier).hide(),
          child: const Icon(CupertinoIcons.chevron_down),
        ),
        middle: const Text('Active Session'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => _completeSession(context),
          child: const Text('Finish'),
        ),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _sessionDuration(session),
                        style: AppTypography.subtitle,
                      ),
                      _BlockProgressIndicator(
                        currentIndex: _currentBlockIndex,
                        totalBlocks: session.blocks.length,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Swipe or tap arrows to navigate blocks',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textColor4,
                        ),
                      ),
                      Row(
                        children: [
                          CupertinoButton(
                            padding: const EdgeInsets.all(AppSpacing.xs),
                            onPressed: _currentBlockIndex > 0
                                ? () => _goToBlock(_currentBlockIndex - 1)
                                : null,
                            child: Icon(
                              CupertinoIcons.chevron_left,
                              color: _currentBlockIndex > 0
                                  ? AppColors.textColor2
                                  : AppColors.textColor4,
                              size: 20,
                            ),
                          ),
                          CupertinoButton(
                            padding: const EdgeInsets.all(AppSpacing.xs),
                            onPressed:
                                _currentBlockIndex < session.blocks.length - 1
                                ? () => _goToBlock(_currentBlockIndex + 1)
                                : null,
                            child: Icon(
                              CupertinoIcons.chevron_right,
                              color:
                                  _currentBlockIndex < session.blocks.length - 1
                                  ? AppColors.textColor2
                                  : AppColors.textColor4,
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      CupertinoButton.filled(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg,
                          vertical: AppSpacing.sm,
                        ),
                        onPressed: () => _togglePause(session),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              session.isPaused
                                  ? CupertinoIcons.play_fill
                                  : CupertinoIcons.pause_fill,
                              color: CupertinoColors.white,
                              size: 16,
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Text(
                              session.isPaused ? 'Resume' : 'Pause',
                              style: const TextStyle(
                                color: CupertinoColors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (session.isPaused) ...[
                        const SizedBox(width: AppSpacing.md),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: AppSpacing.sm,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                            border: Border.all(color: AppColors.warning),
                          ),
                          child: Text(
                            'Paused',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.warning,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: pageController,
                itemCount: session.blocks.length,
                onPageChanged: (index) {
                  setState(() {
                    _currentBlockIndex = index;
                  });
                },
                itemBuilder: (context, index) =>
                    _BlockView(block: session.blocks[index]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _sessionDuration(Session session) {
    final now = DateTime.now();
    var elapsed =
        now.difference(session.startedAt) - session.totalPausedDuration;

    // If currently paused, don't count the current pause time
    if (session.isPaused && session.pausedAt != null) {
      elapsed -= now.difference(session.pausedAt!);
    }

    final minutes = elapsed.inMinutes;
    final seconds = elapsed.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')} ${session.isPaused ? '(paused)' : 'elapsed'}';
  }

  void _goToBlock(int index) {
    pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _togglePause(Session session) async {
    if (session.isPaused) {
      await ref.read(activeSessionNotifierProvider.notifier).resume();
    } else {
      await ref.read(activeSessionNotifierProvider.notifier).pause();
    }
  }

  Future<void> _completeSession(BuildContext context) async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Complete Workout?'),
        content: const Text(
          'This will mark your session as finished and save it to your history.',
        ),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Complete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(activeSessionNotifierProvider.notifier).complete();
    }
  }
}

class _BlockView extends StatelessWidget {
  const _BlockView({required this.block});

  final SessionBlock block;

  String get label => switch (block.type) {
    WorkoutBlockType.warmup => 'Warmup',
    WorkoutBlockType.animalFlow => 'Animal Flow',
    WorkoutBlockType.strength => 'Strength',
    WorkoutBlockType.mobility => 'Mobility',
    WorkoutBlockType.cooldown => 'Cooldown',
  };

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Text(label, style: AppTypography.title),
        const SizedBox(height: AppSpacing.sm),
        ...block.exercises.map(
          (exercise) => _ExerciseCard(block: block, exercise: exercise),
        ),
      ],
    );
  }
}

class _ExerciseCard extends ConsumerWidget {
  const _ExerciseCard({required this.block, required this.exercise});

  final SessionBlock block;
  final WorkoutExercise exercise;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.backgroundDepth2,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.borderDepth1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(exercise.name, style: AppTypography.subtitle),
              ),
              Text(exercise.prescription, style: AppTypography.caption),
            ],
          ),
          if (exercise.cue != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(exercise.cue!, style: AppTypography.caption),
          ],
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              CupertinoButton.filled(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.sm,
                ),
                onPressed: () => _logSet(context, ref),
                child: const Text(
                  'Log Set',
                  style: TextStyle(
                    color: CupertinoColors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: AppColors.backgroundDepth3,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(color: AppColors.borderDepth2),
                ),
                child: Text(
                  _getProgressText(),
                  style: AppTypography.caption.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  int _getLoggedSets() {
    return block.logs.where((log) => log.exerciseId == exercise.id).length;
  }

  String _getProgressText() {
    final completed = _getLoggedSets();
    final target = exercise.targetSets;
    return '$completed of $target completed';
  }

  Future<void> _logSet(BuildContext context, WidgetRef ref) async {
    await ref
        .read(activeSessionNotifierProvider.notifier)
        .logSet(block: block, exercise: exercise, reps: 1);
  }
}

class _BlockProgressIndicator extends StatelessWidget {
  const _BlockProgressIndicator({
    required this.currentIndex,
    required this.totalBlocks,
  });

  final int currentIndex;
  final int totalBlocks;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.backgroundDepth3,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.borderDepth2),
      ),
      child: Text(
        '${currentIndex + 1} of $totalBlocks',
        style: AppTypography.caption.copyWith(fontWeight: FontWeight.w500),
      ),
    );
  }
}
