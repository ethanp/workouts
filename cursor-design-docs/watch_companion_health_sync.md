## Watch Companion + Health Sync Design

### Objectives
- Capture live heart rate and workout metrics from an Apple Watch companion app.
- Sync session data and biometrics into the phone app’s session engine in near real time.
- Persist completed workouts to HealthKit so that Strava ingests them through the user’s existing Health sync.
- Preserve offline-first behavior: workouts remain usable without connectivity and reconcile once available.

### Scope
- iPhone app remains Flutter; watchOS companion built with SwiftUI + WatchConnectivity.
- Heart rate capture limited to workouts started from the phone (no autonomous watch sessions unless technically required for HR streaming).
- HealthKit write permissions limited to workout, heart rate, and energy samples.
- Strava sync relies on Health app integration (no direct Strava API).
- Out of scope: Android wearable support, non-heart-rate biometrics, live Strava push status, cloud sync integrations.

### Assumptions
- Users grant the phone app HealthKit read/write permissions and enable Strava ↔︎ Health sync.
- Existing session model already stores timestamps per set/block and total session duration.
- Local Drift schema changes are acceptable with proper migration handling.
- Watch and phone stay paired; we can require watchOS 10+ for HealthKit improvements.
- Deployment target: iOS 18.6.2 (or newer) and paired watchOS companion matching current hardware baseline.
- We do not estimate energy expenditure beyond data supplied by HealthKit.

### User Journeys
- Start session on iPhone → tap "Connect Watch" banner → watch auto-opens active session → heart rate timeline displayed on both devices → upon completion session summary shows average/max HR and pushes workout to Health.
- Open phone while session running in background → status banner shows "Workout running on watch" with pause/resume controls synced across devices.
- If connectivity drops mid-session, watch keeps logging HR locally and backfills when reconnected.

### High-Level Architecture
- **Watch Session Engine**: SwiftUI app using `HKWorkoutSession` + `HKLiveWorkoutBuilder` for heart rate streaming, storing samples in-memory and in a lightweight watch-only `WorkoutCacheStore` (CoreData or JSON).
- **Connectivity Layer**: `WatchConnectivitySessionManager` exchanging structured messages (`WorkoutControlMessage`, `HeartRatePayload`) via `WCSession`. Pigeon-generated codecs provide shared schema between Swift and Flutter.
- **Phone Bridge**: iOS host app exposes a `HeartRateChannel` to Flutter via MethodChannel/Pigeon, forwarding connectivity updates into Riverpod notifiers.
- **Flutter Session Layer**: `ActiveSessionNotifier` extended to merge heart rate samples, track watch connection state, and manage pause/resume commands.
- **Health Sync Service**: `HealthKitWorkoutExporter` composes workouts from session + HR data and writes to HealthKit on completion, queued via existing local job when offline.

### Implementation Guidelines
- **HealthKit permissions (iOS host)**: Request heart rate, active energy, and workout write access via `HKHealthStore().requestAuthorization` during onboarding. Defer HealthKit writes until authorization succeeds and cache the result in `healthKitPermissionProvider` to avoid redundant prompts.
- **Workout session configuration (watchOS)**: Build an `HKWorkoutConfiguration` with `activityType = .functionalStrengthTraining` (or nearest match) and `locationType = .indoor`. Set `HKLiveWorkoutBuilder`'s `dataSource` to `HKLiveWorkoutDataSource(healthStore: configuration:)` so HealthKit handles sensor calibration.
- **Extended runtime and background delivery**: Start a `WKExtendedRuntimeSession` alongside the workout to keep the app alive, and call `HKHealthStore().enableBackgroundDelivery` for heart rate samples to cover temporary connectivity loss.
- **WatchConnectivity resilience**: Activate a singleton `WCSession` early in both apps. Use `sendMessageData` when `isReachable`, fallback to `transferUserInfo` for guaranteed delivery, and coalesce heart rate batches (≤ 30 seconds) to respect payload limits.
- **Message schema generation**: Use Pigeon to generate Swift/Dart codecs for `WorkoutControlMessage`, `HeartRatePayload`, and `HealthExportCommand` to keep message handling type-safe and synchronized.
- **State restoration**: Persist watch-side samples in `WorkoutCacheStore` using timestamps as the primary key. On reconnect, send any unsynced samples and include the latest `HKQueryAnchor` so the phone can detect duplicates.
- **Flutter bridge pattern**: Surface native updates through an `EventChannel` (`heart_rate_stream`) for streaming samples and a `MethodChannel` for commands (pause/resume, delete exports). Ensure handlers switch back to the main isolate before touching Riverpod state.

