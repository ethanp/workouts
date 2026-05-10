import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:workouts/services/repositories/templates/template_repository_powersync.dart';

part 'template_version_provider.g.dart';

@riverpod
class TemplateVersionController extends _$TemplateVersionController {
  @override
  Future<TemplateVersionStatus> build() async {
    final repository = ref.watch(templateRepositoryPowerSyncProvider);
    final templates = await repository.fetchTemplates();
    final currentVersion = TemplateRepositoryPowerSync.currentTemplateVersion;

    if (templates.isEmpty) {
      return TemplateVersionStatus(
        currentTemplateVersion: currentVersion,
        installed: null,
        needsUpdate: true,
      );
    }

    return TemplateVersionStatus(
      currentTemplateVersion: currentVersion,
      installed: currentVersion,
      needsUpdate: false,
    );
  }

  Future<void> reseed() async {
    state = const AsyncValue.loading();
    final repository = ref.read(templateRepositoryPowerSyncProvider);
    await repository.reseedTemplates();
    ref.invalidateSelf();
  }
}

class TemplateVersionStatus {
  const TemplateVersionStatus({
    required this.currentTemplateVersion,
    required this.installed,
    required this.needsUpdate,
  });

  final int currentTemplateVersion;
  final int? installed;
  final bool needsUpdate;
}
