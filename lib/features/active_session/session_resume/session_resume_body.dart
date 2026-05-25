import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workouts/features/active_session/active_session_provider.dart';
import 'package:workouts/features/active_session/add_note_sheet.dart';
import 'package:workouts/features/active_session/block_progress.dart';
import 'package:workouts/features/active_session/block_view.dart';
import 'package:workouts/features/active_session/early_stopped_notifier.dart';
import 'package:workouts/features/active_session/session_resume/keyboard_enter_accessory.dart';
import 'package:workouts/features/active_session/session_resume/session_finish_sheet.dart';
import 'package:workouts/features/active_session/session_resume/session_resume_metrics_panel.dart';
import 'package:workouts/models/session.dart';
import 'package:workouts/providers/health_kit_provider.dart';
import 'package:workouts/providers/watch_connectivity_provider.dart';
import 'package:workouts/theme/app_theme.dart';

class SessionResumeBody extends ConsumerStatefulWidget {
  const SessionResumeBody({super.key, required this.session});

  final Session session;

  @override
  ConsumerState<SessionResumeBody> createState() => _SessionResumeBodyState();
}

class _SessionResumeBodyState extends ConsumerState<SessionResumeBody> {
  late final PageController _pageController;
  Timer? _timer;
  late int _currentBlockIndex;

  /// Session id we've already auto-shown the finish sheet for. Prevents
  /// the prompt from re-appearing if the user dismisses it and then keeps
  /// poking around (or if the all-done signal flickers off and back on
  /// because they unlogged a set and then re-logged it).
  String? _autoPromptedSessionId;

  /// Block indices we have already auto-scrolled away from after they
  /// became done. Tracking the set (rather than just "last index") means
  /// a manual back-swipe to a completed earlier block doesn't re-trigger
  /// the auto-advance.
  final Set<int> _autoAdvancedFromBlocks = {};

  /// How long to leave the just-completed block on screen before sliding
  /// to the next one. Long enough for the green-tinted "all done" cards
  /// to register visually; short enough to not feel sluggish.
  static const _autoAdvanceDelay = Duration(milliseconds: 700);

  @override
  void initState() {
    super.initState();
    // Resume on the block that still has work — i.e. the first block whose
    // exercises aren't all either fully logged or marked stopped-early.
    // Otherwise opening a part-finished session always lands on block 1
    // even if the user is on block 4.
    _currentBlockIndex = _firstBlockWithWork(widget.session);
    _pageController = PageController(initialPage: _currentBlockIndex);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  /// Returns the index of the first block in [session] that has at least one
  /// exercise that is neither fully logged nor flagged as early-stopped.
  /// Falls back to 0 when every block is complete — the all-done auto
  /// prompt handles the next-step UX from there.
  int _firstBlockWithWork(Session session) {
    for (var blockIndex = 0; blockIndex < session.blocks.length; blockIndex++) {
      final progress = ref.read(
        blockProgressProvider(session.blocks[blockIndex]),
      );
      if (progress.firstUnfinishedExercise() != null) return blockIndex;
    }
    return 0;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Session? activeSession = ref.watch(activeSessionProvider).value;
    final heartRateSamples = ref.watch(heartRateTimelineProvider);
    final bool watchConnected =
        ref.watch(watchConnectionStatusProvider).value ?? false;
    final Session session = activeSession ?? widget.session;
    final bool keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;

    ref.listen<bool>(sessionAllExercisesDoneProvider, (previous, next) {
      if (!next) return;
      if (_autoPromptedSessionId == session.id) return;
      _autoPromptedSessionId = session.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _completeSession(context);
      });
    });

    _maybeAutoAdvanceBlock(session);

