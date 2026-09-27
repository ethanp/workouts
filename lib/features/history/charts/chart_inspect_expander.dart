import 'package:ethan_ui/ethan_ui.dart';
import 'package:flutter/material.dart';

class const ChartInspectExpander({
  required final bool isExpanded,
  required final VoidCallback onToggle,
  final Widget? detail,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _toggle(),
        if (isExpanded && detail != null) ...[
          const SizedBox(height: ELayout.spaceXs),
          detail!,
        ],
      ],
    );
  }

  Widget _toggle() {
    return GestureDetector(
      onTap: onToggle,
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isExpanded ? Icons.expand_less : Icons.expand_more,
            size: 14,
            color: EColors.textMuted,
          ),
          const SizedBox(width: 2),
          Text(
            'Inspect',
            style: EText.caption.copyWith(color: EColors.textMuted),
          ),
        ],
      ),
    );
  }
}
