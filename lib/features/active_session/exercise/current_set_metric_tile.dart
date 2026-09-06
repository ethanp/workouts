import 'package:flutter/material.dart';
import 'package:ethan_ui/ethan_ui.dart';

class const CurrentSetMetricTile({
  required final String label,
  required final TextEditingController controller,
  required final FocusNode focusNode,
  required final String placeholder,
  required final TextInputType keyboardType,
  required final ValueChanged<String> onChanged,
  required final VoidCallback onDecrement,
  required final VoidCallback onIncrement,
  final String? suffix,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(ELayout.spaceSm),
    decoration: _tileDecoration,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _metricLabel(),
        const SizedBox(height: ELayout.spaceXs),
        _inputRow(),
      ],
    ),
  );

  BoxDecoration get _tileDecoration => BoxDecoration(
    color: focusNode.hasFocus ? EColors.surfaceRaised : EColors.backgroundLift,
    borderRadius: BorderRadius.circular(ELayout.radiusSm),
    border: Border.all(
      color: focusNode.hasFocus
          ? EColors.accent.withValues(alpha: 0.55)
          : EColors.borderStrong,
    ),
  );

  Widget _metricLabel() => Text(
    label,
    style: EText.caption.copyWith(
      color: EColors.textTertiary,
      fontWeight: FontWeight.w600,
    ),
  );

  Widget _inputRow() => Row(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      _stepperButton('-', onDecrement),
      const SizedBox(width: ELayout.spaceXs),
      Expanded(child: _inputField()),
      if (suffix != null) ...[
        const SizedBox(width: ELayout.spaceXs),
        _metricSuffix(suffix!),
      ],
      const SizedBox(width: ELayout.spaceXs),
      _stepperButton('+', onIncrement),
    ],
  );

  Widget _inputField() => TextField(
    controller: controller,
    focusNode: focusNode,
    onChanged: onChanged,
    onSubmitted: (_) => focusNode.unfocus(),
    onTapOutside: (_) => focusNode.unfocus(),
    keyboardType: keyboardType,
    textInputAction: TextInputAction.done,
    textAlign: TextAlign.center,
    style: EText.title.copyWith(
      color: EColors.textPrimary,
      fontWeight: FontWeight.w700,
    ),
    decoration: InputDecoration(
      hintText: placeholder,
      hintStyle: EText.title.copyWith(
        color: EColors.textMuted,
        fontWeight: FontWeight.w600,
      ),
      isDense: true,
      border: InputBorder.none,
      contentPadding: EdgeInsets.zero,
    ),
  );

  Widget _stepperButton(String text, VoidCallback onPressed) => FilledButton(
    style: FilledButton.styleFrom(
      backgroundColor: EColors.surfaceRaised,
      foregroundColor: EColors.textPrimary,
      minimumSize: const Size(34, 34),
      padding: EdgeInsets.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ELayout.radiusSm),
      ),
    ),
    onPressed: onPressed,
    child: Text(
      text,
      style: EText.body.medium.copyWith(
        color: EColors.textPrimary,
        fontWeight: FontWeight.w700,
      ),
    ),
  );

  Widget _metricSuffix(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 2),
    child: Text(
      text,
      style: EText.caption.copyWith(
        color: EColors.textMuted,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}
