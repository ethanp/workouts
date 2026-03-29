import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:workouts/models/fitness_goal.dart';
import 'package:workouts/models/workout_template.dart';
import 'package:workouts/providers/background_notes_provider.dart';
import 'package:workouts/providers/bulk_benefits_provider.dart';
import 'package:workouts/providers/goals_provider.dart';
import 'package:workouts/services/repositories/template_repository_powersync.dart';
import 'package:workouts/theme/app_theme.dart';
import 'package:workouts/widgets/library/exercises_tab.dart';
import 'package:workouts/widgets/library/goals_tab.dart';
import 'package:workouts/widgets/library/influences_tab.dart';
import 'package:workouts/widgets/library/locations_tab.dart';
import 'package:workouts/widgets/library/templates_tab.dart';
import 'package:workouts/widgets/sync_status_icon.dart';

enum _LibrarySegment { goals, exercises, templates, influences, locations }

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  _LibrarySegment _segment = _LibrarySegment.goals;

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.backgroundDepth1,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: AppColors.backgroundDepth1,
        border: const Border(
          bottom: BorderSide(color: AppColors.borderDepth1),
        ),
        leading: const SyncStatusIcon(),
        middle: const Text('Library', style: AppTypography.subtitle),
        trailing: _addButton(),
      ),
      child: SafeArea(
        child: Column(
          children: [
            _segmentedControl(),
            Expanded(child: _segmentBody()),
          ],
        ),
      ),
    );
  }

  Widget _addButton() {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: _onAddPressed,
      child: const Icon(CupertinoIcons.add, color: AppColors.accentPrimary),
    );
  }

  Widget _segmentedControl() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: CupertinoSlidingSegmentedControl<_LibrarySegment>(
        groupValue: _segment,
        onValueChanged: (selected) {
          if (selected != null) setState(() => _segment = selected);
        },
        children: const {
          _LibrarySegment.goals: _SegmentLabel('Goals'),
          _LibrarySegment.exercises: _SegmentLabel('Exercises'),
          _LibrarySegment.templates: _SegmentLabel('Templates'),
          _LibrarySegment.influences: _SegmentLabel('Influences'),
          _LibrarySegment.locations: _SegmentLabel('Locations'),
        },
      ),
    );
  }

  Widget _segmentBody() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      child: switch (_segment) {
        _LibrarySegment.goals => GoalsTab(
            key: const ValueKey(_LibrarySegment.goals),
            onAddPressed: _onAddPressed,
          ),
        _LibrarySegment.exercises => ExercisesTab(
            key: const ValueKey(_LibrarySegment.exercises),
            onGenerateAllPressed: _onGenerateAll,
          ),
        _LibrarySegment.templates => TemplatesTab(
            key: const ValueKey(_LibrarySegment.templates),
            onAddPressed: _onAddPressed,
          ),
        _LibrarySegment.influences => const InfluencesTab(
            key: ValueKey(_LibrarySegment.influences),
          ),
        _LibrarySegment.locations => const LocationsTab(
            key: ValueKey(_LibrarySegment.locations),
          ),
      },
    );
  }

  void _onAddPressed() {
    switch (_segment) {
      case _LibrarySegment.goals:
        _showGoalsAddMenu();
      case _LibrarySegment.exercises:
        // Exercises are managed via templates; no direct add flow.
        break;
      case _LibrarySegment.templates:
        _showNewTemplateSheet();
      case _LibrarySegment.influences:
        _showAddInfluenceSheet();
      case _LibrarySegment.locations:
        _showAddLocationSheet();
    }
  }

  void _showGoalsAddMenu() {
    final goals = ref.read(goalsStreamProvider).value ?? [];
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(ctx).pop();
              _showAddGoalSheet();
            },
            child: const Text('Add Goal'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(ctx).pop();
              _showAddNoteSheet(goals);
            },
            child: const Text('Add Background Note'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  void _showAddGoalSheet() {
    final goalsNotifier = ref.read(goalsControllerProvider.notifier);
    showCupertinoModalPopup<void>(
      context: context,
      builder: (_) => GoalFormSheet(
        onSave: (title, category, description, priority) async {
          await goalsNotifier.addGoal(
                title: title,
                category: category,
                description: description,
                priority: priority,
              );
        },
      ),
    );
  }

  void _showAddNoteSheet(List<FitnessGoal> goals) {
    final notesNotifier =
        ref.read(backgroundNotesControllerProvider.notifier);
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => NoteFormSheet(
        availableGoals: goals,
        onSave: (content, category, goalId) {
          notesNotifier.addNote(
                content: content,
                category: category,
                goalId: goalId,
              );
          Navigator.of(ctx).pop();
        },
      ),
    );
  }

  void _showNewTemplateSheet() {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (_) => const _NewTemplateSheet(),
    );
  }

  void _showAddInfluenceSheet() {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (_) => const InfluenceFormSheet(),
    );
  }

  void _showAddLocationSheet() {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (_) => const LocationFormSheet(),
    );
  }

  Future<void> _onGenerateAll() async {
    await ref.read(bulkBenefitsControllerProvider.notifier).generateAll();
  }
}

