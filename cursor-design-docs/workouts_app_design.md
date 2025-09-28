## Vision

- Deliver a professional iOS-first strength and mobility tracker focused on club, kettlebell, and animal flow programming.
- Provide guided active sessions that surface timers, cues, rest, and note-taking in a single flow.
- Persist every workout to Supabase with seamless offline resilience and sync once connectivity resumes.

## Personas & Use Cases

- **Solo athlete**: Wants a structured 60-minute guided session mirroring Strong, with progress memory and quick logging.
- **Coach**: Needs to review clients’ adherence and tweak prescriptions; requires historical reporting.
- **Athlete recovering from injury**: Tracks mobility gains, adds RPE and notes to adjust programming.

Primary flows:
- Start Today’s Session → follow blocks sequentially → capture weights, durations, notes → finish and sync.
- Browse history by calendar/list → inspect session metrics.
- Modify a template (e.g., adjust KB weight, swap move) → save personalized version.

## Functional Scope

- **Session Engine**: Drives the provided 60-minute “Club + KB Base” plan with optional custom variants.
- **Templates**: Store workout blueprint with blocks, exercises, prescriptions, default timing.
- **Tracking**: Log set data (weight, reps, duration, RPE, notes). Capture auto-timestamps for intervals.
- **Recovery & Breath**: Provide guided timers with cues (e.g., 4-4-4-4 box breathing).
- **History**: Summaries per session, block, exercise. Quick navigation to previous metrics.
- **Sync**: Full CRUD mirrored to Supabase with conflict resolution (last-write wins + audit trail).

Out of scope v1: social features, wearable integration, custom macro cycles, Android support.

## Non-Functional Requirements

- Cupertino aesthetic, dark theme base, accessible typography using `AppTypography` scale.
- SOLID/Clean Architecture, no function >50 LOC, DRY.
- Offline-first using local SQLite via `drift` (or `sqflite` helper) with queued mutations.
- Riverpod codegen for state; Freezed models; json_serializable for payloads.
- Unit, widget, integration coverage for critical flows; `flutter analyze` clean.

## Architecture Overview

- **Presentation**: Screens under `lib/screens`, smaller widgets under `lib/widgets`; Cupertino navigation with tab scaffold (Home, Sessions, History, Profile).
- **State**: Riverpod providers per bounded context (templates, active session, history, profile). Async providers for Supabase reads; notifiers for commands.
- **Domain Models**: Freezed classes in `lib/models` for WorkoutTemplate, WorkoutBlock, Exercise, SessionEntry, SetLog, BreathSegment.
- **Data Layer**:
  - `lib/services/local_database.dart` with drift schema for offline tables mirroring Supabase.
  - `lib/services/supabase_client.dart` wraps Supabase SDK and handles RLS policies.
  - Repository interfaces in `lib/services/repositories/` orchestrate local+remote operations.
- **Sync**: Background worker triggered on app foreground/refetch; uses `SyncQueue` table to buffer mutations. After successful push, entries marked complete.
- **Theming**: `lib/theme/app_theme.dart` exports color palette (backgroundDepth1-5, etc.), spacing, typography.

## Data Model (Core Tables)

### Supabase (Postgres)

- `users`
  - `id UUID PK`
  - `email TEXT`
  - `display_name TEXT`

- `workout_templates`
  - `id UUID PK`
  - `owner_id UUID FK -> users`
  - `name TEXT`
  - `goal TEXT`
  - `blocks JSONB` (array of block metadata with exercises)
  - `created_at TIMESTAMPTZ`
  - `updated_at TIMESTAMPTZ`

- `sessions`
  - `id UUID PK`
  - `owner_id UUID FK`
  - `template_id UUID FK`
  - `started_at TIMESTAMPTZ`
  - `completed_at TIMESTAMPTZ`
  - `duration_seconds INT`
  - `notes TEXT`
  - `feeling TEXT`

- `session_blocks`
  - `id UUID PK`
  - `session_id UUID FK`
  - `block_index INT`
  - `label TEXT`
  - `prescription JSONB` (time, reps, weight guidance)

- `set_logs`
  - `id UUID PK`
  - `session_block_id UUID FK`
  - `exercise_id UUID`
  - `set_index INT`
  - `weight_kg NUMERIC`
  - `reps INT`
  - `duration_seconds INT`
  - `rpe NUMERIC`
  - `notes TEXT`

- `breath_segments`
  - `id UUID PK`
  - `session_id UUID FK`
  - `pattern TEXT`
  - `target_seconds INT`
  - `actual_seconds INT`

Row Level Security: each table policy `owner_id = auth.uid()` for CRUD.

### Local SQLite (drift)

- Mirror tables with additional `sync_status ENUM('pending','synced','failed')`, `updated_at` timestamps.
- `sync_queue` table capturing operation type + payload for replay.

## Default Template Blueprint

The built-in “Kettlebell + Club Base” template contains ordered blocks:

1. **Warmup & Mobility (0:00–08:00)**
   - Club halos: 6/side (tempo focus)
   - Half-kneeling hip flexor stretch (club overhead): 30s/side
   - Cat–cow → thread needle: 5/side

