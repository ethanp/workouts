-- Add typed planned workout set prescriptions to template and session exercises.

ALTER TABLE workout_block_exercises
  ADD COLUMN planned_sets JSONB NOT NULL DEFAULT '[]'::jsonb;

ALTER TABLE session_block_exercises
  ADD COLUMN planned_sets JSONB NOT NULL DEFAULT '[]'::jsonb;
