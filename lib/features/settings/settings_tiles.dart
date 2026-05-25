import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workouts/features/library/template_version_provider.dart';
import 'package:workouts/theme/app_theme.dart';

class TemplateVersionTile extends StatelessWidget {
  const TemplateVersionTile({
    super.key,
    required this.versionAsync,
    required this.ref,
  });

  final AsyncValue<TemplateVersionStatus> versionAsync;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.backgroundDepth2,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.borderDepth1),
      ),
      child: versionAsync.when(
        data: (status) => _dataContent(context, status),
        loading: _loadingContent,
        error: (error, _) => _errorContent(error),
      ),
    );
  }

  Widget _dataContent(
    BuildContext context,
    TemplateVersionStatus status,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Workout Templates', style: AppTypography.subtitle),
      const SizedBox(height: AppSpacing.xs),
      Text(
        status.installed == null
            ? 'Not initialized (version ${status.currentTemplateVersion})'
            : 'Version ${status.installed} installed (current: ${status.currentTemplateVersion})',
        style: AppTypography.body.copyWith(
          color: status.needsUpdate ? AppColors.warning : AppColors.textColor3,
        ),
      ),
      if (status.needsUpdate) ...[
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Templates need to be updated to access new features and fixes.',
          style: AppTypography.caption.copyWith(color: AppColors.textColor4),
        ),
        const SizedBox(height: AppSpacing.md),
        CupertinoButton.filled(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          onPressed: () => _confirmReseed(context),
          child: const Text(
            'Update Templates',
            style: TextStyle(
              color: CupertinoColors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
      const SizedBox(height: AppSpacing.sm),
      CupertinoButton(
        padding: EdgeInsets.zero,
        minimumSize: const Size(0, 0),
        onPressed: () => _confirmReseed(context),
        child: Text(
          'Reset to default templates',
          style: AppTypography.caption.copyWith(color: AppColors.accentPrimary),
        ),
      ),
    ],
  );

  Widget _loadingContent() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Workout Templates', style: AppTypography.subtitle),
      const SizedBox(height: AppSpacing.xs),
      const CupertinoActivityIndicator(),
    ],
  );

  Widget _errorContent(Object error) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Workout Templates', style: AppTypography.subtitle),
      const SizedBox(height: AppSpacing.xs),
      Text(
        'Error: $error',
        style: AppTypography.body.copyWith(color: AppColors.error),
      ),
    ],
  );

  void _confirmReseed(BuildContext context) {
    final versionNotifier = ref.read(
      templateVersionControllerProvider.notifier,
    );
    showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetCtx) {
        return CupertinoActionSheet(
          title: const Text('Update Templates?'),
          message: const Text(
            'This will regenerate all workout templates with the latest version. Any active sessions will not be affected.',
          ),
          actions: [
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.of(sheetCtx, rootNavigator: true).pop();
                versionNotifier.reseed();
              },
              child: const Text('Update Templates'),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.of(sheetCtx, rootNavigator: true).pop(),
            child: const Text('Cancel'),
          ),
        );
      },
    );
  }
}

