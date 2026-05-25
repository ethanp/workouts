import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'unit_system_provider.g.dart';

enum UnitSystem { imperial, metric }

// Overridden with the loaded SharedPreferences instance in main() before runApp.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError();
});

const _kUnitSystemKey = 'unit_system';

@Riverpod(keepAlive: true)
class UnitSystemNotifier extends _$UnitSystemNotifier {
  @override
  UnitSystem build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final storedUnitSystemName = prefs.getString(_kUnitSystemKey);
    return UnitSystem.values.firstWhere(
      (unitSystem) => unitSystem.name == storedUnitSystemName,
      orElse: () => UnitSystem.imperial,
    );
  }

  Future<void> setUnitSystem(UnitSystem system) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(_kUnitSystemKey, system.name);
    state = system;
  }
}
