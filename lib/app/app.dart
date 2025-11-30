import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workouts/app/router.dart';
import 'package:workouts/providers/app_bootstrap_provider.dart';
import 'package:workouts/providers/sync_provider.dart';
import 'package:workouts/theme/app_theme.dart';

class WorkoutsApp extends ConsumerStatefulWidget {
  const WorkoutsApp();

  @override
  ConsumerState<WorkoutsApp> createState() => _WorkoutsAppState();
}

class _WorkoutsAppState extends ConsumerState<WorkoutsApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(syncNotifierProvider.notifier).startListening();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        ref.read(syncNotifierProvider.notifier).startListening();
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        ref.read(syncNotifierProvider.notifier).stopListening();
    }
  }

  @override
  Widget build(BuildContext context) {
    final initialization = ref.watch(appBootstrapProvider);

    return CupertinoApp(
      title: 'Workouts',
      theme: buildAppTheme(),
      debugShowCheckedModeBanner: false,
      home: initialization.when(
        data: (_) => const AppRouter(),
        error: (error, stack) => CupertinoPageScaffold(
          navigationBar: const CupertinoNavigationBar(middle: Text('Error')),
          child: Center(child: Text('$error')),
        ),
        loading: () => const CupertinoPageScaffold(
          child: Center(child: CupertinoActivityIndicator()),
        ),
      ),
    );
  }
}
