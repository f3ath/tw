# TorqueWrench (TW)

Flutter Material 3 car-maintenance app backed by the TorqueWrench API. Read [ARCHITECTURE.md](ARCHITECTURE.md) for layer boundaries and concrete classes; [README-CODEX.md](README-CODEX.md) and [the UX specification](docs/ux/car-maintenance-ux-spec.md) define the handoff.

## Launch

From this Flutter package directory, with Flutter/Dart supporting Dart 3.13.5 or later:

```sh
flutter pub get
flutter run -d chrome --web-port=8765
```

For a release web bundle:

```sh
flutter build web
python3 -m http.server 8765 --bind 127.0.0.1 --directory build/web
```

Open http://localhost:8765. Keep the same origin/port to reuse web storage. Native targets use the platform preferences store; run `flutter devices` to select an available target.

## Authentication and server configuration

Continue with Google creates a session through `TwApiClient`, opens the server-provided Google authorization URL, and polls for the authenticated user. On web, sign-in opens a popup; on native platforms it opens the system browser. Complete Google sign-in there and return to the app. Sign-in expires after five minutes. Web popup cancellation is detected automatically.

The default Server address is `http://localhost:8080/api/v0`. Settings saves the complete API base URL locally; login and session restore use that saved value. The previous `http://localhost:8080` default migrates automatically to include `/api/v0`. Start the server with its Google OAuth credentials and registered callback URL before signing in. A physical device needs a reachable server hostname instead of its own localhost. Web hosting and the API must also permit the browser's HTTP/CORS policy.

Session ID, bearer key, and original server URL persist in platform preferences. App startup validates the saved session with the server; revoked sessions return to sign-in, while connection failures offer Retry. Changing the configured server never sends an old server's bearer to the new server. Sign out revokes the session at its original server before removing the saved session and local account cache; failed requests retain the session for retry.

## Maintenance data

Vehicles, schedules, services and operations use the authenticated `TwApiClient` through `ApiMaintenanceRepository` and `ApiMaintenanceService`. New accounts start empty. The server assigns record IDs; successful saves use those IDs for navigation. Scheduled operation names/details follow their schedules; custom operations have editable names/details. Service dates may be up to seven calendar days ahead.

The app caches the complete garage by server URL and user ID. A failed maintenance fetch can display the saved snapshot and its original as-of time; writes remain disabled until a successful refresh. Session restoration still requires server validation. The Estimated reading currently equals the latest actual reading; due status is calculated locally.

Add/edit vehicles and items, log/edit/delete services (including zero-operation mileage updates), archive/restore items, browse linked history, edit Settings, and sign out through the account menu. Units are fixed at vehicle creation. A month is 30 days. The garage previews three due items, with the remainder opening Due. The bottom bar always contains exactly Vehicles and Settings in the signed-in shell.

Hash routes support `/vehicle/<id>?tab=0|1|2`, `/item/<id>`, `/service/<id>` and `/settings`, for example `http://localhost:8765/#/vehicle/runner`. Authentication restores the requested saved-record route; inaccessible IDs show Not found. Forms retain their saved parent URL on refresh; unsaved drafts survive navigation guards and temporary reauthentication only in the running process.

## Sign-out and development fixtures

Sign out revokes the session and clears the current account's local cache. Server records remain available after signing in again. Settings survives sign out. Clear site/application storage to reset local preferences.

`LocalMaintenanceRepository`, simulated authentication and failure controls remain available for isolated tests. The default composition uses the real API and does not seed demo data or enable simulated offline/save failures. Ctrl+Alt+E opens the reauthentication screen while retaining the running form.

## Scoped checks

```sh
dart format lib test
flutter analyze
flutter test
flutter build web
```

The API-backed repository test expects a running server at `localhost:8080` configured with `INSTANCE_TYPE=test` (TestOAuth). It creates a unique test account, completes the test callback, exercises forms and CRUD through the real client, and removes its vehicles during cleanup. It also covers session restore, cached reads during a connection failure, session expiry, retained drafts, and sign-out without deleting server records. Widget and policy tests retain injected fakes for deterministic layout and validation checks.

Dependency tests confine API, browser and storage dependencies to Services; model-only shared imports are allowed outside Services. API saves are sequential across endpoints. Partial-save recovery and server-enforced conditional writes remain future work. Current edit checks compare refreshed records with the form's original snapshot; they cannot prevent a concurrent write between the check and save.

## Native build compatibility

`shared_preferences_foundation` is explicitly pinned to 2.5.7. Version 2.6.0's generated Swift failed to compile with this host's Xcode 16.0; the 2.5.7 implementation builds with the same repository/Service API. Keep this constraint until upgrading and rechecking the Apple toolchain.

```sh
flutter build macos --release
flutter run -d macos --release
flutter build apk --debug
flutter build apk --release
flutter build ios --release --no-codesign
```

The macOS release build and Android debug/release APK builds passed on this host. Gradle installed the configured Android NDK, CMake, platform and build tools using the existing SDK licenses. No Android emulator/device was connected, so Android runtime behavior is unverified. After installing iOS 18, the unsigned iOS release build passed (`build/ios/iphoneos/Runner.app`). The app also built and launched on the iPhone 16 Pro iOS 18.0 simulator; mock sign-in, due navigation and a mileage-only save were verified through the live UI. A Flutter hot restart restored the session and saved 91,700-mile reading. Signing is still required for physical-device deployment; no signed device/archive validation was performed. Windows/Linux require their respective build hosts and were not built here.
