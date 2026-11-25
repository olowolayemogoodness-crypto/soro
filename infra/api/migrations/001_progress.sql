CREATE TABLE learners (
    id text PRIMARY KEY,
    display_name text NOT NULL
);

CREATE TABLE sessions (
    id text PRIMARY KEY,
    learner_id text NOT NULL REFERENCES learners(id) ON DELETE CASCADE,
    started_at timestamptz NOT NULL,
    subject text NOT NULL,
    topic text NOT NULL,
    lesson text NOT NULL
);
CREATE INDEX sessions_learner_started_idx ON sessions (learner_id, started_at DESC);

CREATE TABLE steps (
    id bigserial PRIMARY KEY,
    session_id text NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
    position integer NOT NULL CHECK (position > 0),
    completed boolean NOT NULL DEFAULT false,
    UNIQUE (session_id, position)
);

CREATE TABLE unaided_checks (
    session_id text PRIMARY KEY REFERENCES sessions(id) ON DELETE CASCADE,
    result text NOT NULL CHECK (result IN ('passed', 'needs_practice', 'not_taken')),
    attempts integer NOT NULL DEFAULT 0 CHECK (attempts >= 0)
);

CREATE OR REPLACE FUNCTION soro_learning_streak(p_learner_id text, p_today date DEFAULT (now() AT TIME ZONE 'Africa/Lagos')::date)
RETURNS TABLE(current_streak integer, longest_streak integer, last_active_date date)
LANGUAGE sql STABLE AS $$
    WITH active_days AS (
        SELECT DISTINCT (started_at AT TIME ZONE 'Africa/Lagos')::date AS active_date
          FROM sessions
         WHERE learner_id = p_learner_id
    ), day_groups AS (
        SELECT active_date, active_date - (row_number() OVER (ORDER BY active_date))::integer AS group_id
          FROM active_days
    ), runs AS (
        SELECT group_id, count(*)::integer AS run_length, max(active_date) AS end_day
          FROM day_groups
         GROUP BY group_id
    ), summary AS (
        SELECT COALESCE(max(run_length), 0)::integer AS longest,
               COALESCE(max(run_length) FILTER (WHERE end_day = (SELECT max(active_date) FROM active_days)), 0)::integer AS latest_run,
               max(end_day) AS last_active_date
          FROM runs
    )
    SELECT CASE
               WHEN last_active_date IS NULL OR last_active_date < p_today - 1 OR last_active_date > p_today THEN 0
               ELSE latest_run
           END,
           longest,
           last_active_date
      FROM summary;
$$;

INSERT INTO learners (id, display_name) VALUES ('demo-learner', 'Demo learner');

INSERT INTO sessions (id, learner_id, started_at, subject, topic, lesson) VALUES
('demo-q-6', 'demo-learner', (((now() AT TIME ZONE 'Africa/Lagos')::date - 6) + time '10:00') AT TIME ZONE 'Africa/Lagos', 'Mathematics', 'Quadratics', 'Factoring quadratics'),
('demo-q-5', 'demo-learner', (((now() AT TIME ZONE 'Africa/Lagos')::date - 5) + time '10:00') AT TIME ZONE 'Africa/Lagos', 'Mathematics', 'Quadratics', 'Solving by factoring'),
('demo-f-4', 'demo-learner', (((now() AT TIME ZONE 'Africa/Lagos')::date - 4) + time '10:00') AT TIME ZONE 'Africa/Lagos', 'Physics', 'Friction', 'Friction and normal force'),
('demo-v-3', 'demo-learner', (((now() AT TIME ZONE 'Africa/Lagos')::date - 3) + time '10:00') AT TIME ZONE 'Africa/Lagos', 'Physics', 'Vectors', 'Vector components'),
('demo-f-1', 'demo-learner', (((now() AT TIME ZONE 'Africa/Lagos')::date - 1) + time '10:00') AT TIME ZONE 'Africa/Lagos', 'Physics', 'Friction', 'Inclined planes'),
('demo-v-0', 'demo-learner', (((now() AT TIME ZONE 'Africa/Lagos')::date) + time '10:00') AT TIME ZONE 'Africa/Lagos', 'Physics', 'Vectors', 'Adding vectors');

INSERT INTO steps (session_id, position, completed)
SELECT s.id, p.position, p.position <= CASE WHEN s.id IN ('demo-q-5', 'demo-f-1') THEN 2 ELSE 3 END
FROM sessions s CROSS JOIN generate_series(1, 3) AS p(position);

INSERT INTO unaided_checks (session_id, result, attempts) VALUES
('demo-q-6', 'passed', 1),
('demo-q-5', 'needs_practice', 2),
('demo-f-4', 'passed', 1),
('demo-v-3', 'not_taken', 0),
('demo-f-1', 'needs_practice', 1),
('demo-v-0', 'passed', 1);
