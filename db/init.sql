-- Workouts Database Schema for PowerSync
-- This file creates the normalized schema for the Workouts app
-- All IDs are TEXT (client-generated UUIDs stored as strings) to match PowerSync

-- ============================================
-- FITNESS_GOALS TABLE (R1)
-- ============================================
CREATE TABLE fitness_goals (
    id TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    description TEXT DEFAULT '',
    category TEXT NOT NULL, -- strength, power, endurance, mobility, balance, coordination, quickness, physique, posture, rehabilitation, longevity, skill
    priority INTEGER NOT NULL DEFAULT 1, -- 1 = highest priority
    target_date TIMESTAMPTZ,
    status TEXT NOT NULL DEFAULT 'active', -- active, achieved, paused
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_fitness_goals_priority ON fitness_goals(priority);
CREATE INDEX idx_fitness_goals_status ON fitness_goals(status);
CREATE INDEX idx_fitness_goals_created_at ON fitness_goals(created_at DESC);

-- ============================================
-- BACKGROUND_NOTES TABLE (R2)
-- ============================================
CREATE TABLE background_notes (
    id TEXT PRIMARY KEY,
    goal_id TEXT REFERENCES fitness_goals(id) ON DELETE SET NULL,
    category TEXT NOT NULL,
    content TEXT NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT true,
    source TEXT NOT NULL DEFAULT 'user',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_background_notes_goal_id ON background_notes(goal_id);
CREATE INDEX idx_background_notes_category ON background_notes(category);
CREATE INDEX idx_background_notes_is_active ON background_notes(is_active);
CREATE INDEX idx_background_notes_created_at ON background_notes(created_at DESC);

-- ============================================
-- EXERCISES TABLE
-- ============================================
CREATE TABLE exercises (
    id TEXT PRIMARY KEY,
    name TEXT UNIQUE NOT NULL,
    modality TEXT NOT NULL, -- reps, timed, hold, mobility, breath
    equipment TEXT,
    set_metrics_style TEXT NOT NULL DEFAULT 'repsOnly', -- repsOnly, repsAndWeight, durationOnly, repsAndDuration
    cues TEXT, -- JSON array of cue strings
    benefits TEXT DEFAULT '[]', -- JSON array of {name, goalIds} objects
    is_unilateral BOOLEAN NOT NULL DEFAULT false, -- true for split squats, single-leg/single-arm work; runtime fans every planned set into per-side logged sets
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_exercises_name ON exercises(name);
CREATE INDEX idx_exercises_modality ON exercises(modality);

-- ============================================
-- WORKOUT_TEMPLATES TABLE
-- ============================================
CREATE TABLE workout_templates (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    goal TEXT NOT NULL,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_workout_templates_created_at ON workout_templates(created_at DESC);

-- ============================================
-- WORKOUT_BLOCKS TABLE
-- ============================================
CREATE TABLE workout_blocks (
    id TEXT PRIMARY KEY,
    template_id TEXT NOT NULL REFERENCES workout_templates(id) ON DELETE CASCADE,
    block_index INTEGER NOT NULL,
    type TEXT NOT NULL, -- warmup, animalFlow, strength, mobility, core, conditioning, cooldown
    title TEXT NOT NULL,
    target_duration_seconds INTEGER NOT NULL,
    description TEXT,
    rounds INTEGER NOT NULL DEFAULT 1,
    UNIQUE(template_id, block_index)
);

CREATE INDEX idx_workout_blocks_template_id ON workout_blocks(template_id);
CREATE INDEX idx_workout_blocks_template_block_index ON workout_blocks(template_id, block_index);

-- ============================================
-- WORKOUT_BLOCK_EXERCISES TABLE
-- ============================================
CREATE TABLE workout_block_exercises (
    id TEXT PRIMARY KEY,
    block_id TEXT NOT NULL REFERENCES workout_blocks(id) ON DELETE CASCADE,
    exercise_id TEXT NOT NULL REFERENCES exercises(id) ON DELETE RESTRICT,
    exercise_index INTEGER NOT NULL,
    prescription TEXT NOT NULL, -- e.g., "3 × 8" includes set count
    planned_sets JSONB NOT NULL DEFAULT '[]'::jsonb,
    setup_duration_seconds INTEGER,
    work_duration_seconds INTEGER,
    rest_duration_seconds INTEGER,
    UNIQUE(block_id, exercise_id, exercise_index)
);

CREATE INDEX idx_workout_block_exercises_block_id ON workout_block_exercises(block_id);
CREATE INDEX idx_workout_block_exercises_exercise_id ON workout_block_exercises(exercise_id);
CREATE INDEX idx_workout_block_exercises_block_exercise_index ON workout_block_exercises(block_id, exercise_index);

-- ============================================
-- SESSIONS TABLE
-- ============================================
CREATE TABLE sessions (
    id TEXT PRIMARY KEY,
    template_id TEXT NOT NULL REFERENCES workout_templates(id) ON DELETE RESTRICT,
    started_at TIMESTAMPTZ NOT NULL,
    completed_at TIMESTAMPTZ,
    duration_seconds INTEGER,
    notes TEXT,
    paused_at TIMESTAMPTZ,
    total_paused_duration_seconds INTEGER NOT NULL DEFAULT 0,
    average_heart_rate INTEGER,
    max_heart_rate INTEGER,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_sessions_template_id ON sessions(template_id);
CREATE INDEX idx_sessions_started_at ON sessions(started_at DESC);
CREATE INDEX idx_sessions_completed_at ON sessions(completed_at DESC) WHERE completed_at IS NOT NULL;

-- ============================================
-- SESSION_BLOCKS TABLE
-- ============================================
CREATE TABLE session_blocks (
    id TEXT PRIMARY KEY,
    session_id TEXT NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
    block_index INTEGER NOT NULL,
    type TEXT NOT NULL,
    target_duration_seconds INTEGER NOT NULL,
    actual_duration_seconds INTEGER,
    notes TEXT,
    round_index INTEGER,
    total_rounds INTEGER,
    UNIQUE(session_id, block_index)
);

CREATE INDEX idx_session_blocks_session_id ON session_blocks(session_id);
CREATE INDEX idx_session_blocks_session_block_index ON session_blocks(session_id, block_index);

-- ============================================
-- SESSION_BLOCK_EXERCISES TABLE
-- ============================================
CREATE TABLE session_block_exercises (
    id TEXT PRIMARY KEY,
    block_id TEXT NOT NULL REFERENCES session_blocks(id) ON DELETE CASCADE,
    exercise_id TEXT NOT NULL REFERENCES exercises(id) ON DELETE RESTRICT,
    exercise_index INTEGER NOT NULL,
    prescription TEXT NOT NULL,
    planned_sets JSONB NOT NULL DEFAULT '[]'::jsonb,
    setup_duration_seconds INTEGER,
    work_duration_seconds INTEGER,
    rest_duration_seconds INTEGER,
    UNIQUE(block_id, exercise_id, exercise_index)
);

CREATE INDEX idx_session_block_exercises_block_id ON session_block_exercises(block_id);
CREATE INDEX idx_session_block_exercises_exercise_id ON session_block_exercises(exercise_id);
CREATE INDEX idx_session_block_exercises_block_exercise_index ON session_block_exercises(block_id, exercise_index);

-- ============================================
-- SESSION_SET_LOGS TABLE
-- ============================================
CREATE TABLE session_set_logs (
    id TEXT PRIMARY KEY,
    block_id TEXT NOT NULL REFERENCES session_blocks(id) ON DELETE CASCADE,
    exercise_id TEXT NOT NULL REFERENCES exercises(id) ON DELETE RESTRICT,
    set_index INTEGER NOT NULL,
    weight_kg DOUBLE PRECISION,
    reps INTEGER,
    duration_seconds INTEGER,
    unit_remaining INTEGER, -- Units left in the tank (reps or seconds)
    UNIQUE(block_id, exercise_id, set_index)
);

CREATE INDEX idx_session_set_logs_block_id ON session_set_logs(block_id);
CREATE INDEX idx_session_set_logs_exercise_id ON session_set_logs(exercise_id);
CREATE INDEX idx_session_set_logs_block_exercise ON session_set_logs(block_id, exercise_id);
CREATE INDEX idx_session_set_logs_block_exercise_set ON session_set_logs(block_id, exercise_id, set_index);

-- ============================================
-- SESSION_NOTES TABLE (R3)
-- ============================================
CREATE TABLE session_notes (
    id TEXT PRIMARY KEY,
    session_id TEXT NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
    exercise_id TEXT,
    block_id TEXT,
    content TEXT NOT NULL,
    note_type TEXT NOT NULL,
    source TEXT NOT NULL DEFAULT 'user',
    timestamp TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_session_notes_session_id ON session_notes(session_id);
CREATE INDEX idx_session_notes_timestamp ON session_notes(timestamp DESC);

-- ============================================
-- UPDATED_AT TRIGGER FUNCTION
-- ============================================
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Apply triggers to all tables with updated_at
CREATE TRIGGER update_fitness_goals_updated_at BEFORE UPDATE ON fitness_goals
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_background_notes_updated_at BEFORE UPDATE ON background_notes
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_exercises_updated_at BEFORE UPDATE ON exercises
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_workout_templates_updated_at BEFORE UPDATE ON workout_templates
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_sessions_updated_at BEFORE UPDATE ON sessions
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_session_notes_updated_at BEFORE UPDATE ON session_notes
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- HEART_RATE_SAMPLES TABLE (R5)
-- ============================================
CREATE TABLE heart_rate_samples (
    id TEXT PRIMARY KEY,
    session_id TEXT NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
    timestamp TIMESTAMPTZ NOT NULL,
    bpm INTEGER NOT NULL,
    source TEXT NOT NULL,
    energy_kcal REAL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_heart_rate_samples_session_id ON heart_rate_samples(session_id);
CREATE INDEX idx_heart_rate_samples_timestamp ON heart_rate_samples(timestamp DESC);

CREATE TRIGGER update_heart_rate_samples_updated_at
    BEFORE UPDATE ON heart_rate_samples
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- CARDIO_WORKOUTS TABLES (R7)
-- ============================================
CREATE TABLE cardio_workouts (
    id TEXT PRIMARY KEY,
    external_workout_id TEXT NOT NULL UNIQUE,
    activity_type TEXT NOT NULL DEFAULT 'outdoorRun',
    started_at TIMESTAMPTZ NOT NULL,
    ended_at TIMESTAMPTZ NOT NULL,
    duration_seconds INTEGER NOT NULL,
    distance_meters DOUBLE PRECISION NOT NULL,
    energy_kcal DOUBLE PRECISION,
    avg_heart_rate_bpm DOUBLE PRECISION,
    max_heart_rate_bpm DOUBLE PRECISION,
    route_available BOOLEAN NOT NULL DEFAULT false,
    source_name TEXT NOT NULL DEFAULT 'Apple Health',
    source_bundle_id TEXT,
    device_model TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_cardio_workouts_started_at ON cardio_workouts(started_at DESC);
CREATE INDEX idx_cardio_workouts_external_workout_id ON cardio_workouts(external_workout_id);

CREATE TABLE cardio_route_points (
    id TEXT PRIMARY KEY,
    workout_id TEXT NOT NULL REFERENCES cardio_workouts(id) ON DELETE CASCADE,
    point_index INTEGER NOT NULL,
    lat DOUBLE PRECISION NOT NULL,
    lng DOUBLE PRECISION NOT NULL,
    altitude_meters DOUBLE PRECISION,
    timestamp TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(workout_id, point_index)
);

CREATE INDEX idx_cardio_route_points_workout_id ON cardio_route_points(workout_id);
CREATE INDEX idx_cardio_route_points_timestamp ON cardio_route_points(timestamp DESC);

CREATE TABLE cardio_heart_rate_samples (
    id TEXT PRIMARY KEY,
    workout_id TEXT NOT NULL REFERENCES cardio_workouts(id) ON DELETE CASCADE,
    timestamp TIMESTAMPTZ NOT NULL,
    bpm INTEGER NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(workout_id, timestamp)
);

CREATE INDEX idx_cardio_heart_rate_samples_workout_id ON cardio_heart_rate_samples(workout_id);
CREATE INDEX idx_cardio_heart_rate_samples_timestamp ON cardio_heart_rate_samples(timestamp DESC);

CREATE TABLE cardio_best_efforts (
    id TEXT PRIMARY KEY,
    workout_id TEXT NOT NULL REFERENCES cardio_workouts(id) ON DELETE CASCADE,
    distance_meters DOUBLE PRECISION NOT NULL,
    elapsed_seconds DOUBLE PRECISION NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(workout_id, distance_meters)
);

CREATE INDEX idx_cardio_best_efforts_workout_id ON cardio_best_efforts(workout_id);

CREATE TRIGGER update_cardio_workouts_updated_at BEFORE UPDATE ON cardio_workouts
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_cardio_route_points_updated_at BEFORE UPDATE ON cardio_route_points
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_cardio_heart_rate_samples_updated_at BEFORE UPDATE ON cardio_heart_rate_samples
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_cardio_best_efforts_updated_at BEFORE UPDATE ON cardio_best_efforts
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
