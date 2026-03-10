import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workouts/models/session.dart';
import 'package:workouts/providers/active_session_provider.dart';
import 'package:workouts/providers/health_kit_provider.dart';
import 'package:workouts/providers/watch_connectivity_provider.dart';
import 'package:workouts/theme/app_theme.dart';
import 'package:workouts/widgets/cardio_metrics_card.dart';
import 'package:workouts/widgets/session/add_note_sheet.dart';
import 'package:workouts/widgets/session/block_view.dart';
import 'package:workouts/widgets/session/session_indicators.dart';

class SessionResumeScreen extends ConsumerWidget {
  const SessionResumeScreen({super.key, required this.sessionId});

  final String sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionAsync = ref.watch(activeSessionProvider);

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
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Text(
              'Error loading session: $error',
              textAlign: TextAlign.center,
            ),
          ),
        ),
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
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
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
    final active = ref.watch(activeSessionProvider).value;
    final heartRateSamples = ref.watch(heartRateTimelineProvider);
    final watchStatus =
        ref.watch(watchConnectionStatusProvider).value ?? false;
    final session = active ?? widget.session;

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () =>
              ref.read(sessionUIVisibilityProvider.notifier).hide(),
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
                          child: SessionTimerDisplay(
                            duration: _elapsedDuration(session),
                            isPaused: session.isPaused,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      BlockProgressIndicator(
                        currentIndex: _currentBlockIndex,
                        totalBlocks: session.blocks.length,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _swipeInstructions(session),
                  const SizedBox(height: AppSpacing.md),
                  CardioMetricsCard(samples: heartRateSamples),
                  const SizedBox(height: AppSpacing.md),
                  _actionBar(session, watchStatus),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: pageController,
                itemCount: session.blocks.length,
                onPageChanged: (index) =>
                    setState(() => _currentBlockIndex = index),
                itemBuilder: (context, index) =>
                    BlockView(block: session.blocks[index]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _swipeInstructions(Session session) {
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

  Widget _actionBar(Session session, bool watchConnected) {
    return Row(
      children: [
        _pauseButton(session),
        if (session.isPaused) ...[
          const SizedBox(width: AppSpacing.md),
          _pausedPill(),
        ],
        const SizedBox(width: AppSpacing.md),
        _addNoteButton(session),
        const Spacer(),
        WatchConnectionIndicator(isConnected: watchConnected),
      ],
    );
  }

  Widget _pauseButton(Session session) {
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

  Widget _pausedPill() {
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

  Widget _addNoteButton(Session session) {
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      color: AppColors.backgroundDepth2,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      onPressed: () => _showAddNoteSheet(context, session),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            CupertinoIcons.pencil_outline,
            color: AppColors.textColor2,
            size: 16,
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            'Note',
            style: TextStyle(
              color: AppColors.textColor2,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _showAddNoteSheet(BuildContext context, Session session) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => AddNoteSheet(
        sessionId: session.id,
        currentBlockId: session.blocks.isNotEmpty
            ? session.blocks[_currentBlockIndex].id
            : null,
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

    return elapsed.isNegative ? Duration.zero : elapsed;
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
      await ref.read(activeSessionProvider.notifier).resume();
    } else {
      await ref.read(activeSessionProvider.notifier).pause();
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
            onPressed: () =>
                Navigator.of(popupContext).pop(_FinishAction.save),
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
          onPressed: () =>
              Navigator.of(popupContext).pop(_FinishAction.cancel),
          child: const Text('Cancel'),
        ),
      ),
    );

    switch (action) {
      case _FinishAction.save:
        await ref.read(activeSessionProvider.notifier).complete();
        break;
      case _FinishAction.discard:
        await ref.read(activeSessionProvider.notifier).discard();
        break;
      case _FinishAction.cancel:
      case null:
        break;
    }
  }
}
