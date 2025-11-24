import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workouts/models/session.dart';
import 'package:workouts/models/workout_block.dart';
import 'package:workouts/models/workout_exercise.dart';
import 'package:workouts/providers/active_session_provider.dart';
import 'package:workouts/providers/health_kit_provider.dart';
import 'package:workouts/providers/watch_connectivity_provider.dart';
import 'package:workouts/theme/app_theme.dart';
import 'package:workouts/widgets/expandable_cues.dart';
import 'package:workouts/widgets/heart_rate_timeline_card.dart';

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

enum _FinishAction { cancel, save, discard }

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
    final heartRateSamples = ref.watch(heartRateTimelineNotifierProvider);
    final watchStatus = ref.watch(watchConnectionStatusProvider).value ?? false;
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
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: _TimerDisplay(
                            duration: _elapsedDuration(session),
                            isPaused: session.isPaused,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      _BlockProgressIndicator(
                        currentIndex: _currentBlockIndex,
                        totalBlocks: session.blocks.length,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  swipeInstructions(session),
                  if (heartRateSamples.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.md),
                    HeartRateTimelineCard(samples: heartRateSamples),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  Row(
                    children: [
                      pauseButton(session),
                      if (session.isPaused) ...[
                        const SizedBox(width: AppSpacing.md),
                        pausedPill(),
                      ],
                      const SizedBox(width: AppSpacing.md),
                      _WatchConnectionIndicator(isConnected: watchStatus),
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

  Widget swipeInstructions(Session session) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Swipe or tap arrows to navigate blocks',
          style: AppTypography.caption.copyWith(color: AppColors.textColor4),
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
              onPressed: _currentBlockIndex < session.blocks.length - 1
                  ? () => _goToBlock(_currentBlockIndex + 1)
                  : null,
              child: Icon(
                CupertinoIcons.chevron_right,
                color: _currentBlockIndex < session.blocks.length - 1
                    ? AppColors.textColor2
                    : AppColors.textColor4,
                size: 20,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget pauseButton(Session session) {
    return CupertinoButton.filled(
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
    );
  }

  Widget pausedPill() {
    return Container(
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
    );
  }

  Duration _elapsedDuration(Session session) {
    final now = DateTime.now();
    var elapsed =
        now.difference(session.startedAt) - session.totalPausedDuration;

    if (session.isPaused && session.pausedAt != null) {
      elapsed -= now.difference(session.pausedAt!);
    }

    if (elapsed.isNegative) {
      return Duration.zero;
    }

    return elapsed;
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
    final action = await showCupertinoModalPopup<_FinishAction>(
      context: context,
      builder: (popupContext) => CupertinoActionSheet(
        title: const Text('Finish Session'),
        message: const Text('Choose how to wrap up your workout.'),
        actions: [
          CupertinoActionSheetAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(popupContext).pop(_FinishAction.save),
            child: const Text('Save Session'),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () =>
                Navigator.of(popupContext).pop(_FinishAction.discard),
            child: const Text('Discard Session'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(popupContext).pop(_FinishAction.cancel),
          child: const Text('Cancel'),
        ),
      ),
    );

    switch (action) {
      case _FinishAction.save:
        await ref.read(activeSessionNotifierProvider.notifier).complete();
        break;
      case _FinishAction.discard:
        await ref.read(activeSessionNotifierProvider.notifier).discard();
        break;
      case _FinishAction.cancel:
      case null:
        break;
    }
  }
}

class _BlockView extends StatefulWidget {
  const _BlockView({required this.block});

  final SessionBlock block;

  @override
  State<_BlockView> createState() => _BlockViewState();
}

class _BlockViewState extends State<_BlockView> {
  final _scrollController = ScrollController();
  final _exerciseKeys = <String, GlobalKey>{};

  @override
  void initState() {
    super.initState();
    for (final exercise in widget.block.exercises) {
      _exerciseKeys[exercise.id] = GlobalKey();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  String get label => switch (widget.block.type) {
    WorkoutBlockType.warmup => 'Warmup',
    WorkoutBlockType.animalFlow => 'Animal Flow',
    WorkoutBlockType.strength => 'Strength',
    WorkoutBlockType.mobility => 'Mobility',
    WorkoutBlockType.core => 'Core',
    WorkoutBlockType.conditioning => 'Conditioning',
    WorkoutBlockType.cooldown => 'Cooldown',
  };

  void _scrollToExercise(String exerciseId) {
    final key = _exerciseKeys[exerciseId];
    if (key?.currentContext != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Scrollable.ensureVisible(
          key!.currentContext!,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          alignment: 0.15,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasRoundInfo =
        widget.block.roundIndex != null && widget.block.totalRounds != null;
    final roundLabel = hasRoundInfo
        ? 'Round ${widget.block.roundIndex} of ${widget.block.totalRounds}'
        : null;
    final nextExerciseId = widget.block.nextIncompleteExercise?.id;
    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Text(label, style: AppTypography.title),
        if (roundLabel != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: AppColors.backgroundDepth3,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.borderDepth2),
            ),
            child: Text(
              roundLabel,
              style: AppTypography.caption.copyWith(
                color: AppColors.textColor3,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ] else
          const SizedBox(height: AppSpacing.sm),
        ...widget.block.exercises.map(
          (exercise) => _ExerciseCard(
            key: _exerciseKeys[exercise.id],
            block: widget.block,
            exercise: exercise,
            isNextRecommended: exercise.id == nextExerciseId,
            onSetLogged: () => _scrollToNext(exercise.id),
          ),
        ),
      ],
    );
  }

  void _scrollToNext(String currentExerciseId) {
    final currentIndex = widget.block.exercises.indexWhere(
      (e) => e.id == currentExerciseId,
    );
    if (currentIndex >= 0 && currentIndex < widget.block.exercises.length - 1) {
      final nextExercise = widget.block.exercises[currentIndex + 1];
      _scrollToExercise(nextExercise.id);
    }
  }
}

enum _TimerPhase { idle, setup, work, complete }

class _ExerciseCard extends ConsumerStatefulWidget {
  const _ExerciseCard({
    super.key,
    required this.block,
    required this.exercise,
    required this.isNextRecommended,
    required this.onSetLogged,
  });

  final SessionBlock block;
  final WorkoutExercise exercise;
  final bool isNextRecommended;
  final VoidCallback onSetLogged;

  @override
  ConsumerState<_ExerciseCard> createState() => _ExerciseCardState();
}

class _ExerciseCardState extends ConsumerState<_ExerciseCard> {
  Timer? _timer;
  Duration? _remaining;
  _TimerPhase _phase = _TimerPhase.idle;
  bool _isPaused = false;

  Duration get _setupDuration => widget.exercise.setupDuration ?? Duration.zero;

  Duration get _workDuration => widget.exercise.workDuration ?? Duration.zero;

  bool get _hasTiming =>
      _setupDuration > Duration.zero || _workDuration > Duration.zero;

  bool get _isRunningPhase =>
      _phase == _TimerPhase.setup || _phase == _TimerPhase.work;

  bool get _shouldAutoStart => widget.isNextRecommended && _hasTiming;

  SessionBlock get block => widget.block;
  WorkoutExercise get exercise => widget.exercise;

  @override
  void initState() {
    super.initState();
    print('🔍 ExerciseCard initState: ${exercise.name}');
    print('   isNextRecommended: ${widget.isNextRecommended}');
    print('   hasTiming: $_hasTiming');
    print('   setupDuration: $_setupDuration');
    print('   workDuration: $_workDuration');
    print('   shouldAutoStart: $_shouldAutoStart');
    if (_shouldAutoStart) {
      print('   ✅ Auto-starting timer');
      _startInitialPhase();
    } else {
      print('   ❌ NOT auto-starting');
    }
  }

  @override
  void didUpdateWidget(covariant _ExerciseCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_shouldAutoStart && !_isRunningPhase) {
      _startInitialPhase();
    } else if (!_shouldAutoStart && _phase != _TimerPhase.idle) {
      _resetTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final completedSets = _loggedSets;
    final targetSets = exercise.targetSets;
    final isComplete = targetSets > 0 && completedSets >= targetSets;
    final progressText = '$completedSets of $targetSets completed';
    final indicatorBackground = isComplete
        ? AppColors.success.withValues(alpha: 0.15)
        : AppColors.backgroundDepth3;
    final indicatorBorder = isComplete
        ? AppColors.success.withValues(alpha: 0.3)
        : AppColors.borderDepth2;
    final indicatorTextColor = isComplete
        ? AppColors.success
        : AppColors.textColor3;

    final expectedTiming =
        exercise.modality == ExerciseModality.timed &&
        exercise.prescription.contains('setup');
    final showTimingWarning = expectedTiming && !_hasTiming;

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
          if (exercise.restDuration != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Rest: ${_formatDuration(exercise.restDuration!)}',
              style: AppTypography.caption.copyWith(
                color: AppColors.textColor3,
              ),
            ),
          ],
          if (exercise.cues.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            ExpandableCues(cues: exercise.cues),
          ],
          if (showTimingWarning) ...[
            const SizedBox(height: AppSpacing.xs),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(
                  color: AppColors.warning.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                'Timer unavailable (old session). Start a new session for auto-timer.',
                style: AppTypography.caption.copyWith(color: AppColors.warning),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Row(
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
              const SizedBox(width: AppSpacing.sm),
              CupertinoButton(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                color: AppColors.backgroundDepth3,
                disabledColor: AppColors.backgroundDepth4,
                borderRadius: BorderRadius.circular(AppRadius.md),
                onPressed: _loggedSets == 0
                    ? null
                    : () => _unlogSet(context, ref),
                child: const Text(
                  'Unlog',
                  style: TextStyle(
                    color: CupertinoColors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: indicatorBackground,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(color: indicatorBorder),
                ),
                child: Text(
                  progressText,
                  style: AppTypography.caption.copyWith(
                    fontWeight: FontWeight.w500,
                    color: indicatorTextColor,
                  ),
                ),
              ),
            ],
          ),
          if (_hasTiming) ...[
            const SizedBox(height: AppSpacing.md),
            _TimerPanel(
              phase: _phase,
              remaining: _remaining,
              isPaused: _isPaused,
              onStart: _startInitialPhase,
              onPause: _pauseTimer,
              onResume: _resumeTimer,
              onReset: _resetTimer,
              onSkipToComplete: _skipToComplete,
              onAdjustTime: _adjustTime,
              canPause: _isRunningPhase && !_isPaused,
              canResume: _isRunningPhase && _isPaused,
              canStart: !_isRunningPhase,
              canReset: _phase != _TimerPhase.idle,
              canAdjust: _isRunningPhase,
              canSkip:
                  _phase != _TimerPhase.idle && _phase != _TimerPhase.complete,
              hasSetupPhase: _setupDuration > Duration.zero,
              hasWorkPhase: _workDuration > Duration.zero,
            ),
          ],
        ],
      ),
    );
  }

  int get _loggedSets {
    return block.logs.where((log) => log.exerciseId == exercise.id).length;
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    }
    return '${seconds}s';
  }

  Future<void> _logSet(BuildContext context, WidgetRef ref) async {
    await ref
        .read(activeSessionNotifierProvider.notifier)
        .logSet(block: block, exercise: exercise, reps: 1);
  }

  Future<void> _unlogSet(BuildContext context, WidgetRef ref) async {
    await ref
        .read(activeSessionNotifierProvider.notifier)
        .unlogSet(block: block, exercise: exercise);
  }

  void _startInitialPhase() {
    if (!_hasTiming) return;
    final phase = _setupDuration > Duration.zero
        ? _TimerPhase.setup
        : _TimerPhase.work;
    if (phase == _TimerPhase.work && _workDuration <= Duration.zero) {
      return;
    }
    _startPhase(phase);
  }

  void _startPhase(_TimerPhase phase) {
    final duration = _durationForPhase(phase);
    if (duration <= Duration.zero) {
      _advancePhase(phase);
      return;
    }
    setState(() {
      _phase = phase;
      _isPaused = false;
      _remaining = duration;
    });
    _startTicker();
  }

  void _startTicker() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
  }

  void _onTick() {
    if (!mounted || _isPaused || _remaining == null) {
      return;
    }
    final next = _remaining! - const Duration(seconds: 1);
    if (next <= Duration.zero) {
      _advancePhase(_phase);
    } else {
      setState(() {
        _remaining = next;
      });
    }
  }

  void _advancePhase(_TimerPhase phase) {
    if (phase == _TimerPhase.setup && _workDuration > Duration.zero) {
      _startPhase(_TimerPhase.work);
    } else {
      _completeTimer();
    }
  }

  void _completeTimer() {
    _timer?.cancel();
    setState(() {
      _phase = _TimerPhase.complete;
      _isPaused = false;
      _remaining = Duration.zero;
    });
    _logSetAndAdvance();
  }

  void _pauseTimer() {
    if (!_isRunningPhase || _isPaused) {
      return;
    }
    _timer?.cancel();
    setState(() {
      _isPaused = true;
    });
  }

  void _resumeTimer() {
    if (!_isRunningPhase || !_isPaused) {
      return;
    }
    setState(() {
      _isPaused = false;
    });
    _startTicker();
  }

  void _resetTimer() {
    _timer?.cancel();
    setState(() {
      _phase = _TimerPhase.idle;
      _isPaused = false;
      _remaining = null;
    });
  }

  void _skipToComplete() {
    _timer?.cancel();
    setState(() {
      _phase = _TimerPhase.complete;
      _isPaused = false;
      _remaining = Duration.zero;
    });
    _logSetAndAdvance();
  }

  Future<void> _logSetAndAdvance() async {
    await _logSet(context, ref);
    widget.onSetLogged();
  }

  void _adjustTime(int seconds) {
    if (!_isRunningPhase || _remaining == null) return;
    setState(() {
      final adjusted = _remaining! + Duration(seconds: seconds);
      _remaining = adjusted < Duration.zero ? Duration.zero : adjusted;
      if (_remaining == Duration.zero) {
        _advancePhase(_phase);
      }
    });
  }

  Duration _durationForPhase(_TimerPhase phase) {
    switch (phase) {
      case _TimerPhase.setup:
        return _setupDuration;
      case _TimerPhase.work:
        return _workDuration;
      case _TimerPhase.idle:
      case _TimerPhase.complete:
        return Duration.zero;
    }
  }
}

class _TimerPanel extends StatelessWidget {
  const _TimerPanel({
    required this.phase,
    required this.remaining,
    required this.isPaused,
    required this.onStart,
    required this.onPause,
    required this.onResume,
    required this.onReset,
    required this.onSkipToComplete,
    required this.onAdjustTime,
    required this.canPause,
    required this.canResume,
    required this.canStart,
    required this.canReset,
    required this.canAdjust,
    required this.canSkip,
    required this.hasSetupPhase,
    required this.hasWorkPhase,
  });

  final _TimerPhase phase;
  final Duration? remaining;
  final bool isPaused;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onReset;
  final VoidCallback onSkipToComplete;
  final void Function(int seconds) onAdjustTime;
  final bool canPause;
  final bool canResume;
  final bool canStart;
  final bool canReset;
  final bool canAdjust;
  final bool canSkip;
  final bool hasSetupPhase;
  final bool hasWorkPhase;

  String get _phaseLabel {
    return switch (phase) {
      _TimerPhase.setup => 'Setup',
      _TimerPhase.work => 'Work',
      _TimerPhase.complete => 'Complete',
      _TimerPhase.idle => hasSetupPhase || hasWorkPhase ? 'Ready' : 'Timer',
    };
  }

  String get _timeDisplay {
    if (remaining == null) {
      return '--:--';
    }
    final minutes = remaining!.inMinutes.remainder(60).abs();
    final seconds = remaining!.inSeconds.remainder(60).abs();
    final hours = remaining!.inHours;
    if (hours > 0) {
      final mins = minutes.toString().padLeft(2, '0');
      final secs = seconds.toString().padLeft(2, '0');
      return '${hours.toString().padLeft(2, '0')}:$mins:$secs';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.backgroundDepth3,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.borderDepth2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _phaseLabel,
                style: AppTypography.subtitle.copyWith(
                  color: AppColors.textColor3,
                ),
              ),
              Text(
                isPaused ? 'Paused' : '',
                style: AppTypography.caption.copyWith(
                  color: AppColors.textColor4,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            _timeDisplay,
            style: AppTypography.title.copyWith(
              letterSpacing: 1.2,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              if (canAdjust) ...[
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  color: AppColors.backgroundDepth4,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  onPressed: () => onAdjustTime(-10),
                  child: const Text(
                    '-10s',
                    style: TextStyle(
                      color: CupertinoColors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  color: AppColors.backgroundDepth4,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  onPressed: () => onAdjustTime(10),
                  child: const Text(
                    '+10s',
                    style: TextStyle(
                      color: CupertinoColors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
              ],
              Expanded(
                child: CupertinoButton.filled(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.sm,
                  ),
                  onPressed: canPause
                      ? onPause
                      : canResume
                      ? onResume
                      : canStart
                      ? onStart
                      : null,
                  child: Text(
                    canPause
                        ? 'Pause'
                        : canResume
                        ? 'Resume'
                        : 'Start',
                    style: const TextStyle(
                      color: CupertinoColors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Expanded(
                child: CupertinoButton(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  color: AppColors.backgroundDepth4,
                  disabledColor: AppColors.backgroundDepth4.withValues(
                    alpha: 0.5,
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  onPressed: canReset ? onReset : null,
                  child: const Text(
                    'Reset',
                    style: TextStyle(
                      color: CupertinoColors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: CupertinoButton(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  color: AppColors.success,
                  disabledColor: AppColors.backgroundDepth4.withValues(
                    alpha: 0.5,
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  onPressed: canSkip ? onSkipToComplete : null,
                  child: const Text(
                    'Mark Complete',
                    style: TextStyle(
                      color: CupertinoColors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TimerDisplay extends StatelessWidget {
  const _TimerDisplay({required this.duration, required this.isPaused});

  final Duration duration;
  final bool isPaused;

  @override
  Widget build(BuildContext context) {
    final safeDuration = duration.isNegative ? Duration.zero : duration;
    final hours = safeDuration.inHours;
    final minutes = safeDuration.inMinutes.remainder(60);
    final seconds = safeDuration.inSeconds.remainder(60);
    final timeLabel = hours > 0
        ? '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}'
        : '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    final statusLabel = isPaused ? 'Paused' : 'Elapsed';
    final statusColor = isPaused ? AppColors.warning : AppColors.textColor2;
    final timeStyle = AppTypography.displayLarge(context).copyWith(
      fontSize: 44,
      letterSpacing: 2.4,
      color: CupertinoColors.white,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final statusStyle = AppTypography.caption.copyWith(
      color: statusColor,
      letterSpacing: 1.2,
      fontWeight: FontWeight.w500,
    );

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.backgroundDepth5, AppColors.backgroundDepth3],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.borderDepth2),
        boxShadow: [
          BoxShadow(
            color: AppColors.accentPrimary.withValues(alpha: 0.22),
            blurRadius: 20,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(timeLabel, style: timeStyle),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(statusLabel, style: statusStyle),
        ],
      ),
    );
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

class _WatchConnectionIndicator extends StatelessWidget {
  const _WatchConnectionIndicator({required this.isConnected});

  final bool isConnected;

  @override
  Widget build(BuildContext context) {
    final color = isConnected ? AppColors.success : AppColors.textColor3;
    final background = isConnected
        ? AppColors.success.withValues(alpha: 0.15)
        : AppColors.backgroundDepth3;
    final icon = isConnected
        ? CupertinoIcons.check_mark_circled_solid
        : CupertinoIcons.exclamationmark_triangle_fill;
    final label = isConnected ? 'Watch connected' : 'Watch offline';

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: AppSpacing.xs),
          Text(label, style: AppTypography.caption.copyWith(color: color)),
        ],
      ),
    );
  }
}
