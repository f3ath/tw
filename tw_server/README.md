# TW Server

## Database setup

Start PostgreSQL from the repository root:

```sh
docker compose -f tw_server/docker-compose.yml up -d --wait
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
