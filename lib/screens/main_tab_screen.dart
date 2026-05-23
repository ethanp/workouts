import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workouts/models/session.dart';
import 'package:workouts/features/active_session/active_session_provider.dart';
import 'package:workouts/features/history/history_screen.dart';
import 'package:workouts/features/library/library_screen.dart';
import 'package:workouts/features/active_session/session_resume_screen.dart';
import 'package:workouts/features/settings/settings_screen.dart';
import 'package:workouts/features/today/today_screen.dart';
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

    if (sessionUIVisible && activeSession.value != null) {
      return SessionResumeScreen(sessionId: activeSession.value!.id);
    }

    return CupertinoTabScaffold(
      tabBar: _tabBar(),
      tabBuilder: (_, selectedIndex) => CupertinoTabView(
        builder: (_) => _tabContent(selectedIndex),
      ),
    );
  }

  CupertinoTabBar _tabBar() => CupertinoTabBar(
    items: const [
      BottomNavigationBarItem(
        icon: Icon(CupertinoIcons.house_alt),
        label: 'Today',
      ),
      BottomNavigationBarItem(
        icon: Icon(CupertinoIcons.book),
        label: 'Library',
      ),
      BottomNavigationBarItem(
        icon: Icon(CupertinoIcons.clock),
        label: 'History',
      ),
      BottomNavigationBarItem(
        icon: Icon(CupertinoIcons.gear),
        label: 'Settings',
      ),
    ],
    currentIndex: index,
    onTap: (value) => setState(() => index = value),
  );

  Widget _tabContent(int selectedIndex) {
    final screen = switch (selectedIndex) {
      0 => const TodayScreen(),
      1 => const LibraryScreen(),
      2 => const HistoryScreen(),
      _ => const SettingsScreen(),
    };
    return _ActiveSessionWrapper(child: screen);
  }
}

class _ActiveSessionWrapper extends ConsumerWidget {
  const _ActiveSessionWrapper({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(activeSessionProvider).value;
    final sessionUIVisible = ref.watch(sessionUIVisibilityProvider);
    final showBanner = session != null && !sessionUIVisible;

    // Always render the same Column structure so the child's state (e.g.
    // HistoryScreen's selected tab) is never discarded when the banner
    // appears or disappears.
    return Column(
      children: [
        if (showBanner)
          _activeSessionBanner(ref, session)
        else
          const SizedBox.shrink(),
        Expanded(child: child),
      ],
    );
  }

  Widget _activeSessionBanner(WidgetRef ref, Session session) {
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
                children: [pausedOrActive(session), elapsedTime(session)],
              ),
            ),
            openButton(ref),
          ],
        ),
      ),
    );
  }

  Widget pausedOrActive(Session session) {
    return Text(
      session.isPaused ? 'Workout Paused' : 'Workout Active',
      style: const TextStyle(
        color: CupertinoColors.white,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget elapsedTime(Session session) {
    return Text(
      _getElapsedTime(session),
      style: const TextStyle(
        color: CupertinoColors.white,
        fontSize: 12,
        fontWeight: FontWeight.w400,
      ),
    );
  }

  Widget openButton(WidgetRef ref) {
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      onPressed: () => ref.read(sessionUIVisibilityProvider.notifier).show(),
      child: const Text(
        'Open',
        style: TextStyle(
          color: CupertinoColors.white,
          fontSize: 14,
          fontWeight: FontWeight.w600,
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