### Data Flow
1. Phone starts session → sends `start(workoutId, templateId)` to watch.
2. Watch configures `HKWorkoutSession` + `HKLiveWorkoutBuilder`, assigns the session + builder delegates, calls `beginCollection(withStart:)`, then streams heart rate samples every 5s, batching into ≤30s envelopes for transport.
3. Watch sends `HeartRatePayload { timestamp, bpm, energyKCal, source }` via `sendMessageData` when reachable, otherwise queues with `transferUserInfo` and retries once reachability resumes.
4. Phone bridge pushes samples into `HeartRateBufferNotifier` (`@riverpod`); the notifier writes to Drift `heart_rate_samples` linked by `sessionLocalId`, deduplicates using `HKQueryAnchor` values, and publishes UI updates for the timeline chart.
5. On pause/resume commands, phone and watch coordinate via dedicated messages ensuring `HKWorkoutBuilder` state sync and confirming with haptic feedback; both sides update local state before acknowledging to avoid race conditions.
6. Completion triggers watch to end session, final metrics sent, phone persists session summary, enqueues HealthKit export job; once successful, mark `healthExportStatus = exported`.

### Data Model Updates
- Store the latest `HKQueryAnchor` per session in Drift (e.g., `heartRateAnchor` column) so catch-up queries know which samples remain to be pulled from the watch cache.
- Persist watch battery level snapshots if provided; surface them in the UI status chip for proactive low-power messaging.
- `heart_rate_samples` Drift table: `id`, `session_id`, `timestamp`, `bpm`, `energy_kcal`, `source`, `synced_at`.
- Extend `sessions` table with `average_heart_rate`, `max_heart_rate`, `total_energy_kcal`, `health_export_status`, `health_exported_at`.
- Freezed models updated with `@Default(HealthExportStatus.pending)` to ease migrations.
- New `HeartRateSample` Freezed class with JSON support for local persistence and analytics.

### Provider & Service Additions
- `@riverpod` `heartRateStreamProvider` exposing combined live + persisted samples for charts.
- `watchConnectivityProvider` managing `WCSession` lifecycle and forwarding commands.
- `healthKitPermissionProvider` caching authorization status and prompting UI modals.
- `healthExportQueueNotifier` scheduling HealthKit writes and invalidating on success/failure.

### Flutter ↔︎ Native Integration
- Generate Pigeon interfaces under `ios/Runner/Pigeon/` and `lib/pigeon/` with build scripts so CI verifies schema drift.
- iOS host registers a `HeartRateEventStreamHandler` that buffers events until Flutter attaches, preventing data loss during cold starts.
- Expose a `HealthKitCommandApi` via Pigeon for operations like `requestAuthorization()`, `startWorkout()`, `endWorkout()`, and `deleteWorkouts(uuids)`; keep implementations under `ios/Runner/HealthKit/` for cohesion.
- On the Flutter side, wrap Pigeon APIs in Riverpod providers (`healthKitPermissionProvider`, `watchConnectivityProvider`) to centralize side effects and enable mocking in tests.

### UI & UX Changes (iPhone)
- Today screen banner: watch connection state (connected, connecting, unavailable) with clear call-to-action using `CupertinoButton.filled()` white text.
- Active Session screen: add HR timeline chart aligned to workout blocks using `AppColors.backgroundDepth2` and `textColor1`/`textColor3`; status chips for connection + watch battery.
- Pause overlay: ensure pause/resume buttons sync with watch state and remain dismissible.
- Session summary: heart rate stats, Health sync status banner (pending/exported/failed) with retry option.

### Settings → Health Data UX
- Present permission status (authorized/limited/denied) with copy explaining how to adjust in the Health app.
- Primary `CupertinoButton.filled()` titled "Remove exported workouts from Health" triggers a confirmation sheet summarizing how many exports remain.
- On confirm, call the Pigeon `deleteWorkouts` method, show a progress HUD, then surface success/failure banners tied to `healthExportQueueNotifier` state.
- Provide contextual help linking to Apple’s Health data privacy docs to reassure users about control over their data.

