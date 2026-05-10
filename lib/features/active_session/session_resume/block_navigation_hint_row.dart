import 'package:flutter/cupertino.dart';
import 'package:workouts/theme/app_theme.dart';

class BlockNavigationHintRow extends StatelessWidget {
  const BlockNavigationHintRow({
    super.key,
    required this.onPrevious,
    required this.onNext,
  });

  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(
        'Swipe or tap arrows to navigate blocks',
        style: AppTypography.caption.copyWith(color: AppColors.textColor4),
      ),
      Row(
        children: [
          _navigationButton(
            icon: CupertinoIcons.chevron_left,
            onPressed: onPrevious,
          ),
          _navigationButton(
            icon: CupertinoIcons.chevron_right,
            onPressed: onNext,
          ),
        ],
      ),
    ],
  );

  Widget _navigationButton({
    required IconData icon,
    required VoidCallback? onPressed,
  }) => CupertinoButton(
    padding: const EdgeInsets.all(AppSpacing.xs),
    onPressed: onPressed,
    child: Icon(
      icon,
      color: onPressed == null ? AppColors.textColor4 : AppColors.textColor2,
      size: 20,
    ),
  );
}
