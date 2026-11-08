# Torque Wrench — learning project

Session handover for `tw_app/`. Read this before continuing; inspect current source for changes made between sessions.

## Working agreement

- The user is a professional Dart developer learning Flutter and mobile development.
- Teach through small exercises: explain concepts and tradeoffs, define an observable checkpoint, then review the user's implementation.
- The user writes application code. Do not implement features or provide complete solutions unless asked. Documentation updates are authorized.
- Tests are the source of truth for behavior. Add meaningful tests alongside features, using controlled futures/time for asynchronous behavior.
- Use `../app_proto/` as a reference, not a template to copy. Introduce abstractions through concrete needs.

## Scope

Platform priority: **web → iOS → Android**; native Linux/macOS optional. Minimal Material UI, with web URLs/history, responsive layout, keyboard/mouse and touch support introduced as needed.

First iteration:

- Google login, session restoration, and logout.
- Vehicle CRUD.
- Schedule CRUD within vehicles.
- Service CRUD with scheduled and custom operations.
- Existing server and shared Dart API client.
- Ordinary loading, validation, and request-error handling.

Logout must let the user leave the account independently of server revocation. The user accepts the current authentication implementation as sufficient for this iteration; do not block vehicle work on remaining auth work.

Offline mode, synchronization, and advanced network behavior such as atomicity are out of scope.

## Architecture decisions

- Use ports/adapters. Application logic and its tests depend on semantic ports, not HTTP messages or TwApiClient.
- Skip unit tests for trivial API adapters while TwApiClient evolves; retain application behavior tests.
- Null-to-empty mapping for user name/email is deliberate. Exceptions cross ports unchanged for now.
- URI validation is deferred; retain the adapter's missing-completion-URI check.
- User-facing feedback belongs in presentation. Cancellation is handled silently; other login exceptions currently show a generic snackbar.
- Select login-window adapters through conditional exports. Web reserves a popup synchronously before awaiting requests. Native launches an external browser, cannot observe closure, and cannot close it.

## Current state — 2026-11-06

- Auth service orchestrates session creation, navigation, polling, timeout/cancellation, and window cleanup through ports.
- Real API and platform adapters exist. `main.dart` currently selects fake authentication for development.
- TwApp retains the authenticated User and switches between welcome and garage. The name appears beside logout.
- Welcome handles pending, failure/retry, and cancellation states.
- Domain Vehicle includes id, name, manufactureDate, and distanceUnit.
- GarageScreen owns GarageViewModel in State, creates/loads it in initState, and disposes it on unmount. ListenableBuilder renders loading, error/retry, empty, and keyed vehicle rows. TwApp still supplies a development repository stub; real vehicle loading/CRUD adapters are not implemented.
- Latest full verification: `flutter test` — **20 passed**. Real browser/native authentication has not been verified by these tests.
- Tests cover auth orchestration, welcome failure/retry/cancellation, app login/logout and name wiring, and garage empty/populated rendering.

## Next exercise

Vehicle form validates and calls VehicleRepo.createVehicle, disables Save while pending, and re-enables it after completion. Fake records created vehicles and controls completion. Full suite: 20 passed. Ports moved to app/vehicle_repo.dart; tests now under test/ui/garage.

Review follow-ups: trim submitted name (currently raw text), use padded valid input to verify trimming, assert fake.created empty after invalid saves and length one while pending. Add mounted guard in save finally for navigating back during request. BackendVehicleRepo.createVehicle is still UnimplementedError; live creation not ready.

Next cover save failure with preserved inputs and enabled retry, then successful route pop and garage refresh, and implement backend creation. No trivial adapter unit tests required per user choice. Session restoration remains planned, not completed.

## Next iteration — deferred work

- Clean up old server sessions, including sessions left behind by failed revocation; define policy/mechanism then.
- Finish auth lifecycle/error handling and retained-credential cleanup. Local logout currently clears displayed User before revocation, but failure handling and credential cleanup remain incomplete.
- Resolve HTTP client lifetime ownership and move AuthServicePort out of the Flutter widget library.
- Revisit name-width constraints and long-name layout checks, explicitly deferred by the user.

Offline mode, synchronization, and advanced network behavior are not committed next-iteration features.

## Maintaining this handover

Replace current-state and next-exercise notes as work progresses; do not append detailed session history. Record meaningful decisions, outstanding limitations, and the latest verification. Distinguish completed behavior from planned work and check source before repeating old review findings.
