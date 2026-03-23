import 'package:ethan_utils/ethan_utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:workouts/models/workout_block.dart';
import 'package:workouts/models/workout_exercise.dart';
import 'package:workouts/models/workout_template.dart';
import 'package:workouts/theme/app_theme.dart';

class TemplateDetailScreen extends StatefulWidget {
  const TemplateDetailScreen({super.key, required this.template});

  final WorkoutTemplate template;

  @override
  State<TemplateDetailScreen> createState() => _TemplateDetailScreenState();
}

class _TemplateDetailScreenState extends State<TemplateDetailScreen> {
  final Set<String> _expandedBlockIds = {};

  @override
  void initState() {
    super.initState();
    // Expand the first block by default.
    if (widget.template.blocks.isNotEmpty) {
      _expandedBlockIds.add(widget.template.blocks.first.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.backgroundDepth1,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: AppColors.backgroundDepth1,
        border: const Border(
          bottom: BorderSide(color: AppColors.borderDepth1),
        ),
        middle: Text(
          widget.template.name,
          style: AppTypography.subtitle,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      child: SafeArea(child: _body()),
    );
  }

  Widget _body() {
    return ListView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      children: [
        _templateHeader(),
        const SizedBox(height: AppSpacing.lg),
        _blocksSection(),
        const SizedBox(height: AppSpacing.xxl),
      ],
    );
  }

  Widget _templateHeader() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.backgroundDepth2,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.borderDepth1),
      ),
      child: _headerContent(),
    );
  }

  Widget _headerContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.template.name, style: AppTypography.title),
        if (widget.template.goal.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            widget.template.goal,
            style: AppTypography.body.copyWith(color: AppColors.textColor3),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        _headerStatsRow(),
        if (widget.template.notes != null &&
            widget.template.notes!.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          _headerNotesBox(),
        ],
      ],
    );
  }

  Widget _headerStatsRow() {
    final totalBlocks = widget.template.blocks.length;
    final totalExercises =
        widget.template.blocks.expand((block) => block.exercises).length;
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

  Widget _headerNotesBox() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.backgroundDepth3,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        widget.template.notes!,
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

  Widget _blocksSection() {
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
        ...widget.template.blocks.map(_blockCard),
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
                (exercise) => _exerciseRow(exercise),
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

  Widget _exerciseRow(WorkoutExercise exercise) {
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
          if (exercise.prescription.isNotEmpty)
            Text(
              exercise.prescription,
              style: AppTypography.caption.copyWith(
                color: AppColors.textColor4,
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
      ),
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
