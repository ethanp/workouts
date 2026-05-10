import 'dart:async';

/// App-wide channel for surfacing user-visible errors.
///
/// Anything pushed here is rendered by [ErrorBanner] as a copyable, emailable
/// toast (with recent log context attached on email). Use this whenever the
/// app catches an exception that the user should know about — operations that
/// silently fail are worse than a visible error.
///
/// Push from `catch` blocks (typically with a short prefix identifying the
/// operation) and from the global error handlers wired up in `main.dart`:
///
/// ```dart
/// try {
///   await goalsRepository.saveGoal(goal);
/// } catch (error) {
///   errorBus.add('Save goal: $error');
///   rethrow;
/// }
/// ```
///
/// Keep messages short and human-readable; the full stack trace is captured
/// separately via `ELogger` and included in the email body.
final errorBus = StreamController<String>.broadcast();
