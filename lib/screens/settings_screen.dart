import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:workouts/models/health_export_summary.dart';
import 'package:workouts/models/health_permission_status.dart';
import 'package:workouts/providers/health_kit_provider.dart';
import 'package:workouts/providers/influences_provider.dart';
import 'package:workouts/providers/sync_provider.dart';
import 'package:workouts/providers/template_version_provider.dart';
import 'package:workouts/screens/influences_screen.dart';
import 'package:workouts/theme/app_theme.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permissionAsync = ref.watch(healthKitPermissionProvider);
    final exportAsync = ref.watch(healthExportControllerProvider);
    final versionAsync = ref.watch(templateVersionControllerProvider);
    final syncStatus = ref.watch(powerSyncStatusProvider);

    final influencesAsync = ref.watch(activeInfluencesProvider);

    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('Settings')),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            _TrainingInfluencesTile(influencesAsync: influencesAsync),
            const SizedBox(height: AppSpacing.lg),
            _SyncStatusTile(syncStatus: syncStatus),
            const SizedBox(height: AppSpacing.lg),
            _TemplateVersionTile(versionAsync: versionAsync, ref: ref),
            const SizedBox(height: AppSpacing.lg),
            _PermissionStatusTile(permissionAsync: permissionAsync, ref: ref),
            const SizedBox(height: AppSpacing.lg),
            _HealthDataActions(exportAsync: exportAsync, ref: ref),
          ],
        ),
      ),
    );
  }
}

class _TrainingInfluencesTile extends StatelessWidget {
  const _TrainingInfluencesTile({required this.influencesAsync});

  final AsyncValue<List<dynamic>> influencesAsync;

  @override
  Widget build(BuildContext context) {
    final activeCount = influencesAsync.value?.length ?? 0;
    final subtitle = activeCount == 0
        ? 'None selected'
        : '$activeCount influence${activeCount == 1 ? '' : 's'} active';

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        CupertinoPageRoute<void>(
          builder: (_) => const InfluencesScreen(),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.backgroundDepth2,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.borderDepth1),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.backgroundDepth3,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: const Icon(
                CupertinoIcons.person_2,
                color: AppColors.textColor2,
                size: 22,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Training Influences', style: AppTypography.subtitle),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    subtitle,
                    style: AppTypography.body.copyWith(
                      color: AppColors.textColor3,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              CupertinoIcons.chevron_right,
              color: AppColors.textColor3,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

class _SyncStatusTile extends StatelessWidget {
  const _SyncStatusTile({required this.syncStatus});

  final AsyncValue<SyncStatus> syncStatus;

  @override
  Widget build(BuildContext context) {
    final statusLabel = syncStatus.when(
      data: (status) => status.connected ? 'Connected' : 'Offline',
      loading: () => 'Connecting...',
      error: (_, __) => 'Error',
    );

    final isConnected = syncStatus.value?.connected ?? false;

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
          Text('PowerSync Status', style: AppTypography.subtitle),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isConnected ? AppColors.success : AppColors.warning,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                statusLabel,
                style: AppTypography.body.copyWith(color: AppColors.textColor3),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TemplateVersionTile extends StatelessWidget {
  const _TemplateVersionTile({required this.versionAsync, required this.ref});

  final AsyncValue<TemplateVersionStatus> versionAsync;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.backgroundDepth2,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.borderDepth1),
      ),
      child: versionAsync.when(
        data: (status) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Workout Templates', style: AppTypography.subtitle),
            const SizedBox(height: AppSpacing.xs),
            Text(
              status.installed == null
                  ? 'Not initialized (version ${status.current})'
                  : 'Version ${status.installed} installed (current: ${status.current})',
              style: AppTypography.body.copyWith(
                color: status.needsUpdate
                    ? AppColors.warning
                    : AppColors.textColor3,
              ),
            ),
            if (status.needsUpdate) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Templates need to be updated to access new features and fixes.',
                style: AppTypography.caption.copyWith(
                  color: AppColors.textColor4,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              CupertinoButton.filled(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.sm,
                ),
                onPressed: () => _confirmReseed(context),
                child: const Text(
                  'Update Templates',
                  style: TextStyle(
                    color: CupertinoColors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
        loading: () => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Workout Templates', style: AppTypography.subtitle),
            const SizedBox(height: AppSpacing.xs),
            const CupertinoActivityIndicator(),
          ],
        ),
        error: (error, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Workout Templates', style: AppTypography.subtitle),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Error: $error',
              style: AppTypography.body.copyWith(color: AppColors.error),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmReseed(BuildContext context) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (context) {
        return CupertinoActionSheet(
          title: const Text('Update Templates?'),
          message: const Text(
            'This will regenerate all workout templates with the latest version. Any active sessions will not be affected.',
          ),
          actions: [
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.of(context, rootNavigator: true).pop();
                ref.read(templateVersionControllerProvider.notifier).reseed();
              },
              child: const Text('Update Templates'),
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
                .read(healthKitPermissionProvider.notifier)
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
