import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workouts/features/active_session/active_session_provider.dart';
import 'package:workouts/features/active_session/add_note_sheet.dart';
import 'package:workouts/features/active_session/block_view.dart';
import 'package:workouts/features/active_session/session_resume/keyboard_enter_accessory.dart';
import 'package:workouts/features/active_session/session_resume/session_finish_sheet.dart';
import 'package:workouts/features/active_session/session_resume/session_resume_metrics_panel.dart';
import 'package:workouts/models/session.dart';
import 'package:workouts/providers/health_kit_provider.dart';
import 'package:workouts/providers/watch_connectivity_provider.dart';

class SessionResumeBody extends ConsumerStatefulWidget {
  const SessionResumeBody({super.key, required this.session});

  final Session session;

  @override
  ConsumerState<SessionResumeBody> createState() => _SessionResumeBodyState();
}

class _SessionResumeBodyState extends ConsumerState<SessionResumeBody> {
  final _pageController = PageController();
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

    return CupertinoPageScaffold(
      navigationBar: _navigationBar(context),
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
                    elapsedDuration: _elapsedDuration(session),
                    currentBlockIndex: _currentBlockIndex,
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

  CupertinoNavigationBar _navigationBar(BuildContext context) {
    return CupertinoNavigationBar(
      leading: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: () => ref.read(sessionUIVisibilityProvider.notifier).hide(),
        child: const Icon(CupertinoIcons.chevron_down),
      ),
      middle: const Text('Active Session'),
      trailing: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: () => _completeSession(context),
        child: const Text('Finish'),
      ),
    );
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
