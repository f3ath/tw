# TW server

One server Deployment and an internal Service on port 8080. No chart
dependencies: PostgreSQL is installed separately. The server runs migrations
on startup; a single replica and Recreate strategy avoid overlapping server
instances during upgrades.

## Install

Run from the repository root with kubectl and Helm targeting the same cluster.
First complete the [PostgreSQL installation](../postgres/README.md), including
its tenant setup hook. The defaults expect its release to be named `pg`, with
database `tw` and Secret `database`, in the same namespace as the server.

Create an OAuth Secret in that namespace containing `GOOGLE_OAUTH_CLIENT_ID`
and `GOOGLE_OAUTH_CLIENT_SECRET`. For example, prepare a private local file
with those two KEY=value entries, then run:

```sh
kubectl -n tw create secret generic server-oauth --from-env-file=/path/to/oauth.env
```

The root Makefile reads deployment settings from the Git-ignored root `.env`.
Copy [env.example](../../../env.example) to `.env` and set `REGISTRY`,
`SERVER_IMAGE`, `SERVER_TAG`, `SERVER_PLATFORM`, `KUBE_CONTEXT`,
`KUBE_NAMESPACE`, `SERVER_RELEASE`, and `SERVER_VALUES_FILE`.

```sh
make push-server
make deploy-server
```

The deploy target passes SERVER_VALUES_FILE to Helm using --values. Keep this
file outside the repository. For example, set this in .env:

```dotenv
SERVER_VALUES_FILE=$(HOME)/.config/tw/server-values.yaml
```

The local values file can override any chart setting:

```yaml
image: registry.example.com:5000/tw-server:dev-1
baseUri: https://api.example.com/api/v0
```

Keep its image reference in sync with the image built and pushed by Make.
Use an absolute path or a path relative to the make working directory; use
$(HOME) rather than ~. The target requires an explicit context and a readable
values file. It does not build, push, create Secrets, or install PostgreSQL.
The namespace must already exist. Passwords remain in Kubernetes Secrets.

For other chart overrides, use Helm directly:

```sh
helm upgrade --install api ./server/helm/server -n tw \
  -f /path/to/server-values.yaml --wait --timeout 5m
```

The image must be accessible to the cluster and built for the node's
architecture. This chart assumes registry access is already configured.
For an imported local image, set `imagePullPolicy: Never`.

## Access and configuration

For local access with the default `baseUri`:

```sh
kubectl -n tw port-forward service/api 8080:8080
```

External routing is managed independently by the repository-level
[ingress chart](../../../helm/ingress/README.md). Keep this chart's Service
internal and set `baseUri` to the externally reachable API URL, including its
port and `/api/v0` path. Register the matching `/auth/google/callback` URL with
Google; non-localhost web OAuth redirects generally require HTTPS.

Override `database.host`, `database.port`, `database.name`, and
`database.existingSecret` when using a different PostgreSQL release.
The database Secret must have `DATABASE_SYSTEM_PASSWORD` and
`DATABASE_TENANT_PASSWORD` keys. Usernames are fixed to `tw_system` and
`tw_tenant`, matching the PostgreSQL chart.

Other values are `oauthSecret`, `imagePullPolicy`, and `resources`.
Both Secrets must exist in the server's namespace. After rotating credentials
in PostgreSQL and updating Secrets, restart the server Deployment to refresh
its environment:

```sh
kubectl -n tw rollout restart deployment/api
```

The startup probe waits for database initialization using the readiness
endpoint. Readiness and liveness use the server's existing health endpoints.
