import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workouts/models/session.dart';
import 'package:workouts/providers/active_session_provider.dart';
import 'package:workouts/screens/goals_screen.dart';
import 'package:workouts/screens/history_screen.dart';
import 'package:workouts/screens/session_resume_screen.dart';
import 'package:workouts/screens/today_screen.dart';
import 'package:workouts/theme/app_theme.dart';

class MainTabScreen extends ConsumerStatefulWidget {
  const MainTabScreen({super.key});

  @override
  ConsumerState<MainTabScreen> createState() => _MainTabScreenState();
}

class _MainTabScreenState extends ConsumerState<MainTabScreen> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    final activeSession = ref.watch(activeSessionProvider);
    final sessionUIVisible = ref.watch(sessionUIVisibilityProvider);

    // Auto-hide session UI if there's no active session
    if (sessionUIVisible && activeSession.value == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(sessionUIVisibilityProvider.notifier).hide();
      });
    }

    // If session UI is visible and there's an active session, show the session screen
    if (sessionUIVisible && activeSession.value != null) {
      return SessionResumeScreen(sessionId: activeSession.value!.id);
    }

    return CupertinoTabScaffold(
      tabBar: CupertinoTabBar(
        items: const [
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.house_alt),
            label: 'Today',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.flag),
            label: 'Goals',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.chart_bar_square),
            label: 'History',
          ),
        ],
        currentIndex: index,
        onTap: (value) => setState(() => index = value),
      ),
      tabBuilder: (context, selectedIndex) {
        return CupertinoTabView(
          builder: (context) {
            final screen = switch (selectedIndex) {
              0 => const TodayScreen(),
              1 => const GoalsScreen(),
              _ => const HistoryScreen(),
            };

            // Wrap screen with active session banner if there's an active session
            return activeSession.when(
              data: (session) => session != null && !sessionUIVisible
                  ? _ActiveSessionWrapper(child: screen)
                  : screen,
              loading: () => screen,
              error: (_, __) => screen,
            );
          },
        );
      },
    );
  }
}

class _ActiveSessionWrapper extends ConsumerWidget {
  const _ActiveSessionWrapper({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(activeSessionProvider).value;

    // Session may become null during discard - just show child
    if (session == null) return child;

    return Column(
      children: [
        _ActiveSessionBanner(session: session),
        Expanded(child: child),
      ],
    );
  }
}

class _ActiveSessionBanner extends ConsumerWidget {
  const _ActiveSessionBanner({required this.session});

  final Session session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: session.isPaused ? AppColors.warning : AppColors.accentPrimary,
        border: Border(bottom: BorderSide(color: AppColors.borderDepth2)),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            Icon(
              session.isPaused
                  ? CupertinoIcons.pause_circle
                  : CupertinoIcons.play_circle,
              color: CupertinoColors.white,
              size: 20,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session.isPaused ? 'Workout Paused' : 'Workout Active',
                    style: const TextStyle(
                      color: CupertinoColors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    _getElapsedTime(session),
                    style: const TextStyle(
                      color: CupertinoColors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              onPressed: () =>
                  ref.read(sessionUIVisibilityProvider.notifier).show(),
              child: const Text(
                'Open',
                style: TextStyle(
                  color: CupertinoColors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getElapsedTime(Session session) {
    final now = DateTime.now();
    var elapsed =
        now.difference(session.startedAt) - session.totalPausedDuration;

    if (session.isPaused && session.pausedAt != null) {
      elapsed -= now.difference(session.pausedAt!);
    }

    final minutes = elapsed.inMinutes;
    final seconds = elapsed.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')} elapsed';
  }
}
