ALTER TABLE exercises
    ADD COLUMN IF NOT EXISTS set_metrics_style TEXT NOT NULL DEFAULT 'repsOnly';

UPDATE exercises AS exercise
SET set_metrics_style = CASE
    WHEN EXISTS (
        SELECT 1
        FROM workout_block_exercises AS workout_block_exercise
        CROSS JOIN LATERAL jsonb_array_elements(
            CASE
                WHEN jsonb_typeof(workout_block_exercise.planned_sets) = 'array'
                THEN workout_block_exercise.planned_sets
                WHEN jsonb_typeof(workout_block_exercise.planned_sets) = 'string'
                 AND left(workout_block_exercise.planned_sets #>> '{}', 1) = '['
                THEN (workout_block_exercise.planned_sets #>> '{}')::jsonb
                ELSE '[]'::jsonb
            END
        ) AS planned_set
        WHERE workout_block_exercise.exercise_id = exercise.id
          AND planned_set ? 'weightKg'
          AND planned_set->'weightKg' <> 'null'::jsonb
    ) OR EXISTS (
        SELECT 1
        FROM session_block_exercises AS session_block_exercise
        CROSS JOIN LATERAL jsonb_array_elements(
            CASE
                WHEN jsonb_typeof(session_block_exercise.planned_sets) = 'array'
                THEN session_block_exercise.planned_sets
                WHEN jsonb_typeof(session_block_exercise.planned_sets) = 'string'
                 AND left(session_block_exercise.planned_sets #>> '{}', 1) = '['
                THEN (session_block_exercise.planned_sets #>> '{}')::jsonb
                ELSE '[]'::jsonb
            END
        ) AS planned_set
        WHERE session_block_exercise.exercise_id = exercise.id
          AND planned_set ? 'weightKg'
          AND planned_set->'weightKg' <> 'null'::jsonb
    ) THEN 'repsAndWeight'
    WHEN EXISTS (
        SELECT 1
        FROM workout_block_exercises AS workout_block_exercise
        CROSS JOIN LATERAL jsonb_array_elements(
            CASE
                WHEN jsonb_typeof(workout_block_exercise.planned_sets) = 'array'
                THEN workout_block_exercise.planned_sets
                WHEN jsonb_typeof(workout_block_exercise.planned_sets) = 'string'
                 AND left(workout_block_exercise.planned_sets #>> '{}', 1) = '['
                THEN (workout_block_exercise.planned_sets #>> '{}')::jsonb
                ELSE '[]'::jsonb
            END
        ) AS planned_set
        WHERE workout_block_exercise.exercise_id = exercise.id
          AND planned_set ? 'reps'
          AND planned_set->'reps' <> 'null'::jsonb
          AND planned_set ? 'durationSeconds'
          AND planned_set->'durationSeconds' <> 'null'::jsonb
    ) OR EXISTS (
        SELECT 1
        FROM session_block_exercises AS session_block_exercise
        CROSS JOIN LATERAL jsonb_array_elements(
            CASE
                WHEN jsonb_typeof(session_block_exercise.planned_sets) = 'array'
                THEN session_block_exercise.planned_sets
                WHEN jsonb_typeof(session_block_exercise.planned_sets) = 'string'
                 AND left(session_block_exercise.planned_sets #>> '{}', 1) = '['
                THEN (session_block_exercise.planned_sets #>> '{}')::jsonb
                ELSE '[]'::jsonb
            END
        ) AS planned_set
        WHERE session_block_exercise.exercise_id = exercise.id
          AND planned_set ? 'reps'
          AND planned_set->'reps' <> 'null'::jsonb
          AND planned_set ? 'durationSeconds'
          AND planned_set->'durationSeconds' <> 'null'::jsonb
    ) THEN 'repsAndDuration'
    WHEN exercise.modality IN ('timed', 'hold') THEN 'durationOnly'
    WHEN exercise.modality IN ('mobility', 'breath') THEN 'repsAndDuration'
    ELSE 'repsOnly'
END;
