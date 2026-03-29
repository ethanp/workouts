import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workouts/models/health_permission_status.dart';
import 'package:workouts/providers/activity_provider.dart';
import 'package:workouts/providers/cardio_provider.dart';
import 'package:workouts/providers/health_kit_provider.dart';
import 'package:workouts/providers/sync_provider.dart';
import 'package:workouts/providers/template_version_provider.dart';
import 'package:workouts/providers/unit_system_provider.dart';
import 'package:workouts/theme/app_theme.dart';
import 'package:workouts/utils/training_load_calculator.dart';

class UnitSystemTile extends StatelessWidget {
  const UnitSystemTile({
    super.key,
    required this.unitSystem,
    required this.ref,
  });

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
          _iconBox(),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: _labelColumn()),
          _unitSegmentedControl(),
        ],
      ),
    );
  }

  Widget _iconBox() => Container(
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
  );

  Widget _labelColumn() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Units', style: AppTypography.subtitle),
      Text(
        unitSystem == UnitSystem.imperial
            ? 'Imperial (mi, mph)'
            : 'Metric (km, km/h)',
        style: AppTypography.caption.copyWith(color: AppColors.textColor3),
      ),
    ],
  );

  Widget _unitSegmentedControl() => CupertinoSlidingSegmentedControl<UnitSystem>(
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
  );
}

class HrZonesTile extends StatelessWidget {
  const HrZonesTile({super.key});

  static const _zoneLabels = ['Z1', 'Z2', 'Z3', 'Z4', 'Z5'];
  static const _zoneNames = ['Recovery', 'Aerobic', 'Tempo', 'Threshold', 'Max'];
  static const _zoneColors = [
    Color(0xFF5BA4CF),
    Color(0xFF3FB37F),
    Color(0xFFF0C849),
    Color(0xFFF08C3B),
    Color(0xFFE15A64),
  ];

