CREATE TABLE users
(
    id         UUID PRIMARY KEY,
    email      text UNIQUE NOT NULL,
    name       text        NOT NULL,
    created_at timestamp   NOT NULL,
    updated_at timestamp   NOT NULL
);

CREATE TABLE sessions
(
    id          UUID PRIMARY KEY,
    session_key text UNIQUE NOT NULL,
    nonce       text UNIQUE,
    user_id    UUID REFERENCES users (id) ON DELETE CASCADE,
    created_at  timestamp   NOT NULL,
    updated_at  timestamp   NOT NULL
);

CREATE TABLE vehicles
(
    id               UUID PRIMARY KEY,
    name             text      NOT NULL,
    owner_id         UUID      NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    manufacture_date date      NOT NULL,
    created_at       timestamp NOT NULL,
    updated_at       timestamp NOT NULL,
    UNIQUE (owner_id, id)
);

-- ALTER TABLE vehicles ENABLE ROW LEVEL SECURITY;

-- ALTER TABLE vehicles FORCE ROW LEVEL SECURITY;

CREATE TABLE schedules
(
    id              UUID PRIMARY KEY,
    owner_id        UUID      NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    vehicle_id      UUID      NOT NULL REFERENCES vehicles (id) ON DELETE CASCADE,
    name            text      NOT NULL,
    interval_miles  integer   NOT NULL,
    interval_months integer   NOT NULL,
    details         text      NOT NULL,
    created_at      timestamp NOT NULL,
    updated_at      timestamp NOT NULL,
    UNIQUE (owner_id, id),
    FOREIGN KEY (owner_id, vehicle_id) REFERENCES vehicles (owner_id, id)
);

-- ALTER TABLE schedules ENABLE ROW LEVEL SECURITY;

-- ALTER TABLE schedules FORCE ROW LEVEL SECURITY;

GRANT USAGE
ON SCHEMA public
TO tw_tenant;

GRANT SELECT, INSERT, UPDATE, DELETE
ON ALL TABLES IN SCHEMA public
TO tw_tenant;