### Watch UI
- Minimal SwiftUI flow: start prompt → active workout view (elapsed time, heart rate, pause/resume) styled with native watchOS components.
- Provide pause/resume + end buttons with haptic feedback; show connection errors with actionable retry.

### HealthKit Export Workflow
1. On session completion, enqueue export job with session + HR samples.
2. `HealthKitWorkoutExporter` checks `HKHealthStore.authorizationStatus`, builds `HKWorkout` with `HKQuantitySample` heart rate data (using `HKWorkoutBuilder.finishWorkout`) and any `HKQuantitySampleType.activeEnergyBurned` values returned by the builder.
3. Write to HealthKit on a background queue; on success, store `workoutUUID` + associated `HKSample` UUIDs for clean deletion; on failure, capture `NSError.code` for user messaging and set status `failed` with retry affordances.
4. Strava import happens automatically later; optionally poll HealthKit to confirm workout presence for status update.
5. Surface a persistent control under Settings → Health Data that uses the stored `workoutUUID` to remove exported workouts from HealthKit, wrapping calls in `HKHealthStore.delete` and refreshing Riverpod state afterward.

### Migrations & Plumbing
- Increment Drift `schemaVersion`; add migration to create `heart_rate_samples` and new session columns with defaults.
- Update repositories and notifiers to include HR data in local persistence and HealthKit export pipelines.
- Ensure migrations handle legacy sessions by backfilling default `healthExportStatus` and null-safe metrics.

### Testing Strategy
- Unit: mock `WatchConnectivitySessionManager`, verify message parsing, ensure `ActiveSessionNotifier` merges samples correctly.
- Widget: Active Session HR chart rendering with fake data, banners for export states.
- Integration: iOS host tests with `XCTest` for HealthKit export (use HKHealthStore mock), watch unit tests for workout lifecycle.
- Manual QA: end-to-end run with TestFlight including Health permissions and Strava sync validation.

### Rollout Plan
1. **Foundation**: add Drift schema, models, providers, placeholder UI with simulated HR data.
2. **Connectivity**: implement `WCSession` bridge with mocked watch companion for dev builds.
3. **Watch App**: build SwiftUI watch extension, integrate live HR capture, ensure pause/resume parity.
4. **HealthKit Export**: request permissions, implement exporter, add retry UX.
5. **Beta Validation**: internal flight verifying Strava ingestion, HealthKit workflow, battery impact.
6. **Public Release**: enable watch banner by default, publish App Store update with watchOS companion.

### Risks & Mitigations
- HealthKit permission denial → show fallbacks and gracefully disable HR-based features.
- Connectivity drop → watch buffers samples locally and sends on reconnect before export.
- Battery drain on watch → throttle sample batching (30s), end session when phone commands stop.
- Migration complexity → default values + `@Default` ensure backward compatibility.
- HR streaming limitations → revisit standalone watch sessions only if required for reliable data capture.

### Open Questions
- None currently.

### Implementation Progress
- Flutter scaffolding: heart rate timeline card, Riverpod bridge, and Health settings screen in place with stub MethodChannel integration.
- iOS host: HealthKit method channel + event channel registered in AppDelegate with placeholders for heart rate streaming and WatchConnectivity activation.
- watchOS: SwiftUI shell with workout session manager capable of starting HKWorkoutSession and broadcasting heart rate locally (pending integration into Xcode project).
- Testing: Provider and widget coverage added to guard HeartKit permission handling, heart rate buffering, and Health data removal UX.

### Reference Notes
- Apple Developer: Building a Workout App for Apple Watch — https://developer.apple.com/documentation/healthkit/workouts_and_activity_rings/building_a_workout_app_for_apple_watch
- Apple Developer: Stream live health data to your app — https://developer.apple.com/documentation/healthkit/stream_live_health_data_to_your_app
- Apple Developer: Keep your app connected to your watch — https://developer.apple.com/documentation/watchconnectivity
- Apple Developer: Extending runtime for watchOS apps — https://developer.apple.com/documentation/watchkit/wkextendedruntimesession
- Pigeon (Flutter) code generation — https://pub.dev/packages/pigeon

