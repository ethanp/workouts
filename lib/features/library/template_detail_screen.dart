import 'package:ethan_utils/ethan_utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workouts/features/library/templates_provider.dart';
import 'package:workouts/models/warmup_sets.dart';
import 'package:workouts/models/workout_block.dart';
import 'package:workouts/models/workout_exercise.dart';
import 'package:workouts/models/workout_template.dart';
import 'package:workouts/services/repositories/templates/template_repository_powersync.dart';
import 'package:workouts/theme/app_theme.dart';

class TemplateDetailScreen extends ConsumerStatefulWidget {
  const TemplateDetailScreen({super.key, required this.templateId});

  final String templateId;

  @override
  ConsumerState<TemplateDetailScreen> createState() =>
      _TemplateDetailScreenState();
}

class _TemplateDetailScreenState extends ConsumerState<TemplateDetailScreen> {
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

  Widget _missingTemplateScaffold() => CupertinoPageScaffold(
    backgroundColor: AppColors.backgroundDepth1,
    navigationBar: CupertinoNavigationBar(
      backgroundColor: AppColors.backgroundDepth1,
      border: const Border(bottom: BorderSide(color: AppColors.borderDepth1)),
    ),
    child: const Center(child: CupertinoActivityIndicator()),
  );

  Widget _scaffold(WorkoutTemplate template) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.backgroundDepth1,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: AppColors.backgroundDepth1,
        border: const Border(bottom: BorderSide(color: AppColors.borderDepth1)),
        middle: Text(
          template.name,
          style: AppTypography.subtitle,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      child: SafeArea(child: _body(template)),
    );
  }

  Widget _body(WorkoutTemplate template) {
    return ListView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      children: [
        _templateHeader(template),
        const SizedBox(height: AppSpacing.lg),
        _blocksSection(template),
        const SizedBox(height: AppSpacing.xxl),
      ],
    );
  }

  Widget _templateHeader(WorkoutTemplate template) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.backgroundDepth2,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.borderDepth1),
      ),
      child: _headerContent(template),
    );
  }

  Widget _headerContent(WorkoutTemplate template) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(template.name, style: AppTypography.title),
        if (template.goal.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            template.goal,
            style: AppTypography.body.copyWith(color: AppColors.textColor3),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        _headerStatsRow(template),
        if (template.notes != null && template.notes!.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          _headerNotesBox(template),
        ],
      ],
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
          icon: CupertinoIcons.rectangle_stack,
          label: '$totalBlocks ${totalBlocks == 1 ? 'block' : 'blocks'}',
        ),
        const SizedBox(width: AppSpacing.lg),
        _metaStat(
          icon: CupertinoIcons.list_bullet,
          label:
              '$totalExercises ${totalExercises == 1 ? 'exercise' : 'exercises'}',
        ),
      ],
    );
  }

  Widget _headerNotesBox(WorkoutTemplate template) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.backgroundDepth3,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        template.notes!,
        style: AppTypography.caption.copyWith(color: AppColors.textColor3),
      ),
    );
  }

  Widget _metaStat({required IconData icon, required String label}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppColors.textColor4),
        const SizedBox(width: AppSpacing.xs),
        Text(
          label,
          style: AppTypography.caption.copyWith(color: AppColors.textColor4),
        ),
      ],
    );
  }

  Widget _blocksSection(WorkoutTemplate template) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              CupertinoIcons.rectangle_stack,
              size: 12,
              color: AppColors.textColor4,
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              'BLOCKS',
              style: AppTypography.caption.copyWith(
                color: AppColors.textColor4,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        ...template.blocks.map(_blockCard),
      ],
    );
  }

  Widget _blockCard(WorkoutBlock block) {
    final isExpanded = _expandedBlockIds.contains(block.id);
    final durationMinutes = block.targetDuration.inMinutes;
    final durationLabel = durationMinutes > 0 ? '${durationMinutes}m' : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.backgroundDepth2,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.borderDepth1),
        ),
        child: Column(
          children: [
            _blockHeader(block, isExpanded, durationLabel),
            if (isExpanded) ...[
              Container(
                height: 1,
                margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                color: AppColors.borderDepth1,
              ),
              ...block.exercises.map(
                (exercise) => _exerciseRow(block, exercise),
              ),
              const SizedBox(height: AppSpacing.xs),
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
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            _BlockTypeBadge(type: block.type),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: _blockTitleColumn(block, durationLabel)),
            Icon(
              isExpanded
                  ? CupertinoIcons.chevron_up
                  : CupertinoIcons.chevron_down,
              size: 14,
              color: AppColors.textColor4,
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
          style: AppTypography.body.copyWith(
            color: AppColors.textColor1,
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
            style: AppTypography.caption.copyWith(color: AppColors.textColor4),
          ),
          const SizedBox(width: AppSpacing.sm),
          _dotSeparator(),
          const SizedBox(width: AppSpacing.sm),
        ],
        if (block.rounds > 1) ...[
          Text(
            '${block.rounds} rounds',
            style: AppTypography.caption.copyWith(color: AppColors.textColor4),
          ),
          const SizedBox(width: AppSpacing.sm),
          _dotSeparator(),
          const SizedBox(width: AppSpacing.sm),
        ],
        Text(
          '${block.exercises.length} ${block.exercises.length == 1 ? 'exercise' : 'exercises'}',
          style: AppTypography.caption.copyWith(color: AppColors.textColor4),
        ),
      ],
    );
  }

  Widget _dotSeparator() => Container(
    width: 3,
    height: 3,
    decoration: const BoxDecoration(
      color: AppColors.textColor4,
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
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 3,
            margin: const EdgeInsets.only(right: AppSpacing.md, left: 2),
            decoration: const BoxDecoration(
              color: AppColors.textColor4,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Text(
              exercise.name,
              style: AppTypography.body.copyWith(
                color: AppColors.textColor2,
                fontSize: 14,
              ),
            ),
          ),
          if (exercise.prescriptionLabel.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: Text(
                exercise.prescriptionLabel,
                style: AppTypography.caption.copyWith(
                  color: AppColors.textColor4,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          if (warmupSets.canRemove)
            _warmupChip(
              icon: CupertinoIcons.minus_circle,
              onTap: () => _removeWarmupSet(block.id, exercise),
            ),
          if (warmupSets.canAdd)
            _warmupChip(
              icon: CupertinoIcons.plus_circle,
              onTap: () => _addWarmupSet(block.id, exercise),
            ),
        ],
      ),
    );
  }

  Widget _warmupChip({required IconData icon, required VoidCallback onTap}) =>
      CupertinoButton(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
        minimumSize: const Size(28, 28),
        onPressed: onTap,
        child: Icon(icon, size: 18, color: AppColors.textColor3),
      );

  Future<void> _addWarmupSet(String blockId, WorkoutExercise exercise) {
    return ref.read(templateRepositoryPowerSyncProvider).addWarmupSet(
      templateId: widget.templateId,
      blockId: blockId,
      exercise: exercise,
    );
  }

  Future<void> _removeWarmupSet(String blockId, WorkoutExercise exercise) {
    return ref.read(templateRepositoryPowerSyncProvider).removeWarmupSet(
      templateId: widget.templateId,
      blockId: blockId,
      exercise: exercise,
    );
  }
}

class _BlockTypeBadge extends StatelessWidget {
  const _BlockTypeBadge({required this.type});

  final WorkoutBlockType type;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.sm),
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
    WorkoutBlockType.warmup => AppColors.warning,
    WorkoutBlockType.animalFlow => AppColors.accentSecondary,
    WorkoutBlockType.strength => AppColors.error,
    WorkoutBlockType.mobility => AppColors.success,
    WorkoutBlockType.core => AppColors.accentPrimary,
    WorkoutBlockType.conditioning => AppColors.warning,
    WorkoutBlockType.cooldown => AppColors.textColor3,
  };
}
