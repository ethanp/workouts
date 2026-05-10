import 'package:flutter/cupertino.dart';
import 'package:workouts/theme/app_theme.dart';

class CurrentSetMetricTile extends StatelessWidget {
  const CurrentSetMetricTile({
    super.key,
    required this.label,
    required this.controller,
    required this.focusNode,
    required this.placeholder,
    required this.keyboardType,
    required this.onChanged,
    required this.onDecrement,
    required this.onIncrement,
    this.suffix,
  });

  final String label;
  final TextEditingController controller;
  final FocusNode focusNode;
  final String placeholder;
  final TextInputType keyboardType;
  final ValueChanged<String> onChanged;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;
  final String? suffix;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: _tileDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _metricLabel(),
          const SizedBox(height: AppSpacing.xs),
          _inputRow(),
        ],
      ),
    );
  }

  BoxDecoration get _tileDecoration {
    return BoxDecoration(
      color: focusNode.hasFocus
          ? AppColors.backgroundDepth4
          : AppColors.backgroundDepth2,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      border: Border.all(
        color: focusNode.hasFocus
            ? AppColors.accentPrimary.withValues(alpha: 0.55)
            : AppColors.borderDepth2,
      ),
    );
  }

  Widget _metricLabel() {
    return Text(
      label,
      style: AppTypography.caption.copyWith(
        color: AppColors.textColor3,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _inputRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _stepperButton('-', onDecrement),
        const SizedBox(width: AppSpacing.xs),
        Expanded(child: _inputField()),
        if (suffix != null) ...[
          const SizedBox(width: AppSpacing.xs),
          _metricSuffix(suffix!),
        ],
        const SizedBox(width: AppSpacing.xs),
        _stepperButton('+', onIncrement),
      ],
    );
  }

  Widget _inputField() {
    return CupertinoTextField(
      controller: controller,
      focusNode: focusNode,
      onChanged: onChanged,
      onSubmitted: (_) => focusNode.unfocus(),
      onTapOutside: (_) => focusNode.unfocus(),
      keyboardType: keyboardType,
      textInputAction: TextInputAction.done,
      placeholder: placeholder,
      placeholderStyle: AppTypography.title.copyWith(
        color: AppColors.textColor4,
        fontWeight: FontWeight.w600,
      ),
      style: AppTypography.title.copyWith(
        color: AppColors.textColor1,
        fontWeight: FontWeight.w700,
      ),
      padding: EdgeInsets.zero,
      decoration: const BoxDecoration(color: Color(0x00000000)),
      textAlign: TextAlign.center,
    );
  }

  Widget _stepperButton(String text, VoidCallback onPressed) {
    return CupertinoButton(
      minimumSize: const Size(34, 34),
      padding: EdgeInsets.zero,
      color: AppColors.backgroundDepth4,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      onPressed: onPressed,
      child: Text(
        text,
        style: AppTypography.body.copyWith(
          color: AppColors.textColor1,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _metricSuffix(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Text(
        text,
        style: AppTypography.caption.copyWith(
          color: AppColors.textColor4,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
