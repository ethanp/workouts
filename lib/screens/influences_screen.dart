import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workouts/models/training_influence.dart';
import 'package:workouts/providers/influences_provider.dart';
import 'package:workouts/services/repositories/influences_repository_powersync.dart';
import 'package:workouts/theme/app_theme.dart';

class InfluencesScreen extends ConsumerWidget {
  const InfluencesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final influencesAsync = ref.watch(influencesProvider);

    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Training Influences'),
      ),
      child: SafeArea(
        child: influencesAsync.when(
          data: (influences) => influences.isEmpty
              ? const _EmptyView()
              : _InfluencesList(influences: influences),
          loading: () => const Center(child: CupertinoActivityIndicator()),
          error: (error, _) => Center(
            child: Text(
              'Unable to load influences: $error',
              style: AppTypography.body,
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Text(
          'No training influences available.',
          style: AppTypography.body.copyWith(color: AppColors.textColor3),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _InfluencesList extends StatelessWidget {
  const _InfluencesList({required this.influences});

  final List<TrainingInfluence> influences;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          margin: const EdgeInsets.only(bottom: AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.backgroundDepth2,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.borderDepth1),
          ),
          child: Row(
            children: [
              Icon(
                CupertinoIcons.lightbulb,
                color: AppColors.textColor2,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Select coaches and philosophies to incorporate their training principles into your generated workouts.',
                  style: AppTypography.body.copyWith(color: AppColors.textColor2),
                ),
              ),
            ],
          ),
        ),
        ...influences.map((influence) => _InfluenceCard(influence: influence)),
      ],
    );
  }
}

class _InfluenceCard extends ConsumerStatefulWidget {
  const _InfluenceCard({required this.influence});

  final TrainingInfluence influence;

  @override
  ConsumerState<_InfluenceCard> createState() => _InfluenceCardState();
}

class _InfluenceCardState extends ConsumerState<_InfluenceCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final influence = widget.influence;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.backgroundDepth2,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: influence.isActive
              ? AppColors.accentPrimary.withOpacity(0.5)
              : AppColors.borderDepth1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with toggle
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _isExpanded = !_isExpanded),
                    behavior: HitTestBehavior.opaque,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(influence.name, style: AppTypography.subtitle),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          influence.description,
                          style: AppTypography.body.copyWith(
                            color: AppColors.textColor2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                CupertinoSwitch(
                  value: influence.isActive,
                  onChanged: (value) => _toggleInfluence(value),
                  activeTrackColor: AppColors.accentPrimary,
                ),
              ],
            ),
          ),

          // Expand/collapse indicator
          GestureDetector(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Icon(
                    _isExpanded
                        ? CupertinoIcons.chevron_up
                        : CupertinoIcons.chevron_down,
                    size: 16,
                    color: AppColors.textColor3,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    _isExpanded ? 'Hide principles' : 'Show principles',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textColor3,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Expanded content - principles
          if (_isExpanded) ...[
            Container(height: 1, color: AppColors.borderDepth1),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Key Principles',
                    style: AppTypography.body.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textColor1,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  ...influence.principles.map(
                    (principle) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '•',
                            style: AppTypography.body.copyWith(
                              color: AppColors.accentPrimary,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              principle,
                              style: AppTypography.body.copyWith(
                                color: AppColors.textColor2,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _toggleInfluence(bool isActive) async {
    await ref
        .read(influencesRepositoryPowerSyncProvider)
        .toggleInfluence(widget.influence.id, isActive);
  }
}
