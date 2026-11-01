import 'package:ethan_ui/ethan_ui.dart';
import 'package:ethan_utils/ethan_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workouts/features/active_session/active_session_provider.dart';
import 'package:workouts/models/session.dart';

/// Shows the running or paused workout above [child] while its session UI
/// is hidden, with an Open button that brings the session back.
class const ActiveSessionBanner({required final Widget child})
    extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Session? session = ref.watch(activeSessionProvider).value;
    final bool sessionUIVisible = ref.watch(sessionUIVisibilityProvider);
    return Column(
      children: [
        if (session != null && !sessionUIVisible) _banner(ref, session),
        Expanded(child: child),
      ],
    );
  }

  Widget _banner(WidgetRef ref, Session session) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(ELayout.spaceMd),
      decoration: BoxDecoration(
        color: session.isPaused ? EColors.warning : EColors.accent,
        border: Border(bottom: BorderSide(color: EColors.borderStrong)),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            Icon(
              session.isPaused ? Icons.pause_circle : Icons.play_circle,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: ELayout.spaceSm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [_pausedOrActive(session), _elapsedTime(session)],
              ),
            ),
            _openButton(ref),
          ],
        ),
      ),
    );
  }

  Widget _pausedOrActive(Session session) {
    return Text(
      session.isPaused ? 'Workout Paused' : 'Workout Active',
      style: const TextStyle(
        color: Colors.white,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _elapsedTime(Session session) {
    return Text(
      '${_elapsed(session).formattedClock} elapsed',
      style: const TextStyle(
        color: Colors.white,
        fontSize: 12,
        fontWeight: FontWeight.w400,
      ),
    );
  }

  Widget _openButton(WidgetRef ref) {
    return TextButton(
      onPressed: () => ref.read(sessionUIVisibilityProvider.notifier).show(),
      child: const Text(
        'Open',
        style: TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Duration _elapsed(Session session) {
    final now = DateTime.now();
    var elapsed =
        now.difference(session.startedAt) - session.totalPausedDuration;
    if (session.isPaused && session.pausedAt != null) {
      elapsed -= now.difference(session.pausedAt!);
    }
    return elapsed;
  }
}
