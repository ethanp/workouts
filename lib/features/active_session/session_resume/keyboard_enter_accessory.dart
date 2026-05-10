import 'package:flutter/cupertino.dart';
import 'package:workouts/theme/app_theme.dart';

class KeyboardEnterAccessory extends StatelessWidget {
  const KeyboardEnterAccessory({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Positioned(
    left: 0,
    right: 0,
    bottom: 0,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.backgroundDepth2,
        border: Border(top: BorderSide(color: AppColors.borderDepth1)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 44,
          child: Row(
            children: [
              const Spacer(),
              CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                onPressed: onPressed,
                child: Text(
                  'Enter',
                  style: AppTypography.button.copyWith(
                    color: AppColors.accentPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
