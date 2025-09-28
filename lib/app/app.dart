import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workouts/app/router.dart';
import 'package:workouts/providers/app_bootstrap_provider.dart';
import 'package:workouts/theme/app_theme.dart';

class WorkoutsApp extends ConsumerWidget {
  const WorkoutsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
