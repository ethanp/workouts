import 'package:flutter/cupertino.dart';
import 'package:workouts/theme/app_theme.dart';

class ExpandableCues extends StatefulWidget {
  const ExpandableCues({
    super.key,
    required this.cues,
    this.isInitiallyExpanded = true,
  });

  final List<String> cues;
  final bool isInitiallyExpanded;

  @override
  State<ExpandableCues> createState() => _ExpandableCuesState();
}

class _ExpandableCuesState extends State<ExpandableCues> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.isInitiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.cues.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: Size.zero,
          onPressed: () {
            setState(() {
              _isExpanded = !_isExpanded;
            });
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _isExpanded
                    ? CupertinoIcons.chevron_down
                    : CupertinoIcons.chevron_right,
                size: 16,
                color: AppColors.textColor3,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                _isExpanded
                    ? 'Form Cues'
                    : 'Form Cues (${widget.cues.length})',
                style: AppTypography.caption.copyWith(
                  color: AppColors.textColor3,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        if (_isExpanded) ...[
          const SizedBox(height: AppSpacing.xs),
          ...widget.cues.map((cue) => Padding(
                padding: const EdgeInsets.only(
                  bottom: AppSpacing.xs,
                  left: AppSpacing.md,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.textColor4,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        cue,
                        style: AppTypography.body.copyWith(
                          color: AppColors.textColor3,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ],
    );
  }
}

