import 'package:ethan_ui/ethan_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workouts/models/training_influence.dart';
import 'package:workouts/features/library/influences_provider.dart';

import 'influences/influence_card.dart';

class const InfluencesTab() extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final influencesAsync = ref.watch(influencesProvider);

    return influencesAsync.when(
      data: (influences) => influences.isEmpty
          ? const InfluencesEmptyView()
          : InfluencesList(influences: influences),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Text(
          'Unable to load influences: $error',
          style: EText.body.medium,
        ),
      ),
    );
  }
}

class const InfluencesEmptyView() extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(ELayout.spaceXl),
        child: Text(
          'No training influences available.',
          style: EText.body.medium.copyWith(color: EColors.textTertiary),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class const InfluencesList({required final List<TrainingInfluence> influences})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(ELayout.spaceLg).withOverlaidTabBar(context),
      children: [
        _explanationBanner(),
        ...influences.map((influence) => InfluenceCard(influence: influence)),
      ],
    );
  }

  Widget _explanationBanner() {
    return Container(
      padding: const EdgeInsets.all(ELayout.spaceMd),
      margin: const EdgeInsets.only(bottom: ELayout.spaceLg),
      decoration: BoxDecoration(
        color: EColors.backgroundLift,
        borderRadius: BorderRadius.circular(ELayout.radiusMd),
        border: Border.all(color: EColors.border),
      ),
      child: Row(
        children: [
          Icon(Icons.lightbulb_outline, color: EColors.textSecondary, size: 20),
          const SizedBox(width: ELayout.spaceSm),
          Expanded(
            child: Text(
              'Select coaches and philosophies to incorporate their '
              'training principles into your generated workouts.',
              style: EText.body.medium.copyWith(color: EColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
