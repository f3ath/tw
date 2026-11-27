# PostgreSQL for TW

One PostgreSQL 17 instance, a cluster-internal headless Service, and a persistent
volume. Creates the restricted `tw_tenant` role expected by the server; the
`tw_system` administrator owns the database. Application tables are created by
the server's migrations.

Run from the repository root with Helm and kubectl connected to your target
cluster. No chart dependencies.

## Install

Create the namespace and credentials once per cluster:

```sh
kubectl create namespace tw
kubectl -n tw create secret generic database \
  --from-literal=DATABASE_SYSTEM_PASSWORD="$(openssl rand -hex 32)" \
  --from-literal=DATABASE_TENANT_PASSWORD="$(openssl rand -hex 32)"
helm upgrade --install pg ./server/helm/postgres --namespace tw --wait --timeout 5m
kubectl -n tw get pods,pvc
```

The cluster's default StorageClass is used automatically. To select a different
class, set `storage.className` to an available StorageClass name. Set
`storage.size` to choose the requested volume capacity before installation.

Values: `image`, `database`, `existingSecret`, `storage.size`, and
`storage.className`. Usernames are fixed to match TW's schema grants.
Each release uses its release name for the Service and StatefulSet; the PVC is
`data-<release>-0`. Use separate Secrets for independent databases.

## Connect

For API pods in namespace `tw`:

```text
DATABASE_HOST=pg
DATABASE_PORT=5432
DATABASE_NAME=tw
DATABASE_SYSTEM_USERNAME=tw_system
DATABASE_TENANT_USERNAME=tw_tenant
```

Read the corresponding password keys from Secret `database` using
`secretKeyRef`. For an API running on the host, keep this command running and
use `DATABASE_HOST=localhost`, `DATABASE_PORT=5433`:

```sh
kubectl -n tw port-forward service/pg 5433:5432
```

## Data lifecycle

The PVC survives pod restarts and `helm uninstall pg -n tw`. The
StorageClass reclaim policy determines whether deleting the PVC also deletes
the underlying data. Storage location and durability depend on the chosen
StorageClass; this chart does not configure replication or backups.

Keep the Secret when reinstalling against existing data. Passwords, database
name apply only to an empty data directory. A post-install/post-upgrade hook
creates the tenant role if missing; existing roles and passwords are unchanged.
Changing the Secret does not rotate database passwords. Volume size/class changes are
not an in-place migration path. Keep the image on PostgreSQL 17 unless you
explicitly migrate the database.

## Tenant setup hook

Helm runs the tenant setup Job after install and upgrade, waiting for it to
complete. The Job connects over the internal Service using the administrator
password from the Secret. It retries while PostgreSQL starts, creates
`tw_tenant` only if absent, and is deleted on success. Failed Jobs remain for
inspection until the next hook run:

```sh
kubectl -n tw logs job/pg-tenant-setup
```

Ordinary pod restarts do not run Helm hooks. After replacing storage with an
empty volume, run `helm upgrade --install` again to create the tenant role.
