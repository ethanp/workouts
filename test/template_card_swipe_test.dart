import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:workouts/models/workout_template.dart';
import 'package:workouts/features/library/templates_provider.dart';
import 'package:workouts/services/repositories/template_repository_powersync.dart';
import 'package:workouts/features/library/templates_tab.dart';

class _MockTemplateRepository extends Mock
    implements TemplateRepositoryPowerSync {}

const _fakeTemplate = WorkoutTemplate(
  id: 'test-template-id',
  name: 'Test Routine',
  goal: 'Testing',
  blocks: [],
);

// Mirrors the real app: CupertinoTabScaffold → CupertinoTabView →
// CupertinoPageScaffold → AnimatedSwitcher → TemplatesTab
Widget _buildFullContext({required _MockTemplateRepository mockRepository}) {
  return ProviderScope(
    overrides: [
      workoutTemplatesProvider.overrideWith(
        (_) => Stream.value([_fakeTemplate]),
      ),
      templateRepositoryPowerSyncProvider.overrideWith(
        (_) => mockRepository,
      ),
    ],
    child: CupertinoApp(
      home: CupertinoTabScaffold(
        tabBar: CupertinoTabBar(
          items: const [
            BottomNavigationBarItem(icon: Icon(CupertinoIcons.home), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(CupertinoIcons.book), label: 'Library'),
          ],
          currentIndex: 1,
        ),
        tabBuilder: (_, index) => CupertinoTabView(
          builder: (_) => CupertinoPageScaffold(
            child: SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: TemplatesTab(
                        key: const ValueKey('templates'),
                        onAddPressed: _noop,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  late _MockTemplateRepository mockRepository;

  setUp(() {
    mockRepository = _MockTemplateRepository();
    when(() => mockRepository.deleteTemplate(any())).thenAnswer((_) async {});
  });

  testWidgets('shows confirm dialog when card is swiped left — full app context', (tester) async {
    await tester.pumpWidget(_buildFullContext(mockRepository: mockRepository));
    await tester.pumpAndSettle();

    expect(find.text('Test Routine'), findsOneWidget);

    await tester.fling(
      find.text('Test Routine'),
      const Offset(-300, 0),
      800,
    );
    await tester.pumpAndSettle();

    expect(find.text('Delete Routine?'), findsOneWidget);
  });

  testWidgets('calls deleteTemplate after tapping Delete — full app context', (tester) async {
    await tester.pumpWidget(_buildFullContext(mockRepository: mockRepository));
    await tester.pumpAndSettle();

    await tester.fling(
      find.text('Test Routine'),
      const Offset(-300, 0),
      800,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    verify(() => mockRepository.deleteTemplate('test-template-id')).called(1);
  });

  testWidgets('does not delete when Cancel is tapped — full app context', (tester) async {
    await tester.pumpWidget(_buildFullContext(mockRepository: mockRepository));
    await tester.pumpAndSettle();

    await tester.fling(
      find.text('Test Routine'),
      const Offset(-300, 0),
      800,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    verifyNever(() => mockRepository.deleteTemplate(any()));
  });
}

void _noop() {}
