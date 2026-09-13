import 'package:ethan_ui/ethan_ui.dart';
import 'package:flutter/material.dart';
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
import 'package:workouts/features/library/hr_zones_reference_tile.dart';
import 'package:workouts/features/library/influences_tab.dart';
import 'package:workouts/features/library/locations_tab.dart';
import 'package:workouts/features/library/templates_tab.dart';
import 'package:workouts/features/workout_generation/options/workout_options_sheet.dart';
import 'package:workouts/features/workout_generation/workout_generation_provider.dart';
import 'package:workouts/models/workout_template.dart';
import 'package:workouts/services/repositories/templates/template_repository_powersync.dart';
import 'package:workouts/widgets/connection_gated_widget.dart';
import 'package:workouts/widgets/sync_status_icon.dart';

/// One Library destination: label, icon, and whether the section page shows +.
class const LibrarySection({
  required final String id,
  required final String label,
  required final IconData icon,
  required final String subtitle,
  required final bool canAdd,
});

const librarySections = <LibrarySection>[
  LibrarySection(
    id: 'templates',
    label: 'Templates',
    icon: Icons.view_list,
    subtitle: 'Saved workouts you can start',
    canAdd: true,
  ),
  LibrarySection(
    id: 'goals',
    label: 'Goals',
    icon: Icons.flag,
    subtitle: 'Training priorities and targets',
    canAdd: true,
  ),
  LibrarySection(
    id: 'background',
    label: 'Background',
    icon: Icons.description,
    subtitle: 'Context for AI coaching',
    canAdd: true,
  ),
  LibrarySection(
    id: 'exercises',
    label: 'Exercises',
    icon: Icons.grid_view,
    subtitle: 'Movements used in templates',
    canAdd: false,
  ),
  LibrarySection(
    id: 'influences',
    label: 'Influences',
    icon: Icons.lightbulb,
    subtitle: 'Coaches and training philosophies',
    canAdd: true,
  ),
  LibrarySection(
    id: 'locations',
    label: 'Locations',
    icon: Icons.location_on,
    subtitle: 'Gyms and places you train',
    canAdd: true,
  ),
];

class const LibraryScreen() extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: const EAppHeader(
        title: 'Library',
        automaticallyImplyLeading: false,
        leading: SyncStatusIcon(),
      ),
      body: SafeArea(bottom: false, child: _libraryScroll(context)),
    );
  }

  Widget _libraryScroll(BuildContext context) {
    return CustomScrollView(
      slivers: [_heartRateZonesSliver(), _sectionsSliver(context)],
    );
  }

  Widget _heartRateZonesSliver() {
    return const SliverPadding(
      padding: EdgeInsets.fromLTRB(
        ELayout.spaceLg,
        ELayout.spaceMd,
        ELayout.spaceLg,
        ELayout.spaceMd,
      ),
      sliver: SliverToBoxAdapter(child: HrZonesReferenceTile()),
    );
  }

  Widget _sectionsSliver(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(
        ELayout.spaceLg,
        0,
        ELayout.spaceLg,
        ELayout.spaceMd,
      ).withOverlaidTabBar(context),
      sliver: SliverList.separated(
        itemCount: librarySections.length,
        separatorBuilder: (_, _) => const SizedBox(height: ELayout.spaceSm),
        itemBuilder: (context, sectionIndex) {
          final section = librarySections[sectionIndex];
          return _LibraryIndexRow(
            section: section,
            onActivated: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => LibrarySectionPage(section: section),
              ),
            ),
          );
        },
      ),
    );
  }
}

class const _LibraryIndexRow({
  required final LibrarySection section,
  required final VoidCallback onActivated,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onActivated,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: ELayout.spaceMd,
          vertical: ELayout.spaceMd,
        ),
        decoration: BoxDecoration(
          color: EColors.backgroundLift,
          borderRadius: BorderRadius.circular(ELayout.radiusMd),
          border: Border.all(color: EColors.border),
        ),
        child: Row(
          children: [
            _sectionIcon(),
            const SizedBox(width: ELayout.spaceMd),
            Expanded(child: _sectionLabels()),
            const Icon(Icons.chevron_right, size: 16, color: EColors.textMuted),
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
        color: EColors.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(ELayout.radiusSm),
      ),
      child: Icon(section.icon, size: 18, color: EColors.accent),
    );
  }

  Widget _sectionLabels() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          section.label,
          style: EText.body.medium.copyWith(
            color: EColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          section.subtitle,
          style: EText.caption.copyWith(color: EColors.textMuted),
        ),
      ],
    );
  }
}

