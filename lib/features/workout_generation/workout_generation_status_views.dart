import 'package:flutter/cupertino.dart';
import 'package:workouts/theme/app_theme.dart';

class WorkoutGenerationPreparingView extends StatelessWidget {
  const WorkoutGenerationPreparingView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Preparing...', style: AppTypography.body));
  }
}

class WorkoutGenerationStreamingView extends StatefulWidget {
  const WorkoutGenerationStreamingView({super.key, required this.partialText});

  final String partialText;

  @override
  State<WorkoutGenerationStreamingView> createState() =>
      _WorkoutGenerationStreamingViewState();
}

class _WorkoutGenerationStreamingViewState
    extends State<WorkoutGenerationStreamingView> {
  final _scrollController = ScrollController();

  @override
  void didUpdateWidget(WorkoutGenerationStreamingView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.partialText.length > oldWidget.partialText.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 50),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.partialText.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            CupertinoActivityIndicator(radius: 20),
            SizedBox(height: AppSpacing.lg),
            Text('Thinking about your training...', style: AppTypography.body),
          ],
        ),
      );
    }

    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Text(
          widget.partialText,
          style: AppTypography.body.copyWith(
            color: AppColors.textColor2,
            fontFamily: 'Menlo',
            fontSize: 12,
            height: 1.5,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        const CupertinoActivityIndicator(radius: 8),
      ],
    );
  }
}