    return CupertinoPageScaffold(
      navigationBar: _navigationBar(context, session),
      child: SafeArea(
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!keyboardVisible)
                  SessionResumeMetricsPanel(
                    session: session,
                    heartRateSamples: heartRateSamples,
                    watchConnected: watchConnected,
                    onPreviousBlock: _canGoPrevious ? _goToPreviousBlock : null,
                    onNextBlock: _canGoNext(session) ? _goToNextBlock : null,
                    onTogglePause: () => _togglePause(session),
                    onAddNote: () => _showAddNoteSheet(context, session),
                  ),
                _blockPager(session),
              ],
            ),
            if (keyboardVisible) KeyboardEnterAccessory(onPressed: _dismissKeyboard),
          ],
        ),
      ),
    );
  }

  bool get _canGoPrevious => _currentBlockIndex > 0;

  bool _canGoNext(Session session) {
    return _currentBlockIndex < session.blocks.length - 1;
  }

  CupertinoNavigationBar _navigationBar(BuildContext context, Session session) {
    return CupertinoNavigationBar(
      leading: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: () => ref.read(sessionUIVisibilityProvider.notifier).hide(),
        child: const Icon(CupertinoIcons.chevron_down),
      ),
      middle: _navigationBarMiddle(session),
      trailing: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: () => _completeSession(context),
        child: const Text('Finish'),
      ),
    );
  }

  Widget _navigationBarMiddle(Session session) {
    final timeColor = session.isPaused
        ? AppColors.warning
        : AppColors.textColor1;
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          _formatElapsed(_elapsedDuration(session)),
          style: AppTypography.body.copyWith(
            fontWeight: FontWeight.w600,
            color: timeColor,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        if (session.blocks.isNotEmpty)
          Text(
            session.isPaused
                ? 'Paused · Block ${_currentBlockIndex + 1} of ${session.blocks.length}'
                : 'Block ${_currentBlockIndex + 1} of ${session.blocks.length}',
            style: AppTypography.caption.copyWith(
              color: AppColors.textColor3,
              fontSize: 11,
            ),
          ),
      ],
    );
  }

  String _formatElapsed(Duration elapsed) {
    final totalSeconds = elapsed.inSeconds;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    final mm = minutes.toString().padLeft(2, '0');
    final ss = seconds.toString().padLeft(2, '0');
    if (hours > 0) return '${hours.toString().padLeft(2, '0')}:$mm:$ss';
    return '$mm:$ss';
  }

  Widget _blockPager(Session session) {
    return Expanded(
      child: PageView.builder(
        controller: _pageController,
        itemCount: session.blocks.length,
        onPageChanged: (int blockIndex) {
          setState(() => _currentBlockIndex = blockIndex);
        },
        itemBuilder: (context, blockIndex) {
          return BlockView(block: session.blocks[blockIndex]);
        },
      ),
    );
  }

  Duration _elapsedDuration(Session session) {
    Duration elapsed =
        DateTime.now().difference(session.startedAt) -
        session.totalPausedDuration;

    if (session.isPaused && session.pausedAt != null) {
      elapsed -= DateTime.now().difference(session.pausedAt!);
    }

    return elapsed.isNegative ? Duration.zero : elapsed;
  }

  /// When the current block's exercises are all logged or stopped-early,
  /// slide to the next block. Skips when this is the last block (the
  /// session-all-done listener handles the finish prompt instead) or when
  /// we've already auto-advanced from this block in this session.
  void _maybeAutoAdvanceBlock(Session session) {
    if (session.blocks.isEmpty) return;
    if (_currentBlockIndex >= session.blocks.length - 1) return;
    if (_autoAdvancedFromBlocks.contains(_currentBlockIndex)) return;
    final block = session.blocks[_currentBlockIndex];
    if (!ref.watch(blockProgressProvider(block)).allComplete) return;

    final triggeredFromBlock = _currentBlockIndex;
    _autoAdvancedFromBlocks.add(triggeredFromBlock);
    Future.delayed(_autoAdvanceDelay, () {
      if (!mounted) return;
      // Don't fight a manual page change that landed during the delay,
      // and don't loop past the end of the session.
      if (_currentBlockIndex != triggeredFromBlock) return;
      if (_currentBlockIndex >= session.blocks.length - 1) return;
      _goToBlock(_currentBlockIndex + 1);
    });
  }

  void _goToPreviousBlock() => _goToBlock(_currentBlockIndex - 1);

  void _goToNextBlock() => _goToBlock(_currentBlockIndex + 1);

  void _goToBlock(int blockIndex) {
    _pageController.animateToPage(
      blockIndex,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _dismissKeyboard() {
    FocusManager.instance.primaryFocus?.unfocus();
  }

  void _showAddNoteSheet(BuildContext context, Session session) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (context) => AddNoteSheet(
        sessionId: session.id,
        currentBlockId: session.blocks.isEmpty
            ? null
            : session.blocks[_currentBlockIndex].id,
      ),
    );
  }

  Future<void> _togglePause(Session session) async {
    final activeSessionNotifier = ref.read(activeSessionProvider.notifier);
    if (session.isPaused) {
      await activeSessionNotifier.resume();
      return;
    }
    await activeSessionNotifier.pause();
  }

  Future<void> _completeSession(BuildContext context) async {
    final SessionFinishAction? action = await SessionFinishSheet.show(context);
    final activeSessionNotifier = ref.read(activeSessionProvider.notifier);
    switch (action) {
      case SessionFinishAction.save:
        await activeSessionNotifier.complete();
        break;
      case SessionFinishAction.discard:
        await activeSessionNotifier.discard();
        break;
      case SessionFinishAction.cancel:
      case null:
        break;
    }
  }
}
