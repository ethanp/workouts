-- Migration: Add background_notes table for R2
-- Run: ./migrate.sh workouts/migrations/002_add_background_notes.sql

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

CREATE TRIGGER update_background_notes_updated_at BEFORE UPDATE ON background_notes
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