2. **Animal Flow (08:00–20:00)**
   - Beast crawl hold → forward crawl: 3×20–30s
   - Crab reach: 3×5/side

3. **Strength A (20:00–30:00)**
   - Kettlebell RDL: 3×8
   - Club front shield cast: 3×6/side

4. **Strength B (30:00–40:00)**
   - Half-kneeling kettlebell press: 3×6/side
   - Kettlebell suitcase carry: 3×40s/side

5. **Mobility Focus (40:00–50:00)**
   - Goblet deep lunge hold: 2×30s/side
   - Club side bends (tall kneel): 2×6/side
   - Standing thoracic rotation with club: 8/side

6. **Cooldown & Breathwork (50:00–60:00)**
   - Supine 90/90 breathing: 2×5 breaths
   - Child’s pose with side reach: 45s/side
   - Box breathing 4-4-4-4: 2 minutes

Animal move reference glossary stored in `animal_movements` table for cues.

## Key Workflows

- **Start session**
  - Select template; default to today’s plan.
  - Pre-session summary shows required equipment, block overview, last metrics.
  - Tap “Begin”; Active Session screen enters block 1.

- **Active session UI**
  - Header timer with elapsed + block target.
  - Swipe horizontally to switch blocks; vertical scroll for exercises inside block.
  - Each exercise card lets user log sets or hold timer (for carries/holds).
  - Quick actions: +set, copy last weight, mark RPE, rest timer start.
  - Animal flow blocks present video cue thumbnails and start/stop timer.
  - Breathwork overlay for guided box breathing (animated circle + counts).

- **Completion**
  - Summary view: total duration, volume, perceived feeling (picker), notes field.
  - Persist session locally immediately, enqueue sync.

- **History**
  - Calendar on top (Cupertino date picker); list grouped by week below.
  - Detail shows block metrics, trend charts (volume, load, duration) per exercise.

- **Template editing** (MVP simple)
  - Duplicate default template; edit block order, rep schemes, rest hints.
  - Persist to Supabase and mark as user-specific.

## Providers

- `sessionTemplateProvider` (Future) → fetch templates for user.
- `activeSessionNotifier` → manages session lifecycle, set logging, timers.
- `historyProvider` (Future) → paginated session summaries.
- `sessionDetailProvider` (Future) → fetch block + set logs for a session.
- `authProvider` → Supabase auth state.
- `syncStatusProvider` → surfaces offline/online state.

Providers rely on repositories injected via `ProviderScope` overrides for testing.

## Services & Repositories

- `AuthService`: Supabase auth sign-in/out (Apple + email magic link), stores session.
- `TemplateRepository`: Sources templates prioritized local cache > remote; handles edits.
- `SessionRepository`: Creates sessions, logs sets, manages sync queue.
- `SyncService`: Timer-based job calling Supabase rest for pending operations.
- `SupabaseService`: thin wrapper over Supabase client with typed queries.
- `AnimalMovementService`: Supplies cues, benefits, technique notes.

## Offline & Sync Strategy

- Operations produce `SyncTask` entries (`operation`, `table`, `payload`, `localId`).
- `SyncService` polls connectivity (via `connectivity_plus`), pushes tasks in FIFO order.
- On success, marks task `synced`; on failure, logs reason and leaves for retry.
- Pull strategy: on login/foreground, fetch updated records via `updated_at > lastPull` per table.

## Navigation Map

1. `StartupScreen` → handles auth + data bootstrap.
2. `MainTabScreen`
   - Tab 1: `TodayScreen` (session summary, Begin button).
   - Tab 2: `ActiveSessionScreen` (accessible only when session running; else hidden).
   - Tab 3: `HistoryScreen`.
   - Tab 4: `ProfileScreen` (settings, equipment defaults, sign out).
3. Modal routes:
   - `SessionSummarySheet` (on complete).
   - `TemplateEditorSheet`.
   - `BreathOverlay` (full-screen).

## Testing Strategy

- **Unit**: Model serialization, repository behavior, sync queue logic, timer utilities.
- **Widget**: Active session interactions, template browsing, breath overlay.
- **Integration**: Session creation → logs → sync using Supabase emulator/smoke environment.
- CI pipeline: `flutter analyze`, `flutter test`, custom integration job (GitHub Actions).

## Analytics & Telemetry

- Client events logged via Supabase Functions or `postgrest` RPC: session start, completion, block skip, timer usage.
- Privacy: store only aggregated metrics; allow user opt-out in profile.

## Rollout Plan

1. Implement core architecture with default template and manual auth.
2. Add active session flow with timers and offline persistence.
3. Build history views + analytics.
4. Layer template editor and customization.
5. Add push notifications (reminders) in later release.

## Open Questions

- Need design for multi-template scheduling? (Backlog.)
- Should session auto-save incomplete progress? (Plan to auto-save every set; resume screen to be added.)
- Decision on Apple Health integration timeline? (Not V1.)

