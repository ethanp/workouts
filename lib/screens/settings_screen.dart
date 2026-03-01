import 'package:flutter/cupertino.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:workouts/models/health_export_summary.dart';
import 'package:workouts/models/health_permission_status.dart';
import 'package:workouts/providers/health_kit_provider.dart';
import 'package:workouts/providers/influences_provider.dart';
import 'package:workouts/providers/runs_provider.dart';
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
            const _HealthRunImportValidationTile(),
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

class _HealthRunImportValidationTile extends ConsumerStatefulWidget {
  const _HealthRunImportValidationTile();

  @override
  ConsumerState<_HealthRunImportValidationTile> createState() =>
      _HealthRunImportValidationTileState();
}

class _HealthRunImportValidationTileState
    extends ConsumerState<_HealthRunImportValidationTile> {
  bool _isLoadingPreview = false;
  bool _isLoadingValidation = false;
  List<Map<String, dynamic>> _previewRuns = const [];
  Map<String, dynamic> _validationSummary = const {};
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    final runImportAsync = ref.watch(runImportControllerProvider);
    final runImportProgress =
        runImportAsync.value ?? const RunImportProgress.idle();
    final isImportingRuns = runImportProgress.inProgress;
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
          Text('Run Import Validation', style: AppTypography.subtitle),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Fetch recent Apple Health runs and verify which fields are populated before finalizing schema.',
            style: AppTypography.body.copyWith(color: AppColors.textColor3),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: CupertinoButton.filled(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  onPressed: _isLoadingPreview || _isLoadingValidation
                      ? null
                      : _loadPreviewRuns,
                  child: _isLoadingPreview
                      ? const CupertinoActivityIndicator(
                          color: CupertinoColors.white,
                        )
                      : const Text(
                          'Preview Runs',
                          style: TextStyle(
                            color: CupertinoColors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: CupertinoButton(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  color: AppColors.backgroundDepth3,
                  onPressed: _isLoadingPreview || _isLoadingValidation
                      ? null
                      : _validateFields,
                  child: _isLoadingValidation
                      ? const CupertinoActivityIndicator()
                      : Text(
                          'Validate Fields',
                          style: AppTypography.body.copyWith(
                            color: AppColors.textColor1,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
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
                  widthFactor: runImportProgress.progressFraction.clamp(0.0, 1.0),
                  child: Container(color: AppColors.accentPrimary),
                ),
              ),
            ),
          ] else if (runImportProgress.processedRuns > 0) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Imported ${runImportProgress.processedRuns} runs.',
              style: AppTypography.caption.copyWith(color: AppColors.success),
            ),
          ],
          if (_errorMessage != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              _errorMessage!,
              style: AppTypography.caption.copyWith(color: AppColors.error),
            ),
          ],
          if (_previewRuns.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              'Preview (${_previewRuns.length} runs)',
              style: AppTypography.caption.copyWith(
                color: AppColors.textColor4,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            ..._previewRuns.take(3).map(_buildPreviewRow),
            ..._buildRouteMapPreview(),
          ],
          if (_validationSummary.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            _buildCoverageSummary(_validationSummary),
          ],
        ],
      ),
    );
  }

  Widget _buildPreviewRow(Map<String, dynamic> runMap) {
    final distanceMeters = (runMap['distanceMeters'] as num?)?.toDouble();
    final durationSeconds = (runMap['durationSeconds'] as num?)?.toInt();
    final avgPaceSecondsPerKilometer =
        distanceMeters != null && durationSeconds != null && distanceMeters > 0
        ? (durationSeconds / (distanceMeters / 1000))
        : null;

    final distanceKmText = distanceMeters == null
        ? '-'
        : (distanceMeters / 1000).toStringAsFixed(2);
    final paceText = avgPaceSecondsPerKilometer == null
        ? '--:--/km'
        : _formatPace(avgPaceSecondsPerKilometer);
    final startDate = runMap['startDate'] as String? ?? 'unknown date';
    final routeAvailable = runMap['routeAvailable'] == true;
    final heartRateSampleCount = runMap['heartRateSampleCount'] as int? ?? 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Text(
        '$startDate  |  $distanceKmText km  |  $paceText  |  HR samples: $heartRateSampleCount  |  route: ${routeAvailable ? "yes" : "no"}',
        style: AppTypography.caption.copyWith(color: AppColors.textColor3),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  List<Widget> _buildRouteMapPreview() {
    final firstRunWithRoutePoints = _previewRuns.firstWhere((runPayload) {
      final routePointsRaw = runPayload['routePoints'];
      if (routePointsRaw is! List) {
        return false;
      }
      return routePointsRaw.isNotEmpty;
    }, orElse: () => const {});
    if (firstRunWithRoutePoints.isEmpty) {
      return [
        const SizedBox(height: AppSpacing.sm),
        Text(
          'No route points available in this preview set.',
          style: AppTypography.caption.copyWith(color: AppColors.textColor4),
        ),
      ];
    }

    final routeLatLngPoints = _extractRouteLatLngPoints(
      firstRunWithRoutePoints,
    );
    if (routeLatLngPoints.length < 2) {
      return [
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Route exists but has insufficient points for polyline rendering.',
          style: AppTypography.caption.copyWith(color: AppColors.textColor4),
        ),
      ];
    }

    final routeBounds = LatLngBounds.fromPoints(routeLatLngPoints);
    return [
      const SizedBox(height: AppSpacing.md),
      Text(
        'Route preview',
        style: AppTypography.caption.copyWith(
          color: AppColors.textColor4,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: AppSpacing.xs),
      ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: SizedBox(
          height: 220,
          child: FlutterMap(
            options: MapOptions(
              initialCameraFit: CameraFit.bounds(
                bounds: routeBounds,
                padding: const EdgeInsets.all(24),
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.workouts.app',
              ),
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: routeLatLngPoints,
                    strokeWidth: 4,
                    color: AppColors.accentPrimary,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: AppSpacing.xs),
      Text(
        'OpenStreetMap preview from imported Health route points.',
        style: AppTypography.caption.copyWith(color: AppColors.textColor4),
      ),
    ];
  }

  List<LatLng> _extractRouteLatLngPoints(Map<String, dynamic> runPayload) {
    final routePointsRaw = runPayload['routePoints'];
    if (routePointsRaw is! List) {
      return const [];
    }
    final latLngPoints = <LatLng>[];
    for (final rawPoint in routePointsRaw) {
      if (rawPoint is! Map) {
        continue;
      }
      final pointMap = Map<String, dynamic>.from(rawPoint);
      final latitude = (pointMap['lat'] as num?)?.toDouble();
      final longitude = (pointMap['lng'] as num?)?.toDouble();
      if (latitude == null || longitude == null) {
        continue;
      }
      latLngPoints.add(LatLng(latitude, longitude));
    }
    return latLngPoints;
  }

  Widget _buildCoverageSummary(Map<String, dynamic> validationSummary) {
    final workoutCount = validationSummary['workoutCount'] as int? ?? 0;
    final coverageMap =
        (validationSummary['fieldCoverage'] as Map?)?.map(
          (key, value) => MapEntry('$key', Map<String, dynamic>.from(value)),
        ) ??
        const <String, Map<String, dynamic>>{};

    final orderedFields = [
      'distanceMeters',
      'energyKcal',
      'avgHeartRateBpm',
      'maxHeartRateBpm',
      'heartRateSampleCount',
      'routeAvailable',
      'sourceName',
      'deviceModel',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Coverage ($workoutCount workouts)',
          style: AppTypography.caption.copyWith(
            color: AppColors.textColor4,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (validationSummary['totalHeartRateSamples'] != null) ...[
          Text(
            'Total HR samples: ${validationSummary['totalHeartRateSamples']} '
            'across ${validationSummary['workoutsWithHeartRateSamples'] ?? 0} workouts',
            style: AppTypography.caption.copyWith(color: AppColors.textColor3),
          ),
          const SizedBox(height: AppSpacing.xs),
        ],
        const SizedBox(height: AppSpacing.xs),
        ...orderedFields.map((fieldName) {
          final fieldSummary = coverageMap[fieldName];
          final presentCount = fieldSummary?['present'] as int? ?? 0;
          final missingCount = fieldSummary?['missing'] as int? ?? workoutCount;
          return Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(
              '$fieldName: $presentCount present, $missingCount missing',
              style: AppTypography.caption.copyWith(
                color: AppColors.textColor3,
              ),
            ),
          );
        }),
      ],
    );
  }

  String _formatPace(double secondsPerKilometer) {
    final wholeSeconds = secondsPerKilometer.round();
    final minutes = wholeSeconds ~/ 60;
    final seconds = wholeSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}/km';
  }

  Future<void> _loadPreviewRuns() async {
    setState(() {
      _isLoadingPreview = true;
      _errorMessage = null;
    });
    try {
      final healthKitBridge = ref.read(healthKitBridgeProvider);
      final runs = await healthKitBridge.fetchRecentRunningWorkouts(
        maxWorkouts: 8,
        includeRoute: true,
        maxRoutePoints: 1500,
        includeHeartRateSeries: true,
      );
      if (!mounted) return;
      setState(() {
        _previewRuns = runs;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = '$error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingPreview = false;
        });
      }
    }
  }

  Future<void> _validateFields() async {
    setState(() {
      _isLoadingValidation = true;
      _errorMessage = null;
    });
    try {
      final healthKitBridge = ref.read(healthKitBridgeProvider);
      final validationSummary = await healthKitBridge
          .validateRunningWorkoutFields(maxWorkouts: 30);
      if (!mounted) return;
      setState(() {
        _validationSummary = validationSummary;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = '$error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingValidation = false;
        });
      }
    }
  }
}
