GRANT USAGE ON SCHEMA public TO tw_tenant;

CREATE TABLE users
(
    id         UUID PRIMARY KEY,
    email      text UNIQUE NOT NULL,
    name       text        NOT NULL,
    created_at timestamp   NOT NULL,
    updated_at timestamp   NOT NULL
);

GRANT SELECT, INSERT, UPDATE
    ON TABLE public.users
    TO tw_tenant;

CREATE TABLE sessions
(
    id          UUID PRIMARY KEY,
    token_hash  text UNIQUE NOT NULL,
    nonce       text UNIQUE,
    user_id     UUID REFERENCES users (id) ON DELETE CASCADE,
    created_at  timestamp   NOT NULL,
    updated_at  timestamp   NOT NULL
);

GRANT SELECT, INSERT, UPDATE, DELETE
    ON TABLE public.sessions
    TO tw_tenant;

CREATE TABLE vehicles
(
    id               UUID PRIMARY KEY,
    name             text      NOT NULL,
    owner_id         UUID      NOT NULL DEFAULT current_setting('tw.tenant_id')::uuid REFERENCES users (id) ON DELETE CASCADE,
    manufacture_date date      NOT NULL,
    distance_unit    text      NOT NULL DEFAULT 'mi'
        CONSTRAINT vehicles_distance_unit_check CHECK (distance_unit IN ('mi', 'km')),
    created_at       timestamp NOT NULL,
    updated_at       timestamp NOT NULL,
    UNIQUE (owner_id, id)
);

GRANT SELECT, INSERT, UPDATE, DELETE
    ON TABLE public.vehicles
    TO tw_tenant;

ALTER TABLE vehicles
    ENABLE ROW LEVEL SECURITY;

ALTER TABLE vehicles
    FORCE ROW LEVEL SECURITY;

CREATE
    POLICY owner_access
    ON vehicles
    FOR ALL
    TO tw_tenant
    USING (owner_id = current_setting('tw.tenant_id')::uuid)
    WITH CHECK (owner_id = current_setting('tw.tenant_id')::uuid);

CREATE TABLE schedules
(
    id              UUID PRIMARY KEY,
    owner_id        UUID      NOT NULL DEFAULT current_setting('tw.tenant_id')::uuid REFERENCES users (id) ON DELETE CASCADE,
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

GRANT SELECT, INSERT, UPDATE, DELETE
    ON TABLE public.schedules
    TO tw_tenant;

ALTER TABLE schedules
    ENABLE ROW LEVEL SECURITY;

ALTER TABLE schedules
    FORCE ROW LEVEL SECURITY;

CREATE
    POLICY owner_access
    ON schedules
    FOR ALL
    TO tw_tenant
    USING (owner_id = current_setting('tw.tenant_id')::uuid)
    WITH CHECK (owner_id = current_setting('tw.tenant_id')::uuid);

CREATE TABLE services
(
    id         UUID PRIMARY KEY,
    owner_id   UUID      NOT NULL DEFAULT current_setting('tw.tenant_id')::uuid REFERENCES users (id) ON DELETE CASCADE,
    vehicle_id UUID      NOT NULL REFERENCES vehicles (id) ON DELETE CASCADE,
    date       date      NOT NULL,
    mileage    integer   NOT NULL,
    details    text      NOT NULL,
    created_at timestamp NOT NULL,
    updated_at timestamp NOT NULL,
    UNIQUE (owner_id, id),
    FOREIGN KEY (owner_id, vehicle_id) REFERENCES vehicles (owner_id, id)
);

GRANT SELECT, INSERT, UPDATE, DELETE
    ON TABLE public.services
    TO tw_tenant;

ALTER TABLE services
    ENABLE ROW LEVEL SECURITY;

ALTER TABLE services
    FORCE ROW LEVEL SECURITY;

CREATE
    POLICY owner_access
    ON services
    FOR ALL
    TO tw_tenant
    USING (owner_id = current_setting('tw.tenant_id')::uuid)
    WITH CHECK (owner_id = current_setting('tw.tenant_id')::uuid);

