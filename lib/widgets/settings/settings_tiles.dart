import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workouts/models/health_permission_status.dart';
import 'package:workouts/providers/health_kit_provider.dart';
import 'package:workouts/providers/runs_provider.dart';
import 'package:workouts/providers/sync_provider.dart';
import 'package:workouts/providers/template_version_provider.dart';
import 'package:workouts/providers/unit_system_provider.dart';
import 'package:workouts/screens/influences_screen.dart';
import 'package:workouts/theme/app_theme.dart';

class UnitSystemTile extends StatelessWidget {
  const UnitSystemTile({super.key, required this.unitSystem, required this.ref});

  final UnitSystem unitSystem;
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
              CupertinoIcons.arrow_2_squarepath,
              color: AppColors.textColor2,
              size: 22,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Units', style: AppTypography.subtitle),
                Text(
                  unitSystem == UnitSystem.imperial
                      ? 'Imperial (mi, mph)'
                      : 'Metric (km, km/h)',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textColor3,
                  ),
                ),
              ],
            ),
          ),
          CupertinoSlidingSegmentedControl<UnitSystem>(
            groupValue: unitSystem,
            children: const {
              UnitSystem.imperial: Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                child: Text('mi'),
              ),
              UnitSystem.metric: Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                child: Text('km'),
              ),
            },
            onValueChanged: (value) {
              if (value != null) {
                ref.read(unitSystemProvider.notifier).setUnitSystem(value);
              }
            },
          ),
        ],
      ),
    );
  }
}

class MaxHeartRateTile extends ConsumerStatefulWidget {
  const MaxHeartRateTile({super.key});

  @override
  ConsumerState<MaxHeartRateTile> createState() => _MaxHeartRateTileState();
}

class _MaxHeartRateTileState extends ConsumerState<MaxHeartRateTile> {
  double? _dragValue;

  @override
  Widget build(BuildContext context) {
    final maxHR = ref.watch(maxHeartRateProvider);
    final recomputeProgress = ref.watch(zone2RecomputeProgressProvider);
    final displayHR = _dragValue?.round() ?? maxHR;
    final lowerBound = (displayHR * 0.60).floor();
    final upperBound = (displayHR * 0.70).ceil();

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
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.backgroundDepth3,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: const Icon(
                  CupertinoIcons.heart_fill,
                  color: AppColors.error,
                  size: 22,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Max Heart Rate', style: AppTypography.subtitle),
                    Text(
                      '$displayHR bpm  ·  Zone 2: $lowerBound–$upperBound',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textColor3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          CupertinoSlider(
            value: _dragValue ?? maxHR.toDouble(),
            min: 140,
            max: 220,
            divisions: 80,
            onChanged: (value) => setState(() => _dragValue = value),
            onChangeEnd: (value) {
              setState(() => _dragValue = null);
              ref
                  .read(maxHeartRateProvider.notifier)
                  .setMaxHeartRate(value.round());
            },
          ),
          if (recomputeProgress != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(
                'Recomputing Zone 2: ${recomputeProgress.$1}/${recomputeProgress.$2}',
                style: AppTypography.caption.copyWith(
                  color: AppColors.textColor4,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class TrainingInfluencesTile extends StatelessWidget {
  const TrainingInfluencesTile({
    super.key,
    required this.influencesAsync,
  });

  final AsyncValue<List<dynamic>> influencesAsync;

  @override
  Widget build(BuildContext context) {
    final activeCount = influencesAsync.value?.length ?? 0;
    final subtitle = activeCount == 0
        ? 'None selected'
        : '$activeCount influence${activeCount == 1 ? '' : 's'} active';

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        CupertinoPageRoute<void>(builder: (_) => const InfluencesScreen()),
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

class SyncStatusTile extends StatelessWidget {
  const SyncStatusTile({super.key, required this.syncStatus});

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

class TemplateVersionTile extends StatelessWidget {
  const TemplateVersionTile({
    super.key,
    required this.versionAsync,
    required this.ref,
  });

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

class PermissionStatusTile extends StatelessWidget {
  const PermissionStatusTile({
    super.key,
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

class HealthRunImportTile extends ConsumerWidget {
  const HealthRunImportTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final runImportAsync = ref.watch(runImportControllerProvider);
    final runImportProgress =
        runImportAsync.value ?? const RunImportProgress.idle();
    final isImportingRuns = runImportProgress.inProgress;
    final importErrorMessage = runImportAsync.hasError
        ? '${runImportAsync.error}'
        : null;
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
          Text('Run Import', style: AppTypography.subtitle),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Import recent Apple Health runs into your local run database.',
            style: AppTypography.body.copyWith(color: AppColors.textColor3),
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: CupertinoButton.filled(
              onPressed: isImportingRuns
                  ? null
                  : () => ref
                        .read(runImportControllerProvider.notifier)
                        .importRecentRuns(),
              child: isImportingRuns
                  ? const CupertinoActivityIndicator(
                      color: CupertinoColors.white,
                    )
                  : const Text(
                      'Import Runs To Local DB',
                      style: TextStyle(
                        color: CupertinoColors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
          if (isImportingRuns) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Importing runs ${runImportProgress.processedRuns}/${runImportProgress.totalRuns}',
              style: AppTypography.caption.copyWith(
                color: AppColors.textColor3,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: Container(
                height: 6,
                color: AppColors.backgroundDepth3,
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: runImportProgress.progressFraction.clamp(
                    0.0,
                    1.0,
                  ),
                  child: Container(color: AppColors.accentPrimary),
                ),
              ),
            ),
          ] else if (runImportProgress.status.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              runImportProgress.status,
              style: AppTypography.caption.copyWith(color: AppColors.success),
            ),
          ],
          if (importErrorMessage != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              importErrorMessage,
              style: AppTypography.caption.copyWith(color: AppColors.error),
            ),
          ],
        ],
      ),
    );
  }
}
