import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show DefaultMaterialLocalizations;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workouts/features/cardio/cardio_provider.dart';
import 'package:workouts/screens/main_tab_screen.dart';
import 'package:workouts/services/powersync/powersync_database_provider.dart';
import 'package:workouts/theme/app_theme.dart';
import 'package:workouts/widgets/error_banner.dart';

class WorkoutsApp extends ConsumerWidget {
  const WorkoutsApp();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(powerSyncDatabaseProvider);
    ref.watch(cardioMetricsBackfillProvider);

    return CupertinoApp(
      title: 'Workouts',
      theme: buildAppTheme(),
      debugShowCheckedModeBanner: false,
      // ReorderableListView (used in BlockView) is a Material widget and
      // requires MaterialLocalizations even inside an otherwise Cupertino app.
      localizationsDelegates: const [
        DefaultMaterialLocalizations.delegate,
        DefaultCupertinoLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
      ],
      home: const ErrorBanner(child: MainTabScreen()),
    );
  }
}
