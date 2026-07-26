-- Migration: Add fitness_goals table for R1
-- Run: ./migrate.sh workouts/migrations/001_add_fitness_goals.sql

-- ============================================
-- FITNESS_GOALS TABLE
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

-- Add updated_at trigger
CREATE TRIGGER update_fitness_goals_updated_at BEFORE UPDATE ON fitness_goals
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