class const LibrarySectionPage({required final LibrarySection section})
    extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: EAppHeader(
        title: section.label,
        actions: [
          if (section.id == 'templates')
            ConnectionGatedWidget(
              child: IconButton(
                tooltip: 'Generate workout',
                onPressed: () => _showGenerateWorkout(context, ref),
                icon: const Icon(Icons.auto_awesome),
              ),
            ),
          if (section.canAdd)
            IconButton(
              tooltip: 'Add',
              onPressed: () => _showAddSheetForSection(context, ref),
              icon: const Icon(Icons.add),
            ),
        ],
      ),
      body: SafeArea(bottom: false, child: _sectionBody(context, ref)),
    );
  }

  Widget _sectionBody(BuildContext context, WidgetRef ref) {
    return switch (section.id) {
      'goals' => const GoalsTab(),
      'background' => const BackgroundTab(),
      'exercises' => ExercisesTab(
        onGenerateAllBenefits: () =>
            ref.read(bulkBenefitsControllerProvider.notifier).generateAll(),
      ),
      'templates' => TemplatesTab(
        onTemplateAddRequested: () => _showNewTemplateSheet(context),
      ),
      'influences' => const InfluencesTab(),
      'locations' => const LocationsTab(),
      _ => const SizedBox.shrink(),
    };
  }

  void _showAddSheetForSection(BuildContext context, WidgetRef ref) {
    switch (section.id) {
      case 'goals':
        _showAddGoalSheet(context, ref);
      case 'background':
        _showAddNoteSheet(context, ref);
      case 'templates':
        _showNewTemplateSheet(context);
      case 'influences':
        showModalBottomSheet<void>(
          context: context,
          builder: (_) => const InfluenceFormSheet(),
        );
      case 'locations':
        showModalBottomSheet<void>(
          context: context,
          builder: (_) => const LocationFormSheet(),
        );
    }
  }

  void _showAddGoalSheet(BuildContext context, WidgetRef ref) {
    final goalsNotifier = ref.read(goalsControllerProvider.notifier);
    showModalBottomSheet<void>(
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
    showModalBottomSheet<void>(
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
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => const _NewTemplateSheet(),
    );
  }

  Future<void> _showGenerateWorkout(BuildContext context, WidgetRef ref) async {
    final option = await WorkoutOptionsSheet.show(context);
    if (option == null) return;
    await ref.read(workoutGenerationProvider.notifier).select(option);
  }
}

class const _NewTemplateSheet() extends ConsumerStatefulWidget {
  @override
  ConsumerState<_NewTemplateSheet> createState() => _NewTemplateSheetState();
}

class _NewTemplateSheetState() extends ConsumerState<_NewTemplateSheet> {
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
        color: EColors.backgroundLift,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(ELayout.radiusXl),
        ),
      ),
      child: SafeArea(top: false, child: _sheetScrollContent(context)),
    );
  }

  Widget _sheetScrollContent(BuildContext context) {
    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.all(ELayout.spaceLg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _dragHandle(),
          const SizedBox(height: ELayout.spaceLg),
          Text('New Template', style: EText.title, textAlign: TextAlign.center),
          const SizedBox(height: ELayout.spaceXl),
          _nameFormField(),
          const SizedBox(height: ELayout.spaceLg),
          _goalFormField(),
          const SizedBox(height: ELayout.spaceXl),
          _createButton(context),
          const SizedBox(height: ELayout.spaceMd),
          _cancelButton(context),
        ],
      ),
    );
  }

  Widget _nameFormField() {
    return _formField(
      label: 'Name',
      child: TextField(
        controller: _nameController,
        onChanged: (_) => setState(() {}),
        style: EText.body.medium.copyWith(color: EColors.textPrimary),
        decoration: const InputDecoration(hintText: 'e.g., Upper Body Push'),
      ),
    );
  }

  Widget _goalFormField() {
    return _formField(
      label: 'Goal (optional)',
      child: TextField(
        controller: _goalController,
        maxLines: 2,
        style: EText.body.medium.copyWith(color: EColors.textPrimary),
        decoration: const InputDecoration(
          hintText: 'e.g., Build pressing strength',
        ),
      ),
    );
  }

  Widget _createButton(BuildContext context) {
    return FilledButton(
      onPressed: _nameController.text.trim().isEmpty
          ? null
          : () => _create(context),
      child: const Text('Create Template'),
    );
  }

  Widget _cancelButton(BuildContext context) {
    return TextButton(
      onPressed: () => Navigator.of(context).pop(),
      child: Text('Cancel', style: TextStyle(color: EColors.textTertiary)),
    );
  }

  Widget _dragHandle() => Center(
    child: Container(
      width: 36,
      height: 4,
      decoration: BoxDecoration(
        color: EColors.borderStrong,
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
          style: EText.caption.copyWith(
            color: EColors.textTertiary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: ELayout.spaceSm),
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
