import 'package:ethan_ui/ethan_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workouts/app_identity.dart';
import 'package:workouts/features/cardio/cardio_metrics_backfill.dart';
import 'package:workouts/screens/main_tab_screen.dart';
import 'package:ethan_sync/ethan_sync.dart';
import 'package:workouts/widgets/error_banner.dart';

class const WorkoutsApp() extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(powerSyncDatabaseProvider);
    ref.watch(cardioMetricsBackfillProvider);

    return MaterialApp(
      title: AppIdentity.displayName,
      theme: ETheme.material3Dark,
      debugShowCheckedModeBanner: false,
      home: const ErrorBanner(child: MainTabScreen()),
    );
  }
}
