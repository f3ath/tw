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

## Current state — 2026-11-13

- `tw_app/` is the active learning application; `app_proto/` is the reference prototype.
- Authentication orchestrates login, polling, timeout/cancellation, and window cleanup through ports. TwApp retains the authenticated User and switches between welcome and garage; welcome handles pending, failure/retry, and cancellation. Session restoration remains planned.
- main shares one TwApiClient between real authentication and vehicle adapters. Use `--dart-define=FAKE=true` for the development fakes. Models come from `shared/model.dart`.
- Vehicle listing, creation, editing, and confirmed deletion are wired to the backend. Edit preserves the vehicle ID and locks distance units. Successful form submission returns a boolean refresh signal.
- GarageScreen owns/disposes GarageViewModel. VehicleCard owns card/menu rendering and emits actions; navigation, deletion feedback, and refresh remain in the screen. GarageScreen.vehicleCardKey supplies list-item identity.
- Deletion refreshes after both success and exceptions because a lost response can leave the outcome uncertain. Exceptions show “Could not confirm deletion. Refreshing...”. Cancellation skips deletion and refresh. Manage schedules is still a no-op; due-services content is a placeholder.
- VehicleFormScreen shares create/edit validation and submission/error handling, with persistence extracted into a private method. DateFormField provides typed date selection.
- TestRobot contains shared utilities; WelcomeRobot, GarageRobot, and VehicleFormRobot own screen-specific interactions. PumpMode selects none/frame/settle. Menu and dropdown finders target typed, hit-testable entries.
- InMemoryVehicleRepo defaults to empty and accepts initialVehicles. pauseNextList/Create/Delete gates affect one request each. Sample users/vehicles live in lib/testing/samples.dart; the test harness and fake-backend setup seed explicitly.
- Latest verification: all **29 tw_app tests pass**; static analysis is clean. Builds and real authentication were not reverified during this refactor. Previously verified builds are not evidence of current real-backend behavior.

## Next exercise

Recommended next: implement the schedule-list flow for a selected vehicle, before adding schedule mutations.

- Add a semantic ScheduleRepo listing port, a backend adapter using the existing TwApiClient.listSchedules(vehicleId), and an in-memory fake.
- Wire Manage schedules to a screen showing the selected vehicle and its schedules, with loading, error/retry, and empty states.
- Test selecting the correct vehicle and passing its ID, successful loading, empty results, and failure/retry using controlled futures.
- Observable checkpoint: selecting Manage schedules on either vehicle shows that vehicle’s schedules; returning leaves the garage usable.

Remaining vehicle-test gaps include edit failure/retry and deletion that succeeds server-side before the response fails. The in-memory repository still derives new IDs from map length, which can collide after deletion; address before relying on delete-then-create fake workflows.

## Next iteration — deferred work

- Clean up old server sessions, including sessions left behind by failed revocation; define policy/mechanism then.
- Finish auth lifecycle/error handling and retained-credential cleanup. Local logout currently clears displayed User before revocation, but failure handling and credential cleanup remain incomplete.
- Resolve HTTP client lifetime ownership. AuthService and VehicleRepo ports now live in standalone files under lib/app/.
- Revisit name-width constraints and long-name layout checks, explicitly deferred by the user.

Offline mode, synchronization, and advanced network behavior are not committed next-iteration features.

## Maintaining this handover

Replace current-state and next-exercise notes as work progresses; do not append detailed session history. Record meaningful decisions, outstanding limitations, and the latest verification. Distinguish completed behavior from planned work and check source before repeating old review findings.
