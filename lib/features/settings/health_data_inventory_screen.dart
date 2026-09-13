import 'package:ethan_ui/ethan_ui.dart';
import 'package:ethan_utils/ethan_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workouts/features/cardio/cardio_provider.dart';
import 'package:workouts/models/health_data_inventory.dart';
import 'package:workouts/theme/cardio_type_palette.dart';
import 'package:workouts/utils/run_formatting.dart';

class const HealthDataInventoryTile() extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ELayout.spaceMd),
      decoration: BoxDecoration(
        color: EColors.backgroundLift,
        borderRadius: BorderRadius.circular(ELayout.radiusMd),
        border: Border.all(color: EColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Health data inventory', style: EText.section),
          const SizedBox(height: ELayout.spaceXs),
          Text(
            'See which Apple Health signals each treadmill, indoor walk, and Watch source actually writes.',
            style: EText.body.medium.copyWith(color: EColors.textTertiary),
          ),
          const SizedBox(height: ELayout.spaceMd),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => _showHealthDataInventoryScreen(context),
              child: const Text('Open inventory'),
            ),
          ),
        ],
      ),
    );
  }

  void _showHealthDataInventoryScreen(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const HealthDataInventoryScreen(),
      ),
    );
  }
}

class const HealthDataInventoryScreen() extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inventoryState = ref.watch(healthDataInventoryControllerProvider);
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: const EAppHeader(title: 'Health data inventory'),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.all(
            ELayout.spaceLg,
          ).withOverlaidTabBar(context),
          children: [
            _introCard(context, ref, inventoryState),
            if (inventoryState.errorMessage != null) ...[
              const SizedBox(height: ELayout.spaceMd),
              SelectableText(
                'Unable to inspect Apple Health: ${inventoryState.errorMessage}',
                style: EText.body.medium.copyWith(color: EColors.danger),
              ),
            ],
            const SizedBox(height: ELayout.spaceLg),
            if (inventoryState.inventory != null)
              _inventoryBody(inventoryState.inventory!)
            else if (!inventoryState.isInspecting)
              _emptyHint(),
          ],
        ),
      ),
    );
  }

  Widget _introCard(
    BuildContext context,
    WidgetRef ref,
    HealthDataInventoryState inventoryState,
  ) {
    return Container(
      padding: const EdgeInsets.all(ELayout.spaceMd),
      decoration: BoxDecoration(
        color: EColors.backgroundLift,
        borderRadius: BorderRadius.circular(ELayout.radiusMd),
        border: Border.all(color: EColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Inspects recent indoor and outdoor cardio workouts on this device. '
            'Asks HealthKit for a wide quantity/category/series set, plus every '
            'type already attached as workout statistics — including types we '
            'did not list in advance. Share status is shown because HealthKit '
            'does not reveal read denial.',
            style: EText.body.medium.copyWith(color: EColors.textTertiary),
          ),
          const SizedBox(height: ELayout.spaceMd),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: inventoryState.isInspecting
                  ? null
                  : () => ref
                        .read(healthDataInventoryControllerProvider.notifier)
                        .inspectRecentWorkouts(),
              child: Text(
                inventoryState.isInspecting
                    ? 'Inspecting…'
                    : 'Inspect last 40 workouts',
              ),
            ),
          ),
          if (inventoryState.inspectProgress != null) ...[
            const SizedBox(height: ELayout.spaceMd),
            _inspectProgress(inventoryState.inspectProgress!),
          ],
          if (inventoryState.inventory != null &&
              !inventoryState.isInspecting) ...[
            const SizedBox(height: ELayout.spaceMd),
            _emailAndCopyJson(context, inventoryState.inventory!),
          ],
        ],
      ),
    );
  }

  Widget _inspectProgress(HealthInventoryInspectProgress inspectProgress) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          inspectProgress.caption,
          style: EText.body.medium.copyWith(color: EColors.textSecondary),
        ),
        if (inspectProgress.totalWorkouts > 0) ...[
          const SizedBox(height: ELayout.spaceXs),
          Text(
            '${inspectProgress.completedWorkouts} of ${inspectProgress.totalWorkouts} workouts',
            style: EText.caption.copyWith(color: EColors.textTertiary),
          ),
          const SizedBox(height: ELayout.spaceXs),
          ClipRRect(
            borderRadius: BorderRadius.circular(ELayout.radiusSm),
            child: Container(
              height: 6,
              color: EColors.surface,
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: inspectProgress.fraction,
                child: Container(color: EColors.accent),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _emailAndCopyJson(
    BuildContext context,
    HealthDataInventory inventory,
  ) {
    return Row(
      children: [
        Expanded(
          child: FilledButton(
            onPressed: () => _emailInventoryJson(context, inventory),
            child: const Text('Email JSON'),
          ),
        ),
        const SizedBox(width: ELayout.spaceSm),
        Expanded(
          child: FilledButton(
            style: FilledButton.styleFrom(backgroundColor: EColors.surface),
            onPressed: () async {
              await Clipboard.setData(
                ClipboardData(text: inventory.jsonEmailBody),
              );
              if (context.mounted) {
                context.textSnackBar('Inventory JSON copied');
              }
            },
            child: const Text('Copy JSON'),
          ),
        ),
      ],
    );
  }

  void _emailInventoryJson(
    BuildContext context,
    HealthDataInventory inventory,
  ) {
    ErrorReportDialog.show(
      context: context,
      title: 'Health data inventory',
      userMessage:
          'JSON of the last inspection. Paste it into Cursor for feature work. '
          'If Gmail opens empty, use Copy JSON — URL bodies have a size limit.',
      emailSubject: 'Workouts Health data inventory JSON',
      reportBody: inventory.jsonEmailBody,
    );
  }

  Widget _emptyHint() => Text(
    'Run an inspection to see which signals each Watch, GymKit, and third-party source actually writes.',
    style: EText.body.medium.copyWith(color: EColors.textTertiary),
  );

  Widget _inventoryBody(HealthDataInventory inventory) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (inventory.queriedQuantityTypes.isNotEmpty) ...[
          _sectionLabel('Queried quantity types'),
          Text(
            inventory.queriedQuantityTypes
                .map((type) => type.shortHealthKitType)
                .join(', '),
            style: EText.caption.copyWith(color: EColors.textSecondary),
          ),
          const SizedBox(height: ELayout.spaceLg),
        ],
        _sectionLabel('Share status'),
        ...inventory.requestedTypes.map(_shareStatusRow),
        const SizedBox(height: ELayout.spaceLg),
        _sectionLabel('Source matrix'),
        if (inventory.sourceMatrix.isEmpty)
          Text(
            'No cardio workouts found.',
            style: EText.body.medium.copyWith(color: EColors.textTertiary),
          )
        else
          ...inventory.sourceMatrix.map(_matrixRow),
        const SizedBox(height: ELayout.spaceLg),
        _sectionLabel('Workouts'),
        ...inventory.workouts.map(_workoutCard),
      ],
    );
  }

  Widget _sectionLabel(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: ELayout.spaceSm),
      child: Text(
        title.toUpperCase(),
        style: EText.caption.copyWith(
          color: EColors.textMuted,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  Widget _shareStatusRow(HealthShareStatus status) {
    return Padding(
      padding: const EdgeInsets.only(bottom: ELayout.spaceXs),
      child: Text(
        '${status.id.shortHealthKitType} · ${status.shareStatus}',
        style: EText.caption.copyWith(color: EColors.textSecondary),
      ),
    );
  }

  Widget _matrixRow(HealthSourceMatrixRow row) {
    return Container(
      margin: const EdgeInsets.only(bottom: ELayout.spaceSm),
      padding: const EdgeInsets.all(ELayout.spaceMd),
      decoration: BoxDecoration(
        color: EColors.backgroundLift,
        borderRadius: BorderRadius.circular(ELayout.radiusMd),
        border: Border.all(color: EColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${row.activityType.displayName} · ${row.cohortLabel}',
            style: EText.body.medium.copyWith(color: row.activityType.color),
          ),
          const SizedBox(height: ELayout.spaceXs),
          Text(
            '${row.sourceKey} · ${row.workoutCount} workout${row.workoutCount == 1 ? '' : 's'}',
            style: EText.caption.copyWith(color: EColors.textTertiary),
          ),
          const SizedBox(height: ELayout.spaceXs),
          Text(
            row.signalsPresent.isEmpty
                ? 'No associated samples'
                : row.signalsPresent.join(', '),
            style: EText.caption.copyWith(color: EColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _workoutCard(HealthInventoryWorkout workout) {
    final presentSignals = workout.signals
        .where((signal) => signal.isPresent)
        .map((signal) => '${signal.shortType} (${signal.sampleCount})')
        .join(', ');
    final statisticsCaption = workout.statistics
        .map(_statisticCaption)
        .join(', ');
    final metadataCaption = workout.metadata.isNotEmpty
        ? workout.metadata.entries
              .map((entry) => '${entry.key}=${entry.value}')
              .join(', ')
        : workout.metadataKeys.join(', ');
    return Container(
      margin: const EdgeInsets.only(bottom: ELayout.spaceSm),
      padding: const EdgeInsets.all(ELayout.spaceMd),
      decoration: BoxDecoration(
        color: EColors.backgroundLift,
        borderRadius: BorderRadius.circular(ELayout.radiusMd),
        border: Border.all(color: EColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${workout.activityType.displayName} · ${Format.dateTime(workout.startedAt)}',
            style: EText.body.medium,
          ),
          const SizedBox(height: ELayout.spaceXs),
          Text(
            '${workout.sourceName} · ${workout.machineLinked ? 'Machine-linked' : 'Watch estimate'}',
            style: EText.caption.copyWith(color: EColors.textTertiary),
          ),
          if (presentSignals.isNotEmpty) ...[
            const SizedBox(height: ELayout.spaceXs),
            Text(
              presentSignals,
              style: EText.caption.copyWith(color: EColors.textSecondary),
            ),
          ],
          if (workout.eventTypes.isNotEmpty) ...[
            const SizedBox(height: ELayout.spaceXs),
            Text(
              'Events: ${workout.eventTypes.join(', ')}',
              style: EText.caption.copyWith(color: EColors.textMuted),
            ),
          ],
          if (statisticsCaption.isNotEmpty) ...[
            const SizedBox(height: ELayout.spaceXs),
            Text(
              'Statistics: $statisticsCaption',
              style: EText.caption.copyWith(color: EColors.textSecondary),
            ),
          ],
          if (workout.activities.isNotEmpty) ...[
            const SizedBox(height: ELayout.spaceXs),
            Text(
              'Activities: ${workout.activities.map((activity) => activity.activityType).join(', ')}',
              style: EText.caption.copyWith(color: EColors.textMuted),
            ),
          ],
          if (metadataCaption.isNotEmpty) ...[
            const SizedBox(height: ELayout.spaceXs),
            Text(
              'Metadata: $metadataCaption',
              style: EText.caption.copyWith(color: EColors.textMuted),
            ),
          ],
        ],
      ),
    );
  }

  String _statisticCaption(HealthWorkoutStatistic statistic) {
    final average = statistic.average;
    if (average == null) return statistic.shortType;
    final unit = statistic.unit ?? '';
    return '${statistic.shortType} avg ${average.toStringAsFixed(1)} $unit'
        .trim();
  }
}