class _SegmentLabel extends StatelessWidget {
  const _SegmentLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w400,
      ),
    );
  }
}

class _NewTemplateSheet extends ConsumerStatefulWidget {
  const _NewTemplateSheet();

  @override
  ConsumerState<_NewTemplateSheet> createState() => _NewTemplateSheetState();
}

class _NewTemplateSheetState extends ConsumerState<_NewTemplateSheet> {
  final _nameController = TextEditingController();
  final _goalController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _goalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: const BoxDecoration(
        color: AppColors.backgroundDepth2,
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      child: SafeArea(top: false, child: _sheetScrollContent(context)),
    );
  }

  Widget _sheetScrollContent(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _dragHandle(),
          const SizedBox(height: AppSpacing.lg),
          const Text(
            'New Template',
            style: AppTypography.title,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xl),
          _nameFormField(),
          const SizedBox(height: AppSpacing.lg),
          _goalFormField(),
          const SizedBox(height: AppSpacing.xl),
          _createButton(context),
          const SizedBox(height: AppSpacing.md),
          _cancelButton(context),
        ],
      ),
    );
  }

  Widget _nameFormField() {
    return _formField(
      label: 'Name',
      child: CupertinoTextField(
        controller: _nameController,
        placeholder: 'e.g., Upper Body Push',
        onChanged: (_) => setState(() {}),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.backgroundDepth3,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        style: AppTypography.body.copyWith(color: AppColors.textColor1),
        placeholderStyle: AppTypography.body.copyWith(
          color: AppColors.textColor4,
        ),
      ),
    );
  }

  Widget _goalFormField() {
    return _formField(
      label: 'Goal (optional)',
      child: CupertinoTextField(
        controller: _goalController,
        placeholder: 'e.g., Build pressing strength',
        padding: const EdgeInsets.all(AppSpacing.md),
        maxLines: 2,
        decoration: BoxDecoration(
          color: AppColors.backgroundDepth3,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        style: AppTypography.body.copyWith(color: AppColors.textColor1),
        placeholderStyle: AppTypography.body.copyWith(
          color: AppColors.textColor4,
        ),
      ),
    );
  }

  Widget _createButton(BuildContext context) {
    return CupertinoButton.filled(
      onPressed: _nameController.text.trim().isEmpty
          ? null
          : () => _create(context),
      child: const Text(
        'Create Template',
        style: TextStyle(
          color: CupertinoColors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _cancelButton(BuildContext context) {
    return CupertinoButton(
      onPressed: () => Navigator.of(context).pop(),
      child: Text('Cancel', style: TextStyle(color: AppColors.textColor3)),
    );
  }

  Widget _dragHandle() => Center(
        child: Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: AppColors.borderDepth3,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      );

  Widget _formField({required String label, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.caption.copyWith(
            color: AppColors.textColor3,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        child,
      ],
    );
  }

  Future<void> _create(BuildContext context) async {
    // Create minimal template — user can populate blocks in the workout editor.
    final navigator = Navigator.of(context);
    final repository = ref.read(templateRepositoryPowerSyncProvider);
    final template = WorkoutTemplate(
      id: const Uuid().v4(),
      name: _nameController.text.trim(),
      goal: _goalController.text.trim(),
      blocks: const [],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await repository.saveTemplate(template);
    if (navigator.canPop()) navigator.pop();
  }
}
