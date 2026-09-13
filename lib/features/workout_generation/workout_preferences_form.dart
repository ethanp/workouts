import 'package:ethan_ui/ethan_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workouts/features/goals/goals_provider.dart';
import 'package:workouts/models/training_location.dart';
import 'package:workouts/features/library/locations_provider.dart';
import 'package:workouts/services/context_builder.dart';
import 'package:workouts/widgets/connection_gated_widget.dart';

const _durationPresets = [5, 10, 15, 30, 45, 60];

class const WorkoutPreferencesForm({
  required final ValueChanged<WorkoutPreferences> onPreferencesSubmitted,
}) extends ConsumerStatefulWidget {
  @override
  ConsumerState<WorkoutPreferencesForm> createState() =>
      _WorkoutPreferencesFormState();
}

class _WorkoutPreferencesFormState()
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
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.all(ELayout.spaceLg).withOverlaidTabBar(context),
      children: [
        _sectionLabel('Duration'),
        _durationChips(),
        const SizedBox(height: ELayout.spaceXl),
        _sectionLabel('Focus Areas'),
        _goalChips(),
        const SizedBox(height: ELayout.spaceXl),
        _sectionLabel('Location'),
        _locationSelector(),
        const SizedBox(height: ELayout.spaceXl),
        _sectionLabel('Notes'),
        _notesField(),
        const SizedBox(height: ELayout.spaceXl),
        _generateButton(),
        const SizedBox(height: ELayout.spaceLg),
      ],
    );
  }

  Widget _sectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: ELayout.spaceSm),
      child: Text(
        label,
        style: EText.caption.copyWith(
          color: EColors.textTertiary,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _durationChips() {
    return Wrap(
      spacing: ELayout.spaceSm,
      runSpacing: ELayout.spaceSm,
      children: _durationPresets.map((minutes) {
        final isSelected = _selectedDuration == minutes;
        return GestureDetector(
          onTap: () =>
              setState(() => _selectedDuration = isSelected ? null : minutes),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(
              horizontal: ELayout.spaceMd,
              vertical: ELayout.spaceSm,
            ),
            decoration: BoxDecoration(
              color: isSelected
                  ? EColors.accent
                  : EColors.backgroundLift,
              borderRadius: BorderRadius.circular(ELayout.radiusMd),
              border: Border.all(
                color: isSelected
                    ? EColors.accent
                    : EColors.border,
              ),
            ),
            child: Text(
              '$minutes min',
              style: EText.body.medium.copyWith(
                color: isSelected
                    ? Colors.white
                    : EColors.textSecondary,
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
            style: EText.body.medium.copyWith(color: EColors.textTertiary),
          );
        }
        return Wrap(
          spacing: ELayout.spaceSm,
          runSpacing: ELayout.spaceSm,
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
                  horizontal: ELayout.spaceMd,
                  vertical: ELayout.spaceSm,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? EColors.accent
                      : EColors.backgroundLift,
                  borderRadius: BorderRadius.circular(ELayout.radiusMd),
                  border: Border.all(
                    color: isSelected
                        ? EColors.accent
                        : EColors.border,
                  ),
                ),
                child: Text(
                  goal.title,
                  style: EText.body.medium.copyWith(
                    color: isSelected
                        ? Colors.white
                        : EColors.textSecondary,
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
      loading: () => const CircularProgressIndicator(),
      error: (_, _) => Text(
        'Could not load goals.',
        style: EText.body.medium.copyWith(color: EColors.textTertiary),
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
            style: EText.body.medium.copyWith(color: EColors.textTertiary),
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
                margin: const EdgeInsets.only(bottom: ELayout.spaceSm),
                padding: const EdgeInsets.all(ELayout.spaceMd),
                decoration: BoxDecoration(
                  color: isSelected
                      ? EColors.accent.withValues(alpha: 0.12)
                      : EColors.backgroundLift,
                  borderRadius: BorderRadius.circular(ELayout.radiusMd),
                  border: Border.all(
                    color: isSelected
                        ? EColors.accent
                        : EColors.border,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isSelected
                          ? Icons.check_circle
                          : Icons.circle_outlined,
                      size: 20,
                      color: isSelected
                          ? EColors.accent
                          : EColors.textTertiary,
                    ),
                    const SizedBox(width: ELayout.spaceMd),
                    Expanded(child: _locationInfo(location)),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
      loading: () => const CircularProgressIndicator(),
      error: (_, _) => Text(
        'Could not load locations.',
        style: EText.body.medium.copyWith(color: EColors.textTertiary),
      ),
    );
  }

  Widget _locationInfo(TrainingLocation location) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          location.name,
          style: EText.body.medium.copyWith(
            color: EColors.textPrimary,
            fontWeight: FontWeight.w500,
          ),
        ),
        if (location.equipment.isNotEmpty)
          Text(
            location.equipment,
            style: EText.caption.copyWith(color: EColors.textTertiary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
      ],
    );
  }

  Widget _notesField() {
    return TextField(
      controller: _notesController,
      decoration: const InputDecoration(
        hintText: 'Anything else? e.g., "I\'m feeling tired", "skip legs"',
      ),
      maxLines: 3,
    );
  }

  Widget _generateButton() {
    return ConnectionGatedWidget(
      child: SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: _submit,
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.auto_awesome, size: 18),
              SizedBox(width: ELayout.spaceSm),
              Text(
                'Generate',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
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

    widget.onPreferencesSubmitted(
      WorkoutPreferences(
        durationMinutes: _selectedDuration,
        focusGoals: focusGoals,
        location: selectedLocation,
        notes: notes.isEmpty ? null : notes,
      ),
    );
  }
}
