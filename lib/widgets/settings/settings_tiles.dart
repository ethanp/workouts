import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workouts/models/health_permission_status.dart';
import 'package:workouts/providers/activity_provider.dart';
import 'package:workouts/providers/cardio_provider.dart';
import 'package:workouts/providers/health_kit_provider.dart';
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
    final recomputeProgress = ref.watch(metricsRecomputeProgressProvider);
    final displayHR = _dragValue?.round() ?? maxHR;
    final zone2Lower = (displayHR * 0.60).floor();

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
                      '$displayHR bpm  ·  >= Zone 2: $zone2Lower+ bpm',
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
                'Recomputing zones: ${recomputeProgress.$1}/${recomputeProgress.$2}',
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

class RestingHeartRateTile extends ConsumerStatefulWidget {
  const RestingHeartRateTile({super.key});

  @override
  ConsumerState<RestingHeartRateTile> createState() =>
      _RestingHeartRateTileState();
}

class _RestingHeartRateTileState extends ConsumerState<RestingHeartRateTile> {
  double? _dragValue;
  bool _syncing = false;

  Future<void> _syncFromHealthKit() async {
    setState(() => _syncing = true);
    try {
      final bridge = ref.read(healthKitBridgeProvider);
      final bpm = await bridge.fetchRestingHeartRate();
      if (bpm != null && mounted) {
        ref.read(restingHeartRateProvider.notifier).setRestingHeartRate(bpm);
      }
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final restingHR = ref.watch(restingHeartRateProvider);
    final displayHR = _dragValue?.round() ?? restingHR;

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
                  CupertinoIcons.heart,
                  color: Color(0xFF64D2FF),
                  size: 22,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Resting Heart Rate', style: AppTypography.subtitle),
                    Text(
                      '$displayHR bpm',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textColor3,
                      ),
                    ),
                  ],
                ),
              ),
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: _syncing ? null : _syncFromHealthKit,
                child: _syncing
                    ? const CupertinoActivityIndicator()
                    : const Icon(CupertinoIcons.arrow_2_circlepath,
                        size: 20, color: AppColors.accentPrimary),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          CupertinoSlider(
            value: _dragValue ?? restingHR.toDouble(),
            min: 30,
            max: 100,
            divisions: 70,
            onChanged: (value) => setState(() => _dragValue = value),
            onChangeEnd: (value) {
              setState(() => _dragValue = null);
              ref
                  .read(restingHeartRateProvider.notifier)
                  .setRestingHeartRate(value.round());
            },
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
        HealthPermissionStatus.unavailable => 'Unavailable on this platform',
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

class HealthCardioImportTile extends ConsumerWidget {
  const HealthCardioImportTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final importAsync = ref.watch(cardioImportControllerProvider);
    final importProgress =
        importAsync.value ?? const CardioImportProgress.idle();
    final isImporting = importProgress.inProgress;
    final importErrorMessage = importAsync.hasError
        ? '${importAsync.error}'
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
          Text('Cardio Import', style: AppTypography.subtitle),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Import recent Apple Health cardio workouts into your local database.',
            style: AppTypography.body.copyWith(color: AppColors.textColor3),
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: CupertinoButton.filled(
              onPressed: isImporting
                  ? null
                  : () => ref
                        .read(cardioImportControllerProvider.notifier)
                        .importRecentWorkouts(),
              child: isImporting
                  ? const CupertinoActivityIndicator(
                      color: CupertinoColors.white,
                    )
                  : const Text(
                      'Import Workouts',
                      style: TextStyle(
                        color: CupertinoColors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
          if (isImporting) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Importing ${importProgress.processedWorkouts}/${importProgress.totalWorkouts}',
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
                  widthFactor: importProgress.progressFraction.clamp(
                    0.0,
                    1.0,
                  ),
                  child: Container(color: AppColors.accentPrimary),
                ),
              ),
            ),
          ] else if (importProgress.status.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              importProgress.status,
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

class MetricsBackfillTile extends ConsumerWidget {
  const MetricsBackfillTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(metricsBackfillControllerProvider);

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
          Text('Metrics Backfill', style: AppTypography.subtitle),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Compute missing HR zones, best effort paces, and session metrics for all workouts.',
            style: AppTypography.body.copyWith(color: AppColors.textColor3),
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: CupertinoButton.filled(
              onPressed: status.inProgress
                  ? null
                  : () => ref
                      .read(metricsBackfillControllerProvider.notifier)
                      .runBackfill(),
              child: status.inProgress
                  ? const CupertinoActivityIndicator(
                      color: CupertinoColors.white,
                    )
                  : const Text(
                      'Run Backfill',
                      style: TextStyle(
                        color: CupertinoColors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
          if (status.label.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              status.label,
              style: AppTypography.caption.copyWith(
                color: status.inProgress
                    ? AppColors.textColor3
                    : AppColors.success,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
