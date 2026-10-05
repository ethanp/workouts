import 'package:ethan_ui/ethan_ui.dart';
import 'package:flutter/material.dart';
import 'package:workouts/models/cardio_type.dart';
import 'package:workouts/theme/cardio_type_palette.dart';

class const ActivityTypeFilterStrip({
  required final List<CardioType> activityTypes,
  required final CardioType? selectedActivityType,
  required final ValueChanged<CardioType?> onActivityTypeSelected,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(
        ELayout.spaceLg,
        0,
        ELayout.spaceLg,
        ELayout.spaceSm,
      ),
      child: Row(
        children: [
          _ActivityTypeChip(
            label: 'All',
            isSelected: selectedActivityType == null,
            color: EColors.accent,
            onActivated: () => onActivityTypeSelected(null),
          ),
          for (final activityType in activityTypes)
            _ActivityTypeChip(
              label: activityType.displayName,
              isSelected: selectedActivityType == activityType,
              color: activityType.color,
              onActivated: () => onActivityTypeSelected(activityType),
            ),
        ],
      ),
    );
  }
}

class const _ActivityTypeChip({
  required final String label,
  required final bool isSelected,
  required final Color color,
  required final VoidCallback onActivated,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final Color background = isSelected ? color : EColors.surface;
    return Padding(
      padding: const EdgeInsets.only(right: ELayout.spaceSm),
      child: InkWell(
        onTap: onActivated,
        borderRadius: BorderRadius.circular(ELayout.radiusMd),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: ELayout.spaceMd,
            vertical: ELayout.spaceXs,
          ),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(ELayout.radiusMd),
          ),
          child: Text(
            label,
            style: EText.caption.copyWith(
              color: _labelColor(background),
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Color _labelColor(Color background) {
    if (!isSelected) return EColors.textPrimary;
    if (background.computeLuminance() > 0.55) return const Color(0xFF1C1C1E);
    return Colors.white;
  }
}
