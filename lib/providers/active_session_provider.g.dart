// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'active_session_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$activeSessionNotifierHash() =>
    r'c199e3d8dc4f1cf1e8f5aeeaa6c6c14fb436cfbc';

/// See also [ActiveSessionNotifier].
@ProviderFor(ActiveSessionNotifier)
final activeSessionNotifierProvider =
    AutoDisposeAsyncNotifierProvider<ActiveSessionNotifier, Session?>.internal(
      ActiveSessionNotifier.new,
      name: r'activeSessionNotifierProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$activeSessionNotifierHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$ActiveSessionNotifier = AutoDisposeAsyncNotifier<Session?>;
String _$sessionUIVisibilityNotifierHash() =>
    r'539b1b14757e40cc1d329a999fd028f1926c99b1';

/// See also [SessionUIVisibilityNotifier].
@ProviderFor(SessionUIVisibilityNotifier)
final sessionUIVisibilityNotifierProvider =
    AutoDisposeNotifierProvider<SessionUIVisibilityNotifier, bool>.internal(
      SessionUIVisibilityNotifier.new,
      name: r'sessionUIVisibilityNotifierProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$sessionUIVisibilityNotifierHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$SessionUIVisibilityNotifier = AutoDisposeNotifier<bool>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
