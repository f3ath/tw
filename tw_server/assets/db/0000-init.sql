CREATE TABLE users
(
    id         text PRIMARY KEY,
    email      text UNIQUE NOT NULL,
    name       text        NOT NULL,
    created_at timestamp   NOT NULL,
    updated_at timestamp   NOT NULL
);

CREATE TABLE sessions
(
    id          text PRIMARY KEY,
    session_key text UNIQUE NOT NULL,
    nonce       text UNIQUE,
    user_id     text REFERENCES users (id) ON DELETE CASCADE,
    created_at  timestamp   NOT NULL,
    updated_at  timestamp   NOT NULL
);

CREATE TABLE vehicles
(
    id               text PRIMARY KEY,
    name             text      NOT NULL,
    user_id          text      NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    manufacture_date date      NOT NULL,
    created_at       timestamp NOT NULL,
    updated_at       timestamp NOT NULL
);

CREATE TABLE schedules
(
    id              text PRIMARY KEY,
    vehicle_id      text      NOT NULL REFERENCES vehicles (id) ON DELETE CASCADE,
    name            text      NOT NULL,
    interval_miles  integer   NOT NULL,
    interval_months integer   NOT NULL,
    details         text      NOT NULL,
    created_at      timestamp NOT NULL,
    updated_at      timestamp NOT NULL
);
