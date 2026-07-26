-- R3 follow-up: add id primary keys to block exercise tables
-- PostgREST expects a single-column primary key named id

-- workout_block_exercises
ALTER TABLE workout_block_exercises ADD COLUMN id TEXT;
UPDATE workout_block_exercises
SET id = md5(block_id || ':' || exercise_id || ':' || exercise_index);
ALTER TABLE workout_block_exercises ALTER COLUMN id SET NOT NULL;
ALTER TABLE workout_block_exercises DROP CONSTRAINT workout_block_exercises_pkey;
ALTER TABLE workout_block_exercises ADD PRIMARY KEY (id);
CREATE UNIQUE INDEX idx_workout_block_exercises_unique
  ON workout_block_exercises(block_id, exercise_id, exercise_index);

-- session_block_exercises
ALTER TABLE session_block_exercises ADD COLUMN id TEXT;
UPDATE session_block_exercises
SET id = md5(block_id || ':' || exercise_id || ':' || exercise_index);
ALTER TABLE session_block_exercises ALTER COLUMN id SET NOT NULL;
ALTER TABLE session_block_exercises DROP CONSTRAINT session_block_exercises_pkey;
ALTER TABLE session_block_exercises ADD PRIMARY KEY (id);
CREATE UNIQUE INDEX idx_session_block_exercises_unique
  ON session_block_exercises(block_id, exercise_id, exercise_index);
