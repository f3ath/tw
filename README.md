# Torque Wrench

The repository contains the Flutter [app](app/README.md), the Dart
[server](server/README.md), and the shared API client and models in `shared/`.

Install dependencies in each package before running checks:

```sh
(cd app && flutter pub get)
(cd shared && dart pub get)
(cd server && dart pub get)
```

Run these commands from the repository root with Make, Dart, Flutter, and Docker
installed:

```sh
make db-start      # Start PostgreSQL and wait until healthy
make test          # Run all tests
make analyze       # Run dart analyze in all packages
make format        # Format all packages
make format-check  # Check formatting without changing files
make db-stop       # Stop and remove the database containers
```

Use `-app`, `-shared`, or `-server` to select a package, for example
`make test-app`, `make analyze-shared`, or `make format-check-server`.
The shared test target skips testing until a `shared/test` directory exists.

Server tests require the database. Its storage uses tmpfs, so stopping it discards
its data. See [server setup](server/README.md) for credentials and initialization.

Run `make help` for the target list. Override executables if needed, for example
`make analyze DART=/path/to/dart`.

## Build the server image

Run from the repository root. Copy [env.example](env.example) to `.env` and
set `REGISTRY`, `SERVER_IMAGE`, `SERVER_TAG`, and `SERVER_PLATFORM` for your
deployment. The root `.env` is ignored by Git and uses unquoted,
Make-compatible `KEY=value` assignments; it is separate from the server's
runtime configuration.

```sh
cp env.example .env
# Edit .env before pushing.
make build-server
make push-server
```

`build-server` includes both the server and its local `shared` dependency.
`push-server` builds first, then pushes `REGISTRY/SERVER_IMAGE:SERVER_TAG`.
Authenticate with `docker login` separately if the registry requires it.
Use a new tag for each deployment.

Without `.env`, the build defaults to `tw-server:local` on Docker's default
platform. Pushing requires `REGISTRY`. Override settings per invocation:

```sh
make push-server REGISTRY=registry.example.com:5000 SERVER_TAG=dev-2
```

Use `ENV_FILE=/path/to/settings.env` to select a different settings file.

For Helm deployment, also set `KUBE_CONTEXT`, `KUBE_NAMESPACE`,
`SERVER_RELEASE`, and `SERVER_VALUES_FILE` in `.env`, then run
`make deploy-server`. The referenced local values file supplies the image, API URL,
and other chart overrides. Keep its image reference in sync with builds. Install PostgreSQL and create the OAuth Secret first; see the
[server chart](server/helm/server/README.md).

The build compiles a native Dart executable. The runtime image includes the
database migrations and runs the server on port 8080. Supply configuration at
runtime through environment variables: `BASE_URI`, `DATABASE_HOST`,
`DATABASE_PORT`, `DATABASE_NAME`, `DATABASE_SYSTEM_USERNAME`,
`DATABASE_SYSTEM_PASSWORD`, `DATABASE_TENANT_USERNAME`,
`DATABASE_TENANT_PASSWORD`, `GOOGLE_OAUTH_CLIENT_ID`, and
`GOOGLE_OAUTH_CLIENT_SECRET`. See [server setup](server/README.md) for the
local database configuration. Environment files are not included in the image.

To build and push an image for both AMD64 and ARM64 nodes, use a registry tag
you can push to:

```sh
docker buildx build --platform linux/amd64,linux/arm64 \
  -f server/Dockerfile -t <registry>/tw-server:<tag> --push .
```

The single-platform build targets Docker's default build platform. For a local
ARM64 image, add `--platform linux/arm64` to `docker build`.

## Web app deployment

Use `make push-web` and `make deploy-web` to deploy the Flutter web app as an
independent Helm release. The [web deployment guide](app/README.md#deploying-the-web-app)
covers the registry settings and Cloudflare Tunnel route for `web.twdiy.app`.

## Local web app and persistent database

Register `http://localhost:8080/auth/google/callback` as an authorized redirect
URI on a Google OAuth **Web application** client. Copy `env.local.example` to
`.env.local` and fill in the client ID and secret. Sign-in requires access to
Google.

From the repository root:

```sh
make build-local-web
docker compose --env-file .env.local -f compose.local.yaml up --build -d
```

Open [http://localhost:8080](http://localhost:8080). Only the web port is
published, on loopback. Nginx serves the bundled Flutter assets and forwards
API and OAuth callback requests to the server over the Compose network.

The first command needs the local Flutter SDK and builds the web image.
Compose builds the server image and runs all three services in Docker. For
subsequent starts with the same images, omit `--build` and skip the Make step.
Run `make build-local-web` again after changing the web app.

```sh
docker compose --env-file .env.local -f compose.local.yaml down
```

A normal shutdown preserves PostgreSQL data in the `tw-local_postgres-data`
volume. Use `down --volumes` only when you intend to erase the local database.
