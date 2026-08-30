import 'package:ethan_ui/ethan_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workouts/app_identity.dart';
import 'package:workouts/features/cardio/cardio_provider.dart';
import 'package:workouts/screens/main_tab_screen.dart';
import 'package:workouts/services/powersync/powersync_database_provider.dart';
import 'package:workouts/widgets/error_banner.dart';

class const WorkoutsApp() extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(powerSyncDatabaseProvider);
    ref.watch(cardioMetricsBackfillProvider);

    return MaterialApp(
      title: AppIdentity.displayName,
      theme: ETheme.build(),
      debugShowCheckedModeBanner: false,
      home: const ErrorBanner(child: MainTabScreen()),
    );
  }
}
