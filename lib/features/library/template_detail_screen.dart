import 'package:ethan_utils/ethan_utils.dart';
import 'package:ethan_ui/ethan_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workouts/features/active_session/active_session_provider.dart';
import 'package:workouts/features/library/templates_provider.dart';
import 'package:workouts/models/warmup_sets.dart';
import 'package:workouts/models/workout_block.dart';
import 'package:workouts/models/workout_exercise.dart';
import 'package:workouts/models/workout_template.dart';
import 'package:workouts/services/repositories/templates/template_repository_powersync.dart';

class const TemplateDetailScreen({required final String templateId})
    extends ConsumerStatefulWidget {
  @override
  ConsumerState<TemplateDetailScreen> createState() =>
      _TemplateDetailScreenState();
}

class _TemplateDetailScreenState() extends ConsumerState<TemplateDetailScreen> {
  final Set<String> _expandedBlockIds = {};
  bool _initializedExpanded = false;

  @override
  Widget build(BuildContext context) {
    final WorkoutTemplate? template = ref.watch(
      templateByIdProvider(widget.templateId),
    );
    if (template == null) return _missingTemplateScaffold();
    _ensureFirstBlockExpanded(template);
    return _scaffold(template);
  }

  void _ensureFirstBlockExpanded(WorkoutTemplate template) {
    if (_initializedExpanded || template.blocks.isEmpty) return;
    _expandedBlockIds.add(template.blocks.first.id);
    _initializedExpanded = true;
  }

  Widget _missingTemplateScaffold() => const Scaffold(
    backgroundColor: Colors.transparent,
    appBar: EAppHeader(title: 'Template'),
    body: SafeArea(child: Center(child: CircularProgressIndicator())),
  );

