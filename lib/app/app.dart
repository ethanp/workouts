import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workouts/screens/main_tab_screen.dart';
import 'package:workouts/services/powersync/powersync_database_provider.dart';
import 'package:workouts/theme/app_theme.dart';
import 'package:workouts/widgets/error_banner.dart';

class WorkoutsApp extends ConsumerWidget {
  const WorkoutsApp();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(powerSyncDatabaseProvider);

    return CupertinoApp(
      title: 'Workouts',
      theme: buildAppTheme(),
      debugShowCheckedModeBanner: false,
      home: const ErrorBanner(child: MainTabScreen()),
    );
  }
}
