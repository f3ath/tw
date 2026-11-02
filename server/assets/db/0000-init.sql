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
    id         UUID PRIMARY KEY,
    token_hash text UNIQUE NOT NULL,
    nonce      text UNIQUE,
    user_id    UUID REFERENCES users (id) ON DELETE CASCADE,
    created_at timestamp   NOT NULL,
    updated_at timestamp   NOT NULL
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
    id                UUID PRIMARY KEY,
    owner_id          UUID      NOT NULL DEFAULT current_setting('tw.tenant_id')::uuid REFERENCES users (id) ON DELETE CASCADE,
    vehicle_id        UUID      NOT NULL REFERENCES vehicles (id) ON DELETE CASCADE,
    name              text      NOT NULL,
    interval_distance integer,
    interval_months   integer,
    details           text      NOT NULL,
    is_archived       boolean   NOT NULL DEFAULT false,
    created_at        timestamp NOT NULL,
    updated_at        timestamp NOT NULL,
    UNIQUE (owner_id, id),
    UNIQUE (owner_id, vehicle_id, id),
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
    odometer   integer   NOT NULL,
    details    text      NOT NULL,
    created_at timestamp NOT NULL,
    updated_at timestamp NOT NULL,
    UNIQUE (owner_id, id),
    UNIQUE (owner_id, vehicle_id, id),
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

CREATE TABLE service_operations
(
    id          UUID PRIMARY KEY,
    owner_id    UUID      NOT NULL DEFAULT current_setting('tw.tenant_id')::uuid REFERENCES users (id) ON DELETE CASCADE,
    vehicle_id  UUID      NOT NULL,
    service_id  UUID      NOT NULL,
    schedule_id UUID,
    name        text,
    details     text,
    created_at  timestamp NOT NULL,
    updated_at  timestamp NOT NULL,
    UNIQUE (owner_id, id),
    UNIQUE (service_id, schedule_id),
    FOREIGN KEY (owner_id, vehicle_id, service_id)
        REFERENCES services (owner_id, vehicle_id, id) ON DELETE CASCADE,
    FOREIGN KEY (owner_id, vehicle_id, schedule_id)
        REFERENCES schedules (owner_id, vehicle_id, id),
    CONSTRAINT service_operations_content_check CHECK (
        (schedule_id IS NOT NULL AND name IS NULL AND details IS NULL)
        OR (schedule_id IS NULL AND name IS NOT NULL AND BTRIM(name) <> '' AND details IS NOT NULL)
    )
);

GRANT SELECT, INSERT, UPDATE, DELETE
    ON TABLE public.service_operations
    TO tw_tenant;

ALTER TABLE service_operations
    ENABLE ROW LEVEL SECURITY;

ALTER TABLE service_operations
    FORCE ROW LEVEL SECURITY;

CREATE
    POLICY owner_access
    ON service_operations
    FOR ALL
    TO tw_tenant
    USING (owner_id = current_setting('tw.tenant_id')::uuid)
    WITH CHECK (owner_id = current_setting('tw.tenant_id')::uuid);