  Widget _scaffold(WorkoutTemplate template) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: EAppHeader(title: template.name),
      body: SafeArea(child: _body(template)),
    );
  }

  Widget _body(WorkoutTemplate template) {
    return ListView(
      padding: const EdgeInsets.symmetric(
        horizontal: ELayout.spaceLg,
        vertical: ELayout.spaceMd,
      ),
      children: [
        _templateHeader(template),
        const SizedBox(height: ELayout.spaceLg),
        _blocksSection(template),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _templateHeader(WorkoutTemplate template) {
    return Container(
      padding: const EdgeInsets.all(ELayout.spaceLg),
      decoration: BoxDecoration(
        color: EColors.backgroundLift,
        borderRadius: BorderRadius.circular(ELayout.radiusMd),
        border: Border.all(color: EColors.border),
      ),
      child: _headerContent(template),
    );
  }

  Widget _headerContent(WorkoutTemplate template) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(template.name, style: EText.title),
        if (template.goal.isNotEmpty) ...[
          const SizedBox(height: ELayout.spaceSm),
          Text(
            template.goal,
            style: EText.body.medium.copyWith(color: EColors.textTertiary),
          ),
        ],
        const SizedBox(height: ELayout.spaceMd),
        _headerStatsRow(template),
        if (template.notes != null && template.notes!.isNotEmpty) ...[
          const SizedBox(height: ELayout.spaceMd),
          _headerNotesBox(template),
        ],
        const SizedBox(height: ELayout.spaceMd),
        _startWorkoutButton(template),
      ],
    );
  }

  Widget _startWorkoutButton(WorkoutTemplate template) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: () =>
            ref.read(activeSessionProvider.notifier).start(template.id),
        child: const Text('Start workout'),
      ),
    );
  }

  Widget _headerStatsRow(WorkoutTemplate template) {
    final totalBlocks = template.blocks.length;
    final totalExercises = template.blocks
        .expand((block) => block.exercises)
        .length;
    return Row(
      children: [
        _metaStat(
          icon: Icons.layers,
          label: '$totalBlocks ${totalBlocks == 1 ? 'block' : 'blocks'}',
        ),
        const SizedBox(width: ELayout.spaceLg),
        _metaStat(
          icon: Icons.format_list_bulleted,
          label:
              '$totalExercises ${totalExercises == 1 ? 'exercise' : 'exercises'}',
        ),
      ],
    );
  }

  Widget _headerNotesBox(WorkoutTemplate template) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(ELayout.spaceMd),
      decoration: BoxDecoration(
        color: EColors.surface,
        borderRadius: BorderRadius.circular(ELayout.radiusSm),
      ),
      child: Text(
        template.notes!,
        style: EText.caption.copyWith(color: EColors.textTertiary),
      ),
    );
  }

  Widget _metaStat({required IconData icon, required String label}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: EColors.textMuted),
        const SizedBox(width: ELayout.spaceXs),
        Text(label, style: EText.caption.copyWith(color: EColors.textMuted)),
      ],
    );
  }

  Widget _blocksSection(WorkoutTemplate template) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.layers, size: 12, color: EColors.textMuted),
            const SizedBox(width: ELayout.spaceXs),
            Text(
              'BLOCKS',
              style: EText.caption.copyWith(
                color: EColors.textMuted,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
        const SizedBox(height: ELayout.spaceSm),
        ...template.blocks.map(_blockCard),
      ],
    );
  }

  Widget _blockCard(WorkoutBlock block) {
    final isExpanded = _expandedBlockIds.contains(block.id);
    final durationMinutes = block.targetDuration.inMinutes;
    final durationLabel = durationMinutes > 0 ? '${durationMinutes}m' : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: ELayout.spaceSm),
      child: Container(
        decoration: BoxDecoration(
          color: EColors.backgroundLift,
          borderRadius: BorderRadius.circular(ELayout.radiusMd),
          border: Border.all(color: EColors.border),
        ),
        child: Column(
          children: [
            _blockHeader(block, isExpanded, durationLabel),
            if (isExpanded) ...[
              Container(
                height: 1,
                margin: const EdgeInsets.symmetric(horizontal: ELayout.spaceMd),
                color: EColors.border,
              ),
              ...block.exercises.map(
                (exercise) => _exerciseRow(block, exercise),
              ),
              const SizedBox(height: ELayout.spaceXs),
            ],
          ],
        ),
      ),
    );
  }

  Widget _blockHeader(
    WorkoutBlock block,
    bool isExpanded,
    String? durationLabel,
  ) {
    return GestureDetector(
      onTap: () => _toggleBlock(block, isExpanded),
      child: Padding(
        padding: const EdgeInsets.all(ELayout.spaceMd),
        child: Row(
          children: [
            _BlockTypeBadge(type: block.type),
            const SizedBox(width: ELayout.spaceMd),
            Expanded(child: _blockTitleColumn(block, durationLabel)),
            Icon(
              isExpanded ? Icons.expand_less : Icons.expand_more,
              size: 14,
              color: EColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }

  void _toggleBlock(WorkoutBlock block, bool isExpanded) {
    setState(() {
      if (isExpanded) {
        _expandedBlockIds.remove(block.id);
      } else {
        _expandedBlockIds.add(block.id);
      }
    });
  }

  Widget _blockTitleColumn(WorkoutBlock block, String? durationLabel) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          block.title,
          style: EText.body.medium.copyWith(
            color: EColors.textPrimary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        _blockMetaRow(block, durationLabel),
      ],
    );
  }

  Widget _blockMetaRow(WorkoutBlock block, String? durationLabel) {
    return Row(
      children: [
        if (durationLabel != null) ...[
          Text(
            durationLabel,
            style: EText.caption.copyWith(color: EColors.textMuted),
          ),
          const SizedBox(width: ELayout.spaceSm),
          _dotSeparator(),
          const SizedBox(width: ELayout.spaceSm),
        ],
        if (block.rounds > 1) ...[
          Text(
            '${block.rounds} rounds',
            style: EText.caption.copyWith(color: EColors.textMuted),
          ),
          const SizedBox(width: ELayout.spaceSm),
          _dotSeparator(),
          const SizedBox(width: ELayout.spaceSm),
        ],
        Text(
          '${block.exercises.length} ${block.exercises.length == 1 ? 'exercise' : 'exercises'}',
          style: EText.caption.copyWith(color: EColors.textMuted),
        ),
      ],
    );
  }

  Widget _dotSeparator() => Container(
    width: 3,
    height: 3,
    decoration: const BoxDecoration(
      color: EColors.textMuted,
      shape: BoxShape.circle,
    ),
  );

  Widget _exerciseRow(WorkoutBlock block, WorkoutExercise exercise) {
    final warmupSets = WarmupSets(
      plannedSets: exercise.plannedSets,
      exercise: exercise,
      loggedSetCount: 0,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: ELayout.spaceMd,
        vertical: ELayout.spaceSm,
      ),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 3,
            margin: const EdgeInsets.only(right: ELayout.spaceMd, left: 2),
            decoration: const BoxDecoration(
              color: EColors.textMuted,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Text(
              exercise.name,
              style: EText.body.medium.copyWith(
                color: EColors.textSecondary,
                fontSize: 14,
              ),
            ),
          ),
          if (exercise.prescriptionLabel.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: ELayout.spaceSm),
              child: Text(
                exercise.prescriptionLabel,
                style: EText.caption.copyWith(
                  color: EColors.textMuted,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          if (warmupSets.canRemove)
            _warmupChip(
              icon: Icons.remove_circle_outline,
              onTap: () => _removeWarmupSet(block.id, exercise),
            ),
          if (warmupSets.canAdd)
            _warmupChip(
              icon: Icons.add_circle_outline,
              onTap: () => _addWarmupSet(block.id, exercise),
            ),
        ],
      ),
    );
  }

  Widget _warmupChip({required IconData icon, required VoidCallback onTap}) =>
      IconButton(
        onPressed: onTap,
        visualDensity: VisualDensity.compact,
        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
        padding: const EdgeInsets.symmetric(horizontal: ELayout.spaceXs),
        icon: Icon(icon, size: 18, color: EColors.textTertiary),
      );

  Future<void> _addWarmupSet(String blockId, WorkoutExercise exercise) {
    return ref
        .read(templateRepositoryPowerSyncProvider)
        .addWarmupSet(
          templateId: widget.templateId,
          blockId: blockId,
          exercise: exercise,
        );
  }

  Future<void> _removeWarmupSet(String blockId, WorkoutExercise exercise) {
    return ref
        .read(templateRepositoryPowerSyncProvider)
        .removeWarmupSet(
          templateId: widget.templateId,
          blockId: blockId,
          exercise: exercise,
        );
  }
}

class const _BlockTypeBadge({required final WorkoutBlockType type})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: ELayout.spaceSm,
        vertical: ELayout.spaceXs,
      ),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(ELayout.radiusSm),
      ),
      child: Text(
        type.name.capitalize,
        style: TextStyle(
          fontSize: 11,
          color: _color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Color get _color => switch (type) {
    WorkoutBlockType.warmup => EColors.warning,
    WorkoutBlockType.animalFlow => EColors.warning,
    WorkoutBlockType.strength => EColors.danger,
    WorkoutBlockType.mobility => EColors.success,
    WorkoutBlockType.core => EColors.accent,
    WorkoutBlockType.conditioning => EColors.warning,
    WorkoutBlockType.cooldown => EColors.textTertiary,
  };
}
