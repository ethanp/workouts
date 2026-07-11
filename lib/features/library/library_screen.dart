import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:workouts/features/goals/background_notes_provider.dart';
import 'package:workouts/features/goals/background_tab.dart';
import 'package:workouts/features/goals/goal_form_sheet.dart';
import 'package:workouts/features/goals/goals_provider.dart';
import 'package:workouts/features/goals/goals_tab.dart';
import 'package:workouts/features/goals/note_form_sheet.dart';
import 'package:workouts/features/library/bulk_benefits_provider.dart';
import 'package:workouts/features/library/exercises_tab.dart';
import 'package:workouts/features/library/influences_tab.dart';
import 'package:workouts/features/library/locations_tab.dart';
import 'package:workouts/features/library/templates_tab.dart';
import 'package:workouts/models/workout_template.dart';
import 'package:workouts/services/repositories/templates/template_repository_powersync.dart';
import 'package:workouts/theme/app_theme.dart';
import 'package:workouts/widgets/sync_status_icon.dart';

/// One Library destination: label, icon, and whether the section page shows +.
class LibrarySection {
  const LibrarySection({
    required this.id,
    required this.label,
    required this.icon,
    required this.subtitle,
    required this.canAdd,
  });

  final String id;
  final String label;
  final IconData icon;
  final String subtitle;
  final bool canAdd;
}

const librarySections = <LibrarySection>[
  LibrarySection(
    id: 'goals',
    label: 'Goals',
    icon: CupertinoIcons.flag_fill,
    subtitle: 'Training priorities and targets',
    canAdd: true,
  ),
  LibrarySection(
    id: 'background',
    label: 'Background',
    icon: CupertinoIcons.doc_text_fill,
    subtitle: 'Context for AI coaching',
    canAdd: true,
  ),
  LibrarySection(
    id: 'exercises',
    label: 'Exercises',
    icon: CupertinoIcons.circle_grid_3x3_fill,
    subtitle: 'Movements used in templates',
    canAdd: false,
  ),
  LibrarySection(
    id: 'templates',
    label: 'Templates',
    icon: CupertinoIcons.square_list_fill,
    subtitle: 'Reusable workout structures',
    canAdd: true,
  ),
  LibrarySection(
    id: 'influences',
    label: 'Influences',
    icon: CupertinoIcons.lightbulb_fill,
    subtitle: 'Coaches and training philosophies',
    canAdd: true,
  ),
  LibrarySection(
    id: 'locations',
    label: 'Locations',
    icon: CupertinoIcons.location_solid,
    subtitle: 'Gyms and places you train',
    canAdd: true,
  ),
];

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.backgroundDepth1,
      navigationBar: const CupertinoNavigationBar(
        backgroundColor: AppColors.backgroundDepth1,
        border: Border(bottom: BorderSide(color: AppColors.borderDepth1)),
        leading: SyncStatusIcon(),
        middle: Text('Library', style: AppTypography.subtitle),
      ),
      child: SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          itemCount: librarySections.length,
          separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
          itemBuilder: (context, sectionIndex) {
            final section = librarySections[sectionIndex];
            return _LibraryIndexRow(
              section: section,
              onTap: () => Navigator.of(context).push(
                CupertinoPageRoute<void>(
                  builder: (_) => LibrarySectionPage(section: section),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _LibraryIndexRow extends StatelessWidget {
  const _LibraryIndexRow({required this.section, required this.onTap});

  final LibrarySection section;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: AppColors.backgroundDepth2,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.borderDepth1),
        ),
        child: Row(
          children: [
            _sectionIcon(),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: _sectionLabels()),
            const Icon(
              CupertinoIcons.chevron_right,
              size: 16,
              color: AppColors.textColor4,
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionIcon() {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: AppColors.accentPrimary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Icon(section.icon, size: 18, color: AppColors.accentPrimary),
    );
  }

  Widget _sectionLabels() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          section.label,
          style: AppTypography.body.copyWith(
            color: AppColors.textColor1,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          section.subtitle,
          style: AppTypography.caption.copyWith(color: AppColors.textColor4),
        ),
      ],
    );
  }
}

class LibrarySectionPage extends ConsumerWidget {
  const LibrarySectionPage({super.key, required this.section});

  final LibrarySection section;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.backgroundDepth1,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: AppColors.backgroundDepth1,
        border: const Border(bottom: BorderSide(color: AppColors.borderDepth1)),
        middle: Text(section.label, style: AppTypography.subtitle),
        trailing: section.canAdd
            ? CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => _onAdd(context, ref),
                child: const Icon(
                  CupertinoIcons.add,
                  color: AppColors.accentPrimary,
                ),
              )
            : null,
      ),
      child: SafeArea(child: _sectionBody(context, ref)),
    );
  }

  Widget _sectionBody(BuildContext context, WidgetRef ref) {
    return switch (section.id) {
      'goals' => const GoalsTab(),
      'background' => const BackgroundTab(),
      'exercises' => ExercisesTab(
        onGenerateAllPressed: () =>
            ref.read(bulkBenefitsControllerProvider.notifier).generateAll(),
      ),
      'templates' => TemplatesTab(
        onAddPressed: () => _showNewTemplateSheet(context),
      ),
      'influences' => const InfluencesTab(),
      'locations' => const LocationsTab(),
      _ => const SizedBox.shrink(),
    };
  }

  void _onAdd(BuildContext context, WidgetRef ref) {
    switch (section.id) {
      case 'goals':
        _showAddGoalSheet(context, ref);
      case 'background':
        _showAddNoteSheet(context, ref);
      case 'templates':
        _showNewTemplateSheet(context);
      case 'influences':
        showCupertinoModalPopup<void>(
          context: context,
          builder: (_) => const InfluenceFormSheet(),
        );
      case 'locations':
        showCupertinoModalPopup<void>(
          context: context,
          builder: (_) => const LocationFormSheet(),
        );
    }
  }

  void _showAddGoalSheet(BuildContext context, WidgetRef ref) {
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

  void _showAddNoteSheet(BuildContext context, WidgetRef ref) {
    final goals = ref.read(goalsStreamProvider).value ?? [];
    final notesNotifier = ref.read(backgroundNotesControllerProvider.notifier);
    showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetContext) => NoteFormSheet(
        availableGoals: goals,
        onSave: (content, category, goalId) {
          notesNotifier.addNote(
            content: content,
            category: category,
            goalId: goalId,
          );
          Navigator.of(sheetContext).pop();
        },
      ),
    );
  }

  void _showNewTemplateSheet(BuildContext context) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (_) => const _NewTemplateSheet(),
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
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: AppColors.backgroundDepth2,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      child: SafeArea(top: false, child: _sheetScrollContent(context)),
    );
  }

  Widget _sheetScrollContent(BuildContext context) {
    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
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
