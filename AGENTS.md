## Workouts Agent Guidelines

- **Scope**: These rules govern automated assistant changes in the Workouts repository.

- **Assistant behavior**:
  - Do not add comments to generated code.
  - Keep responses brief and scannable; include only essential context.
  - Do not run `flutter run` commands - let the user test apps in their own terminal for faster hot reload.

- **Dart/Flutter preferences**:
  - Prefer getters over `getX()` method forms for model attributes.
  - Use switch expressions when returning values where practical.
  - Inline trivial `buildX` helpers that only wrap a constructor.
  - Use `forEach` for controller disposal when results are unused.

- **Widget construction**:
  - Replace static factory helpers with widgets instantiated via constructors.
  - Avoid using `super.key` unless the key is consumed.
  - Omit underscore prefixes for widget helper methods; reserve them for non-widget helpers.

- **UI styling**:
  - Follow iOS design language using Cupertino components and `AppColors`, `AppTypography`, `AppSpacing`, `AppRadius`.
  - Keep unselected controls styled with white text on grey backgrounds.
  - Name colors with numeric depth scales: `backgroundDepth1-5`, `borderDepth1-5`, `textColor1-4`.

- **UX patterns**:
  - Use `CupertinoButton.filled()` for primary actions with explicit white text styling.
  - Avoid confusing button states ("blue blobs") - always ensure text is clearly visible.
  - Implement dismissible overlays for persistent background processes (sessions, timers).
  - Add status banners for background state awareness (active sessions, sync status).
  - Remove features that don't provide clear user value (profile pages with app info).
  - Make interactive elements obviously tappable with clear visual feedback.
  - Provide pause/resume for long-running activities to accommodate real-world interruptions.

- **Quality bar**:
  - Keep output lint-clean, type-safe, and formatted with `dart format` conventions.
  - Avoid duplicated logic; prefer DRY, functional, idiomatic Dart.

- **Architecture**:
  - Use Riverpod with `@riverpod` codegen (`riverpod_annotation`) for all providers and notifiers.
  - Split logic into models, services/DAOs, providers, screens, and widgets mirroring Clean Architecture boundaries.
  - Enforce SOLID principles and keep methods under 50 lines.

- **State management**:
  - Use `ref.watch(...).when(...)` for async UI and `ref.read` for imperative calls.
  - Invalidate providers after mutations via `ref.invalidate(...)` or `ref.invalidateSelf()`.
  - Separate UI visibility state from data state (e.g., `SessionUIVisibilityNotifier` vs `ActiveSessionNotifier`).
  - Use `Timer.periodic()` for real-time updates (elapsed time, countdowns) with proper disposal.

- **Data architecture**:
  - Prefer local-first design with SQLite/Drift for immediate responsiveness.
  - Only add remote sync/auth when absolutely necessary for user value.
  - Repository pattern: local database operations through dedicated DAO layers.

- **Models & serialization**:
  - Generate models with Freezed and `json_serializable`, including `toJson`/`fromJson` methods.
  - Prefer immutable data classes with explicit `required` fields.

- **Navigation & screens**:
  - Build screens with `ConsumerWidget`/`ConsumerStatefulWidget` as needed; avoid global state.
  - Provide consistent Cupertino navigation and tab flows matching native expectations.

- **Session management patterns**:
  - Support pause/resume functionality for long-running processes (workouts, timers).
  - Implement dismissible interfaces that allow background state persistence.
  - Use notification banners to maintain awareness of background processes.
  - Track pause duration separately to provide accurate elapsed time calculations.

- **Testing**:
  - Add widget and service tests under `test/` using deterministic data and mocks for external services.

- **Error handling**:
  - Present user-friendly error states in UI with clear recovery actions.
  - Use defensive programming for null checks and state validation.

- **Feature philosophy**:
  - Ruthlessly remove features that don't provide clear user value.
  - Prefer simple, focused apps over feature-heavy ones.
  - Question every dependency - remove unused packages immediately.
  - Cost-conscious: avoid expensive services when local solutions work better.

- **Operations**:
  - Deployment scripts must raise exceptions on failure instead of returning bools.
  - Keep secrets in `.env` files; exclude them from Git via `.gitignore`.

- **Performance**:
  - Favor `const` constructors and computed providers to limit rebuilds.
  - Avoid heavy computation inside `build`; offload to providers or callbacks.

- **Documentation**:
  - Place reference material in `references/` and design docs under `cursor-design-docs/`.

- **Drift conventions**:
  - Name table classes with a `Table` suffix (e.g., `WorkoutTemplatesTable`).
  - Generated row data classes should use the `Row` suffix (e.g., `WorkoutTemplateRow`).
  - Increment `schemaVersion` when adding new columns to existing tables.
  - Use `@Default()` values in Freezed models for new fields to avoid migration complexity.

- **Workout app patterns**:
  - Session state: active/paused/completed with accurate timing that excludes pause duration.
  - Dismissible session UI: allow navigation while maintaining background session state.
  - Two-tab navigation: "Today" (current workout) and "History" (completed sessions).
  - Local-only design: no authentication, no remote dependencies, immediate app startup.

