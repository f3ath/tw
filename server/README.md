# TW Server

## TODO
- request UUID validation

## Database setup

Start PostgreSQL from the repository root:

```sh
docker compose -f server/docker-compose.yml up -d --wait
```

The database is `tw_e2e` at `localhost:5432`. System credentials default to
`tw_system` / `tw_system` (`DATABASE_SYSTEM_USERNAME`, `DATABASE_SYSTEM_PASSWORD`).
Tenant credentials default to `tw_tenant` / `tw_tenant`
(`DATABASE_TENANT_USERNAME`, `DATABASE_TENANT_PASSWORD`).

Docker initializes the tenant login through `docker/init-users.sql`.
The system connection runs migrations and closes; DAOs use the tenant connection
through `Database`. Migrations grant tenant CRUD access; row-level security still
applies. Initialization scripts run only on a fresh database. Storage uses tmpfs,
so stopping the container discards its data.

## Operation text

The database permits nullable name/details, with CHECK (name IS NOT NULL OR
schedule_id IS NOT NULL). API defaults and validation remain as described below.

Operation names and details are independent of optional schedule links. Supplied
names must be nonblank; details may be empty. A linked create that omits name uses
the schedule name once, while omitted details default to an empty string. Updates
retain omitted text fields, and sending empty details clears them. Schedule edits
do not change existing operation text. Existing ownership, archive, and duplicate
link validation still applies.

The schema is defined directly in `0000-init.sql`; no separate migration is
provided. The app's scheduled-operation adapter and fake still need alignment
with this new contract to support custom linked text.

Verification: all 48 operation API tests passed and static analysis is clean.
The full server suite has 164 passes and one existing
date-validation failure: the vehicle-date test expects tomorrow to be rejected,
while parseDate currently defaults to a 30-day allowance.
