import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workouts/screens/main_tab_screen.dart';
import 'package:workouts/services/powersync/powersync_database_provider.dart';
import 'package:workouts/theme/app_theme.dart';

class WorkoutsApp extends ConsumerWidget {
  const WorkoutsApp();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final initializedSynchronizer = ref.watch(powerSyncDatabaseProvider);

    return CupertinoApp(
      title: 'Workouts',
      theme: buildAppTheme(),
      debugShowCheckedModeBanner: false,
      home: initializedSynchronizer.when(
        data: (_) => const MainTabScreen(),
        error: (error, stack) => CupertinoPageScaffold(
          navigationBar: const CupertinoNavigationBar(middle: Text('Error')),
          child: Center(child: Text('$error')),
        ),
        loading: () => const CupertinoPageScaffold(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              spacing: 16,
              children: [
                CupertinoActivityIndicator(),
                Text('Syncing your workouts…'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
