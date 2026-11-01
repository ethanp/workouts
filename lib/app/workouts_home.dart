import 'package:ethan_sync/ethan_sync.dart';
import 'package:ethan_ui/ethan_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workouts/features/active_session/active_session_banner.dart';
import 'package:workouts/features/active_session/active_session_provider.dart';
import 'package:workouts/features/active_session/session_resume_screen.dart';
import 'package:workouts/features/cardio/cardio_metrics_backfill.dart';
import 'package:workouts/features/history/history_screen.dart';
import 'package:workouts/features/library/library_screen.dart';
import 'package:workouts/features/settings/settings_screen.dart';

const _mainTabs = <EMainTab>[
  EMainTab(icon: Icons.history, label: 'History', screen: HistoryScreen()),
  EMainTab(
    icon: Icons.menu_book_outlined,
    label: 'Library',
    screen: LibraryScreen(),
  ),
  EMainTab(
    icon: Icons.settings_outlined,
    label: 'Settings',
    screen: SettingsScreen(),
  ),
];

/// The active session when its UI is showing, otherwise the main tabs with
/// the active-session banner above each. Providers that must start on launch
/// are kept alive here.
class const WorkoutsHome() extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(powerSyncDatabaseProvider);
    ref.watch(cardioMetricsBackfillProvider);

    final activeSession = ref.watch(activeSessionProvider);
    final bool sessionUIVisible = ref.watch(sessionUIVisibilityProvider);

    if (sessionUIVisible && activeSession.value == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(sessionUIVisibilityProvider.notifier).hide();
      });
    }

    if (sessionUIVisible && activeSession.value != null) {
      return SessionResumeScreen(sessionId: activeSession.value!.id);
    }

    return EMainTabScreen(
      tabs: _mainTabs,
      wrapTabScreen: (screen) => ActiveSessionBanner(child: screen),
    );
  }
}
