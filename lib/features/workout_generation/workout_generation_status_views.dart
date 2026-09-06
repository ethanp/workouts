import 'package:ethan_ui/ethan_ui.dart';
import 'package:flutter/material.dart';

class const WorkoutGenerationPreparingView() extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(child: Text('Preparing...', style: EText.body.medium));
  }
}

class const WorkoutGenerationStreamingView({required final String partialText})
    extends StatefulWidget {
  @override
  State<WorkoutGenerationStreamingView> createState() =>
      _WorkoutGenerationStreamingViewState();
}

class _WorkoutGenerationStreamingViewState()
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
          children: [
            const SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            const SizedBox(height: ELayout.spaceLg),
            Text('Thinking about your training...', style: EText.body.medium),
          ],
        ),
      );
    }

    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.all(ELayout.spaceLg),
      children: [
        Text(
          widget.partialText,
          style: EText.body.medium.copyWith(
            color: EColors.textSecondary,
            fontFamily: 'Menlo',
            fontSize: 12,
            height: 1.5,
          ),
        ),
        const SizedBox(height: ELayout.spaceMd),
        const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ],
    );
  }
}
