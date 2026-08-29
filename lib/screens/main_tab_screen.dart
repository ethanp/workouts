import 'package:ethan_ui/ethan_ui.dart';
import 'package:ethan_utils/ethan_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workouts/models/session.dart';
import 'package:workouts/features/active_session/active_session_provider.dart';
import 'package:workouts/features/history/history_screen.dart';
import 'package:workouts/features/library/library_screen.dart';
import 'package:workouts/features/active_session/session_resume_screen.dart';
import 'package:workouts/features/settings/settings_screen.dart';
import 'package:workouts/features/today/today_screen.dart';
import 'package:workouts/theme/app_theme.dart';

class MainTab {
  const MainTab({
    required this.icon,
    required this.label,
    required this.screen,
  });

  final IconData icon;
  final String label;
  final Widget screen;
}

const _mainTabs = <MainTab>[
  MainTab(
    icon: Icons.history,
    label: 'History',
    screen: HistoryScreen(),
  ),
  MainTab(
    icon: Icons.play_circle_outline,
    label: 'Start Workout',
    screen: TodayScreen(),
  ),
  MainTab(
    icon: Icons.menu_book_outlined,
    label: 'Library',
    screen: LibraryScreen(),
  ),
  MainTab(
    icon: Icons.settings_outlined,
    label: 'Settings',
    screen: SettingsScreen(),
  ),
];

class MainTabScreen extends ConsumerStatefulWidget {
  const MainTabScreen();

  @override
  ConsumerState<MainTabScreen> createState() => _MainTabScreenState();
}

class _MainTabScreenState extends ConsumerState<MainTabScreen> {
  int _selectedTabIndex = 0;
  final _navigatorKeys = List<GlobalKey<NavigatorState>>.generate(
    _mainTabs.length,
    (_) => GlobalKey<NavigatorState>(),
  );

  @override
  Widget build(BuildContext context) {
    final activeSession = ref.watch(activeSessionProvider);
    final sessionUIVisible = ref.watch(sessionUIVisibilityProvider);

    if (sessionUIVisible && activeSession.value == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(sessionUIVisibilityProvider.notifier).hide();
      });
    }

    if (sessionUIVisible && activeSession.value != null) {
      return SessionResumeScreen(sessionId: activeSession.value!.id);
    }

    return EScaffoldShell(
      contentMaxWidth: double.infinity,
      bottomBar: ETabBar(
        selectedIndex: _selectedTabIndex,
        tabs: [
          for (final tab in _mainTabs) ETab(icon: tab.icon, label: tab.label),
        ],
        onSelected: (index) {
          if (index == _selectedTabIndex) {
            _navigatorKeys[index].currentState?.popUntil((route) => route.isFirst);
            return;
          }
          setState(() => _selectedTabIndex = index);
        },
      ),
      body: IndexedStack(
        index: _selectedTabIndex,
        children: [
          for (var tabIndex = 0; tabIndex < _mainTabs.length; tabIndex++)
            Navigator(
              key: _navigatorKeys[tabIndex],
              onGenerateRoute: (settings) => MaterialPageRoute<void>(
                settings: settings,
                builder: (_) => _ActiveSessionWrapper(
                  child: _mainTabs[tabIndex].screen,
                ),
              ),
            ),
        ],
      ),
    );
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
              session.isPaused ? Icons.pause_circle : Icons.play_circle,
              color: Colors.white,
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
        color: Colors.white,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget elapsedTime(Session session) {
    return Text(
      _getElapsedTime(session),
      style: const TextStyle(
        color: Colors.white,
        fontSize: 12,
        fontWeight: FontWeight.w400,
      ),
    );
  }

  Widget openButton(WidgetRef ref) {
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

  String _getElapsedTime(Session session) {
    final now = DateTime.now();
    var elapsed =
        now.difference(session.startedAt) - session.totalPausedDuration;

    if (session.isPaused && session.pausedAt != null) {
      elapsed -= now.difference(session.pausedAt!);
    }

    return '${elapsed.formattedClock} elapsed';
  }
}
