# Torque Wrench — learning project

Session handover for `tw_app/`. Read this before continuing; inspect current source for changes made between sessions.

## Working agreement

- The user is a professional Dart developer learning Flutter and mobile development.
- Teach through small exercises: explain concepts and tradeoffs, define an observable checkpoint, then review the user's implementation.
- The user writes application code. Do not implement features or provide complete solutions unless asked. Documentation updates are authorized.
- Tests are the source of truth for behavior. Add meaningful tests alongside features, using controlled futures/time for asynchronous behavior. Prefer TDD where it makes sense.
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

- Flutter 3.50 / Dart 3.14 toolchain. Import Material widgets from `package:material_ui/material_ui.dart` (standalone `material_ui` dependency), not the deprecated `package:flutter/material.dart`.
- Use ports/adapters. Application logic and its tests depend on semantic ports, not HTTP messages or TwApiClient.
- Skip unit tests for trivial API adapters while TwApiClient evolves; retain application behavior tests.
- Null-to-empty mapping for user name/email is deliberate. Exceptions cross ports unchanged for now.
- URI validation is deferred; retain the adapter's missing-completion-URI check.
- User-facing feedback belongs in presentation. Cancellation is handled silently; other login exceptions currently show a generic snackbar.
- Select login-window adapters through conditional exports. Web reserves a popup synchronously before awaiting requests. Native launches an external browser, cannot observe closure, and cannot close it.

## Current state — 2026-11-11

- Auth service orchestrates session creation, navigation, polling, timeout/cancellation, and window cleanup through ports.
- `app_proto/` is the renamed reference prototype (Dart package `app_proto`); `tw_app/` remains the active learning application.
- main selects real authentication/vehicles by default and shares one TwApiClient between their adapters. Use `--dart-define=USE_FAKE_BACKEND=true` for development stubs. Models come from `shared/model.dart`.
- TwApp retains the authenticated User and switches between welcome and garage. The name appears beside logout.
- Welcome handles pending, failure/retry, and cancellation states.
- Domain Vehicle includes id, name, manufactureDate, and distanceUnit.
- GarageScreen owns GarageViewModel in State, creates/loads it in initState, and disposes it on unmount. ListenableBuilder renders loading, error/retry, empty, and keyed vehicle rows. TwApp receives VehicleRepo; BackendVehicleRepo delegates listing and creation to TwApiClient.
- Latest full verification on Flutter 3.50: `flutter test` — **22 passed**; static analysis, release web build, and macOS debug build pass. Prototype analysis/web/macOS debug builds also pass, with 31 server-independent tests passing; its live-API test needs the server at localhost:8080. Real browser/native authentication has not been verified by these tests.
- Tests cover auth orchestration, welcome failure/retry/cancellation, app login/logout and name wiring, and garage empty/populated rendering.

## Next exercise

Vehicle editing groundwork underway: optional vehicle and prefilled-value test exist. Reusable `lib/ui/form/date_form_field.dart` extends FormField<DateTime>, owns its display controller, synchronizes init/didChange/reset, and forwards validator/onSaved. It is integrated into VehicleFormScreen with initialValue, injected clock, and FormState.save(). Existing form tests pass; dedicated reset/typed-field tests remain optional follow-up.

Next continue edit update semantics and row navigation; existing save still calls createVehicle. User accepts creation coverage and does not require extra retry/refreshed-list assertions. Keep trivial adapter tests skipped.

Reference prototype is app_proto; active app is tw_app. Session restoration remains planned, not completed.

## Next iteration — deferred work

- Clean up old server sessions, including sessions left behind by failed revocation; define policy/mechanism then.
- Finish auth lifecycle/error handling and retained-credential cleanup. Local logout currently clears displayed User before revocation, but failure handling and credential cleanup remain incomplete.
- Resolve HTTP client lifetime ownership. AuthService and VehicleRepo ports now live in standalone files under lib/app/.
- Revisit name-width constraints and long-name layout checks, explicitly deferred by the user.

Offline mode, synchronization, and advanced network behavior are not committed next-iteration features.

## Maintaining this handover

Replace current-state and next-exercise notes as work progresses; do not append detailed session history. Record meaningful decisions, outstanding limitations, and the latest verification. Distinguish completed behavior from planned work and check source before repeating old review findings.