  @override
  Widget build(BuildContext context) {
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
          _header(),
          const SizedBox(height: AppSpacing.md),
          _zoneTable(),
        ],
      ),
    );
  }

  Widget _header() => Row(
    children: [
      Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.backgroundDepth3,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: const Icon(CupertinoIcons.heart_fill, color: AppColors.error, size: 22),
      ),
      const SizedBox(width: AppSpacing.md),
      Text('Heart Rate Zones', style: AppTypography.subtitle),
    ],
  );

  Widget _zoneTable() => Column(
    children: List.generate(5, (zoneIndex) {
      final lower = TrainingLoadCalculator.zoneBoundaries[zoneIndex];
      final upper = TrainingLoadCalculator.zoneUpperBounds[zoneIndex];
      return _zoneRow(zoneIndex, lower, upper);
    }),
  );

  Widget _zoneRow(int zoneIndex, int lower, int upper) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: _zoneColors[zoneIndex],
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        SizedBox(
          width: 20,
          child: Text(
            _zoneLabels[zoneIndex],
            style: AppTypography.caption.copyWith(
              color: _zoneColors[zoneIndex],
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          _zoneNames[zoneIndex],
          style: AppTypography.caption.copyWith(color: AppColors.textColor4),
        ),
        const Spacer(),
        Text(
          '$lower – $upper bpm',
          style: AppTypography.caption.copyWith(color: AppColors.textColor3),
        ),
      ],
    ),
  );
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
    final restingHeartRate = ref.watch(restingHeartRateProvider);
    final displayedHeartRate = _dragValue?.round() ?? restingHeartRate;

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
          _header(displayedHeartRate),
          const SizedBox(height: AppSpacing.sm),
          _restingHeartRateSlider(restingHeartRate),
        ],
      ),
    );
  }

  Widget _header(int displayedHeartRate) => Row(
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
              '$displayedHeartRate bpm',
              style: AppTypography.caption.copyWith(color: AppColors.textColor3),
            ),
          ],
        ),
      ),
      CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: _syncing ? null : _syncFromHealthKit,
        child: _syncing
            ? const CupertinoActivityIndicator()
            : const Icon(
                CupertinoIcons.arrow_2_circlepath,
                size: 20,
                color: AppColors.accentPrimary,
              ),
      ),
    ],
  );

  Widget _restingHeartRateSlider(int restingHeartRate) => CupertinoSlider(
    value: _dragValue ?? restingHeartRate.toDouble(),
    min: 30,
    max: 100,
    divisions: 70,
    onChanged: (value) => setState(() => _dragValue = value),
    onChangeEnd: (value) {
      setState(() => _dragValue = null);
      ref.read(restingHeartRateProvider.notifier).setRestingHeartRate(value.round());
    },
  );
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
        data: (status) => _dataContent(context, status),
        loading: _loadingContent,
        error: (error, _) => _errorContent(error),
      ),
    );
  }

  Widget _dataContent(BuildContext context, TemplateVersionStatus status) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Workout Templates', style: AppTypography.subtitle),
      const SizedBox(height: AppSpacing.xs),
      Text(
        status.installed == null
            ? 'Not initialized (version ${status.currentTemplateVersion})'
            : 'Version ${status.installed} installed (current: ${status.currentTemplateVersion})',
        style: AppTypography.body.copyWith(
          color: status.needsUpdate ? AppColors.warning : AppColors.textColor3,
        ),
      ),
      if (status.needsUpdate) ...[
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Templates need to be updated to access new features and fixes.',
          style: AppTypography.caption.copyWith(color: AppColors.textColor4),
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
      const SizedBox(height: AppSpacing.sm),
      CupertinoButton(
        padding: EdgeInsets.zero,
        minimumSize: const Size(0, 0),
        onPressed: () => _confirmReseed(context),
        child: Text(
          'Reset to default templates',
          style: AppTypography.caption.copyWith(color: AppColors.accentPrimary),
        ),
      ),
    ],
  );

  Widget _loadingContent() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Workout Templates', style: AppTypography.subtitle),
      const SizedBox(height: AppSpacing.xs),
      const CupertinoActivityIndicator(),
    ],
  );

  Widget _errorContent(Object error) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Workout Templates', style: AppTypography.subtitle),
      const SizedBox(height: AppSpacing.xs),
      Text(
        'Error: $error',
        style: AppTypography.body.copyWith(color: AppColors.error),
      ),
    ],
  );

  void _confirmReseed(BuildContext context) {
    final versionNotifier =
        ref.read(templateVersionControllerProvider.notifier);
    showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetCtx) {
        return CupertinoActionSheet(
          title: const Text('Update Templates?'),
          message: const Text(
            'This will regenerate all workout templates with the latest version. Any active sessions will not be affected.',
          ),
          actions: [
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.of(sheetCtx, rootNavigator: true).pop();
                versionNotifier.reseed();
              },
              child: const Text('Update Templates'),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () =>
                Navigator.of(sheetCtx, rootNavigator: true).pop(),
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
          if (_permissionNeedsFirstRequest) ...[
            const SizedBox(height: AppSpacing.sm),
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => ref
                  .read(healthKitPermissionProvider.notifier)
                  .requestAuthorization(),
              child: const Text('Allow Health Access'),
            ),
          ],
        ],
      ),
    );
  }

  bool get _permissionNeedsFirstRequest =>
      permissionAsync.value == null ||
      permissionAsync.value == HealthPermissionStatus.unknown;
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
          _importButton(isImporting, ref),
          if (isImporting) ...[
            const SizedBox(height: AppSpacing.xs),
            _importProgressSection(importProgress),
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

  Widget _importButton(bool isImporting, WidgetRef ref) => SizedBox(
    width: double.infinity,
    child: CupertinoButton.filled(
      onPressed: isImporting
          ? null
          : () => ref
                .read(cardioImportControllerProvider.notifier)
                .importRecentWorkouts(),
      child: isImporting
          ? const CupertinoActivityIndicator(color: CupertinoColors.white)
          : const Text(
              'Import Workouts',
              style: TextStyle(
                color: CupertinoColors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
    ),
  );

  Widget _importProgressSection(CardioImportProgress importProgress) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Importing ${importProgress.processedWorkouts}/${importProgress.totalWorkouts}',
        style: AppTypography.caption.copyWith(color: AppColors.textColor3),
      ),
      const SizedBox(height: AppSpacing.xs),
      ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Container(
          height: 6,
          color: AppColors.backgroundDepth3,
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: importProgress.progressFraction.clamp(0.0, 1.0),
            child: Container(color: AppColors.accentPrimary),
          ),
        ),
      ),
    ],
  );
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
          _backfillButton(status, ref),
          if (status.label.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            _statusLabel(status),
          ],
        ],
      ),
    );
  }

  Widget _backfillButton(MetricsBackfillStatus status, WidgetRef ref) => SizedBox(
    width: double.infinity,
    child: CupertinoButton.filled(
      onPressed: status.inProgress
          ? null
          : () => ref
                .read(metricsBackfillControllerProvider.notifier)
                .runBackfill(),
      child: status.inProgress
          ? const CupertinoActivityIndicator(color: CupertinoColors.white)
          : const Text(
              'Run Backfill',
              style: TextStyle(
                color: CupertinoColors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
    ),
  );

  Widget _statusLabel(MetricsBackfillStatus status) => Text(
    status.label,
    style: AppTypography.caption.copyWith(
      color: status.inProgress ? AppColors.textColor3 : AppColors.success,
    ),
  );
}
