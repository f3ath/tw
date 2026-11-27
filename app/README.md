# Torque Wrench App

Flutter application for vehicle maintenance.

## Working agreement

- Tests are the source of truth. Add meaningful behavior tests alongside features,
  using controlled futures and clocks for asynchronous behavior; prefer TDD where useful.
- Use in-memory repositories as test doubles in application and widget tests;
  do not add dedicated tests for them or trivial backend adapters.
- Introduce abstractions through concrete needs. Do not add widget previews.

## Running locally

Use the Flutter 3.50 / Dart 3.14 toolchain. From the repository root:

```sh
cd app
flutter pub get
flutter run -d chrome --dart-define=FAKE=true
```

Omit `cd app` if already in the app directory.
Fake mode seeds users, vehicles, schedules, services, and operations without a server.
Omit `--dart-define=FAKE=true` to use the deployed API at
`https://api.twdiy.app/api/v0`. Set `--dart-define=API_URL=<url>` to choose a
different backend. For a persistent local stack, see the
[Docker Compose setup](../README.md#local-web-app-and-persistent-database).

Platform priority is web, then iOS, then Android; Linux/macOS support is optional.
Web URLs/history, responsive layout, and keyboard/touch support are introduced as needed.

## Deploying the web app

The web app runs as a separate Helm release with an internal Service on port
8080. It uses the existing API at `https://api.twdiy.app/api/v0`.

From the repository root, use the same `REGISTRY`, `KUBE_CONTEXT`, and
`KUBE_NAMESPACE` settings as the server in the Git-ignored `.env`. Add the
web settings from [env.example](../env.example). The default release is `web`.

`make build-web` and `make push-web` use the locally installed Flutter SDK
(override with `FLUTTER=/path/to/flutter`) to compile into `app/build/web`.
Docker packages that output in Nginx. `WEB_PLATFORM` selects the Nginx image
architecture and defaults to `SERVER_PLATFORM`.

In the local file named by `WEB_VALUES_FILE`, set the image to match the
registry, image name, and tag used by Make. Use a new tag for each update.

```yaml
image: registry.example.com:5000/tw-web:dev-1
```

```sh
make push-web
make deploy-web
```

Add a published application route on your existing Cloudflare Tunnel. Set the
hostname to `web.twdiy.app` and the origin service to
`http://web.tw.svc.cluster.local:8080`. Replace `web` and `tw` with your Helm
release and namespace if they differ, and use your cluster's DNS suffix if it
differs from `cluster.local`. For a locally managed tunnel, add the following
rule before the final catch-all in your existing `cloudflared` configuration.

```yaml
  - hostname: web.twdiy.app
    service: http://web.tw.svc.cluster.local:8080
```

After routing is configured, check that the public endpoint serves the Flutter
bootstrap script, then open the app and sign in to verify the browser-to-API flow.

```sh
curl -fsS -o /dev/null https://web.twdiy.app/flutter_bootstrap.js
```

## Architecture

- `lib/app/` contains semantic repository/authentication ports and validated
  `VehicleService` / `VehicleSchedule` pairs. Models come from `shared/model.dart`.
  Backend adapters in `lib/data/` translate ports into shared API-client calls.
- `main.dart` separates real and fake composition. Real adapters share one
  `TwApiClient`; fake operation repositories share the service and schedule stores.
- `RepositoryProvider` sits above `MaterialApp` / Navigator. Screens read and retain
  their repositories without listening for replacements. Rebuilding a screen does
  not reload its list or replace its repository.
- Screens own navigation, dialogs, and model disposal. Cards render resources and
  emit typed actions. Import Material widgets from `package:material_ui/material_ui.dart`.
- `ListViewModel<T>` takes a fetch callback and exposes immutable items plus loading
  and error state. Only the latest load may update state or notify; stale completions
  and completions after disposal are ignored. Loading after disposal is a no-op.
- `FormSubmissionController` exposes `isSubmitting` and returns typed
  `SubmissionSuccess<T>`, `SubmissionFailure<T>`, or `SubmissionIgnored<T>` results.
  It guards duplicate/disposed submissions and suppresses notifications after disposal.
  Forms handle results explicitly; the controller retains no error flag.
- `deleteAndRefresh` shares deletion, error-snackbar, and mounted-refresh behavior
  across all four list screens. Resource-specific confirmation dialogs remain in screens.
- `LoadingView`, `ErrorRetryView`, `DateFormField`, and schedule interval widgets
  share presentation. Stable screen-owned keys support widget tests.
- Authentication selects login-window adapters through conditional exports. Web
  reserves a popup before awaiting requests; native launches an external browser
  and cannot observe or close that browser window. Cancellation is silent; other
  login exceptions show generic feedback. Null user name/email maps to empty text;
  URI validation remains deferred apart from the missing-completion-URI check.

## Testing and verification

Widget tests use screen-specific robots from `test/robots.dart`, explicit repository
fakes, and route harnesses that capture navigation results. `PumpMode` selects no
pump, a frame, or settling; use frames for pending requests and settle completed
transitions. `RequestGate` pauses one fake repository request, and `FixedClock`
controls dates. `ListViewModel` unit tests use fetch callbacks and controlled futures,
without repository fixtures.

Coverage includes validation, targeting/filtering, navigation results, retry,
duplicate submissions, reconciliation after deletion failures, disposal during
pending requests, and overlapping list loads.

Latest verification: all 209 app tests pass, static analysis is clean, and changed
Dart files are formatted. The web build passed after the package rename; it has
not been rerun for the subsequent refactors.

## Deferred work

- Session restoration, authentication error handling, and retained-credential cleanup.
  Local logout must remain independent of server revocation; the current auth flow
  is accepted for this iteration and should not block maintenance features.
- Cleanup policy for old server sessions, including failed revocations.
- HTTP-client lifetime ownership.
- Pull-to-refresh and long-name layout checks.
- Vehicle deletion coverage for a committed deletion followed by a lost response.

Offline mode, synchronization, and advanced network behavior are out of scope.
Keep this handover focused on current decisions, limitations, and verification;
replace stale notes rather than appending session history.
