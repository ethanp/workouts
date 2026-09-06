import 'package:flutter/material.dart';
import 'package:ethan_ui/ethan_ui.dart';

class const WatchConnectionIndicator({required final bool isConnected})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final color = isConnected ? EColors.success : EColors.textTertiary;
    final background = isConnected
        ? EColors.success.withValues(alpha: 0.15)
        : EColors.surface;
    final icon = isConnected
        ? Icons.check_circle
        : Icons.warning;
    final label = isConnected ? 'Watch connected' : 'Watch offline';

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: ELayout.spaceSm,
        vertical: ELayout.spaceXs,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(ELayout.radiusSm),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: ELayout.spaceXs),
          Text(label, style: EText.caption.copyWith(color: color)),
        ],
      ),
    );
  }
}
