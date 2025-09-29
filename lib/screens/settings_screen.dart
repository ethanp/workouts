import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:workouts/models/health_export_summary.dart';
import 'package:workouts/models/health_permission_status.dart';
import 'package:workouts/providers/health_kit_provider.dart';
import 'package:workouts/theme/app_theme.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permissionAsync = ref.watch(healthKitPermissionNotifierProvider);
    final exportAsync = ref.watch(healthExportControllerProvider);

    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('Settings')),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            _PermissionStatusTile(permissionAsync: permissionAsync, ref: ref),
            const SizedBox(height: AppSpacing.lg),
            _HealthDataActions(exportAsync: exportAsync, ref: ref),
          ],
        ),
      ),
    );
  }
}

class _PermissionStatusTile extends StatelessWidget {
  const _PermissionStatusTile({
    required this.permissionAsync,
    required this.ref,
  });

  final AsyncValue<HealthPermissionStatus> permissionAsync;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final statusLabel = permissionAsync.when(
      data: (status) => switch (status) {
        HealthPermissionStatus.authorized => 'Authorized',
        HealthPermissionStatus.limited => 'Limited',
        HealthPermissionStatus.denied => 'Denied',
        HealthPermissionStatus.unavailable => 'Unavailable on simulator',
        HealthPermissionStatus.unknown => 'Unknown',
      },
      loading: () => 'Checking…',
      error: (error, _) => 'Error: $error',
    );

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.backgroundDepth2,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.borderDepth1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Health Permissions', style: AppTypography.subtitle),
          const SizedBox(height: AppSpacing.xs),
          Text(
            statusLabel,
            style: AppTypography.body.copyWith(color: AppColors.textColor3),
          ),
          const SizedBox(height: AppSpacing.sm),
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => ref
                .read(healthKitPermissionNotifierProvider.notifier)
                .requestAuthorization(),
            child: const Text('Manage in Health app'),
          ),
        ],
      ),
    );
  }
}

class _HealthDataActions extends StatelessWidget {
  const _HealthDataActions({required this.exportAsync, required this.ref});

  final AsyncValue<HealthExportSummary> exportAsync;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final summary =
        exportAsync.value ??
        const HealthExportSummary(exportedWorkoutUUIDs: []);
    final isLoading = exportAsync.isLoading;
    final errorMessage = exportAsync.whenOrNull(error: (error, _) => '$error');
    final buttonLabel = switch (summary.remainingCount) {
      0 => 'Remove exported workouts from Health',
      final count => 'Remove $count exported workout${count == 1 ? '' : 's'}',
    };

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.backgroundDepth2,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.borderDepth1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Health Data', style: AppTypography.subtitle),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Remove workouts pushed to Apple Health if you want to clear them before the next sync.',
            style: AppTypography.body.copyWith(color: AppColors.textColor3),
          ),
          const SizedBox(height: AppSpacing.md),
          CupertinoButton.filled(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
            onPressed: isLoading
                ? null
                : () => _confirmDeletion(context, ref, summary.remainingCount),
            child: Text(
              buttonLabel,
              style: const TextStyle(
                color: CupertinoColors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (errorMessage != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              errorMessage,
              style: AppTypography.caption.copyWith(color: AppColors.error),
            ),
          ],
          if (summary.lastDeletionAt != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Last removal ${DateFormat('MMM d • HH:mm').format(summary.lastDeletionAt!.toLocal())}',
              style: AppTypography.caption.copyWith(
                color: AppColors.textColor4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _confirmDeletion(BuildContext context, WidgetRef ref, int count) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (context) {
        return CupertinoActionSheet(
          title: const Text('Remove Health workouts?'),
          message: Text(
            count == 0
                ? 'This removes any workouts we previously exported to Apple Health.'
                : 'This removes $count exported workout${count == 1 ? '' : 's'} from Apple Health using the stored HealthKit identifiers.',
          ),
          actions: [
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.of(context, rootNavigator: true).pop();
                ref
                    .read(healthExportControllerProvider.notifier)
                    .deleteAllExports();
              },
              isDestructiveAction: true,
              child: const Text('Remove from Health'),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
            child: const Text('Cancel'),
          ),
        );
      },
    );
  }
}
