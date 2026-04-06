import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workouts/features/goals/goals_provider.dart';
import 'package:workouts/models/training_location.dart';
import 'package:workouts/features/library/locations_provider.dart';
import 'package:workouts/services/context_builder.dart';
import 'package:workouts/theme/app_theme.dart';

const _durationPresets = [5, 10, 15, 30, 45, 60];

class WorkoutPreferencesForm extends ConsumerStatefulWidget {
  const WorkoutPreferencesForm({super.key, required this.onSubmit});

  final ValueChanged<WorkoutPreferences> onSubmit;

  @override
  ConsumerState<WorkoutPreferencesForm> createState() =>
      _WorkoutPreferencesFormState();
}

class _WorkoutPreferencesFormState
    extends ConsumerState<WorkoutPreferencesForm> {
  int? _selectedDuration;
  final Set<String> _selectedGoalIds = {};
  String? _selectedLocationId;
  final _notesController = TextEditingController();

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        _sectionLabel('Duration'),
        _durationChips(),
        const SizedBox(height: AppSpacing.xl),
        _sectionLabel('Focus Areas'),
        _goalChips(),
        const SizedBox(height: AppSpacing.xl),
        _sectionLabel('Location'),
        _locationSelector(),
        const SizedBox(height: AppSpacing.xl),
        _sectionLabel('Notes'),
        _notesField(),
        const SizedBox(height: AppSpacing.xl),
        _generateButton(),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }

  Widget _sectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(
        label,
        style: AppTypography.caption.copyWith(
          color: AppColors.textColor3,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _durationChips() {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: _durationPresets.map((minutes) {
        final isSelected = _selectedDuration == minutes;
        return GestureDetector(
          onTap: () =>
              setState(() => _selectedDuration = isSelected ? null : minutes),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.accentPrimary
                  : AppColors.backgroundDepth2,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: isSelected
                    ? AppColors.accentPrimary
                    : AppColors.borderDepth1,
              ),
            ),
            child: Text(
              '$minutes min',
              style: AppTypography.body.copyWith(
                color: isSelected
                    ? CupertinoColors.white
                    : AppColors.textColor2,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _goalChips() {
    final goalsAsync = ref.watch(activeGoalsStreamProvider);

    return goalsAsync.when(
      data: (activeGoals) {
        if (activeGoals.isEmpty) {
          return Text(
            'No active goals. Add goals in the Library.',
            style: AppTypography.body.copyWith(color: AppColors.textColor3),
          );
        }
        return Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: activeGoals.map((goal) {
            final isSelected = _selectedGoalIds.contains(goal.id);
            return GestureDetector(
              onTap: () => setState(() {
                if (isSelected) {
                  _selectedGoalIds.remove(goal.id);
                } else {
                  _selectedGoalIds.add(goal.id);
                }
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.accentPrimary
                      : AppColors.backgroundDepth2,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.accentPrimary
                        : AppColors.borderDepth1,
                  ),
                ),
                child: Text(
                  goal.title,
                  style: AppTypography.body.copyWith(
                    color: isSelected
                        ? CupertinoColors.white
                        : AppColors.textColor2,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
      loading: () => const CupertinoActivityIndicator(),
      error: (_, __) => Text(
        'Could not load goals.',
        style: AppTypography.body.copyWith(color: AppColors.textColor3),
      ),
    );
  }

  Widget _locationSelector() {
    final locationsAsync = ref.watch(locationsProvider);

    return locationsAsync.when(
      data: (savedLocations) {
        if (savedLocations.isEmpty) {
          return Text(
            'No locations saved. Add locations in the Library.',
            style: AppTypography.body.copyWith(color: AppColors.textColor3),
          );
        }
        return Column(
          children: savedLocations.map((location) {
            final isSelected = _selectedLocationId == location.id;
            return GestureDetector(
              onTap: () => setState(() {
                _selectedLocationId = isSelected ? null : location.id;
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.accentPrimary.withValues(alpha: 0.12)
                      : AppColors.backgroundDepth2,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.accentPrimary
                        : AppColors.borderDepth1,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isSelected
                          ? CupertinoIcons.checkmark_circle_fill
                          : CupertinoIcons.circle,
                      size: 20,
                      color: isSelected
                          ? AppColors.accentPrimary
                          : AppColors.textColor3,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(child: _locationInfo(location)),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
      loading: () => const CupertinoActivityIndicator(),
      error: (_, __) => Text(
        'Could not load locations.',
        style: AppTypography.body.copyWith(color: AppColors.textColor3),
      ),
    );
  }

  Widget _locationInfo(TrainingLocation location) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          location.name,
          style: AppTypography.body.copyWith(
            color: AppColors.textColor1,
            fontWeight: FontWeight.w500,
          ),
        ),
        if (location.equipment.isNotEmpty)
          Text(
            location.equipment,
            style:
                AppTypography.caption.copyWith(color: AppColors.textColor3),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
      ],
    );
  }

  Widget _notesField() {
    return CupertinoTextField(
      controller: _notesController,
      placeholder: 'Anything else? e.g., "I\'m feeling tired", "skip legs"',
      placeholderStyle:
          AppTypography.body.copyWith(color: AppColors.textColor4),
      style: AppTypography.body.copyWith(color: AppColors.textColor1),
      padding: const EdgeInsets.all(AppSpacing.md),
      maxLines: 3,
      decoration: BoxDecoration(
        color: AppColors.backgroundDepth2,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.borderDepth1),
      ),
    );
  }

  Widget _generateButton() {
    return SizedBox(
      width: double.infinity,
      child: CupertinoButton.filled(
        onPressed: _submit,
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(CupertinoIcons.sparkles, size: 18),
            SizedBox(width: AppSpacing.sm),
            Text(
              'Generate',
              style: TextStyle(
                color: CupertinoColors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _submit() {
    final goalsAsync = ref.read(activeGoalsStreamProvider);
    final locationsAsync = ref.read(locationsProvider);

    final allGoals = goalsAsync.value ?? [];
    final focusGoals = allGoals
        .where((goal) => _selectedGoalIds.contains(goal.id))
        .toList();

    final allLocations = locationsAsync.value ?? [];
    TrainingLocation? selectedLocation;
    if (_selectedLocationId != null) {
      selectedLocation = allLocations
          .where((location) => location.id == _selectedLocationId)
          .firstOrNull;
    }

    final notes = _notesController.text.trim();

    widget.onSubmit(
      WorkoutPreferences(
        durationMinutes: _selectedDuration,
        focusGoals: focusGoals,
        location: selectedLocation,
        notes: notes.isEmpty ? null : notes,
      ),
    );
  }
}
