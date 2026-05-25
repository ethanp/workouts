# Workouts

Personal workout tracker with local-first sync.

## Stack

- **Flutter** (iOS) with Cupertino widgets
- **Riverpod** for state management
- **PowerSync** for local-first SQLite with real-time sync
- **Postgres** + **PostgREST** backend (managed in separate `infra` repo)
- **Docker compose** (also in separate `infra` repo)

## Setup

1. Copy `.env.example` to `.env` and fill in real values. Only `.env`
   is loaded at startup (see `main.dart`) and bundled as a Flutter asset.

2. Run `flutter pub get`

3. Run `flutter pub run build_runner build` (for Freezed/Riverpod codegen)

## Features

- **Today**: View scheduled workouts, start sessions
- **Goals & Context**: Track fitness goals and background notes (injuries, preferences, equipment)
- **History**: Review past workout sessions
- **Sync**: Real-time sync indicator in navigation bar
