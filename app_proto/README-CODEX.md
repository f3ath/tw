# TorqueWrench (TW) — Flutter Material 3 prototype implementation brief

## How to use this handoff

Use the existing Flutter application inside the TorqueWrench monorepo. Extract this archive into that Flutter application's package directory, beside its pubspec.yaml. It adds this file and docs/ux/; it does not contain Flutter application code. Start Codex in that directory. Do not create a new Flutter project or replace the monorepo. You do not need the previous chat.

Read docs/ux/car-maintenance-ux-spec.md and inspect docs/ux/car-maintenance-wireframes.html before editing. Open the HTML in a browser to explore the reference if useful. The review toolbar (Screen, Layout, State) is outside the product and must not become part of the Flutter UI.

## Task

Replace the existing Flutter application logic with a runnable, interactive TorqueWrench (TW) application that renders the approved UX using real Material 3 widgets and deterministic mocked data. This is a local UX prototype, not a static screenshot and not a server integration. Use TorqueWrench as the app title and TW where a short name is appropriate. Implement the flows; do not stop after proposing a plan.

The UX spec defines the behavior. The HTML defines the screen hierarchy and approximate placement. Where its illustrative data or incomplete save handlers disagree with the spec, implement the spec. The prototype requirements below intentionally replace the spec's real backend/OAuth behavior for this phase. Do not add unrequested product features.

## Mandatory replacement scope and monorepo isolation

The user explicitly authorizes removing all existing application logic in the target Flutter package, including the already implemented real sign-in/authentication flow. This is a replacement, not an incremental integration with the old application.

- Remove the previous Flutter UI, state management, models, repositories, services, networking, business rules, auth/token handling, OAuth callbacks, routes and obsolete application tests. Replace them with the new implementation described here. Do not retain the old sign-in behind a flag, adapt it, or use it as a behavioral reference. Remove unused runtime dependencies and Flutter-local auth initialization/configuration/hooks as appropriate. Regenerate plugin artifacts using normal tooling rather than hand-editing generated files.
- Retain only build/platform scaffolding, package identity, assets and tooling configuration that are still necessary or useful. Remove application behavior embedded in that scaffolding, such as real OAuth deep-link handlers. Preserve unrelated pre-existing user changes; do not use a blanket git reset/clean or delete the package directory. Limit removals to this authorized application replacement.
- Ignore the implementation logic in the monorepo's server and shared code. Do not read those source trees, import their models, copy their validation rules, discover their endpoints, generate a client from them, or let their contracts shape this prototype. Define new Flutter-local models and repository/service interfaces from this handoff alone.
- Do not edit, delete or refactor server or shared files. Root-level changes are outside scope unless strictly required to build this Flutter package. Read only minimal workspace/build metadata when necessary for package resolution; this exception does not authorize reading server/shared application source. Explain any unavoidable root metadata change in the final report.
- Respect applicable repository instructions, but do not interpret existing server/shared domain behavior or the old Flutter implementation as requirements. This brief and the approved UX documents define the new application behavior.
- Inspect paths, Flutter build metadata and git status only as needed to establish the target and scoped replacement. If the package directory is unambiguous from the working directory/pubspec.yaml, proceed without asking permission again. Do not run monorepo-wide searches or tests that pull server/shared logic into the task.
- Before completion, confirm that no active Flutter runtime imports or executes the old application logic, shared package logic, real auth or networking. List what was removed and what scaffolding was retained. Do not claim to have changed server/shared code.

## Mandatory Flutter architecture

Follow the official Flutter architecture guidance, adapted to this app. Strong layering with distinct Repositories and Services is a requirement, even for this mocked prototype. Architecture must be enforced by dependencies and tests, not just folder names.

References:

- https://docs.flutter.dev/app-architecture/guide
- https://docs.flutter.dev/app-architecture/recommendations
- https://docs.flutter.dev/app-architecture/case-study/data-layer

Use the following responsibilities and boundaries:

| Component | Owns | Must not do |
| --- | --- | --- |
| Views/widgets | Material rendering, layout, focus/controllers, displaying state, forwarding user actions | Access Services/storage directly, instantiate concrete repositories, mutate shared application records, calculate maintenance rules |
| ViewModels | Screen state, user commands, presentation validation/error mapping, asynchronous command lifecycle | Call platform storage, real/fake data-source Services or other ViewModels directly; duplicate domain rules |
| Domain models and focused policies/use cases | Immutable application models, maintenance/odometer rules, reusable computations and orchestration when needed | Depend on widgets, platform plugins, concrete data implementations, server/shared packages |
| Repository interfaces and implementations | Source of truth for logical app data, mutations, model mapping, caching/observation, consistency and error propagation | Know about widgets/BuildContext, expose mutable internal collections, become thin aliases to Services with ownership left in ViewModels |
| Data-source Services | Narrow asynchronous interfaces to mock authentication and local persistence; serialization at the storage boundary | Own screen state, navigation, maintenance policy, or act as a second observable application state store |
| Composition root | Construct Services, repository implementations, policies/use cases and ViewModels; wire navigation and dependencies | Hide mutable state in arbitrary globals or perform business operations in main.dart |

Concretely:

1. Use MVVM with one feature/screen ViewModel where appropriate. ChangeNotifier/Listenable or an equivalently explicit state mechanism is acceptable; choose one consistent approach and document it. Keep UI code declarative. Do not put the app in one main.dart file.
2. Define abstract repository contracts and separate concrete mock/local implementations. Use cohesive aggregate boundaries, for example AuthRepository, VehicleMaintenanceRepository (vehicles, schedules and their service history), and SettingsRepository. If splitting maintenance into several repositories, document how cross-record operations stay atomic and consistent. Do not make repositories call each other opportunistically or duplicate their caches.
3. Define separate Service interfaces and implementations, for example MockAuthService and LocalPersistenceService. Services can wrap the chosen local storage plugin; only Services may import/call its I/O API. Repository implementations consume these interfaces by constructor injection. No widget or ViewModel may bypass the repository layer to reach a Service.
4. Keep repository contracts and immutable models independent of Flutter presentation. The production replacement seam is explicit: future server/auth integrations replace data-layer implementations behind the contracts, without rewriting Views or ViewModels. No production HTTP/auth implementation is required now.
5. Extract scheduling calculations and odometer validation into testable pure-Dart policies. Use focused use cases where operations coordinate repositories or would otherwise duplicate rules across ViewModels. Do not generate an empty use-case class for every trivial getter.
6. The maintenance repository is responsible for observable consistency after a write: save/edit/delete service or archive/restore item updates derived due data and affected screens. Delegate rule calculations to the domain policies. Creating a vehicle and its first mileage-only record is atomic. Use immutable snapshots/copy-on-write to avoid UI mutation leaks.
7. Use explicit asynchronous result/error semantics consistently. Distinguish validation failure, simulated connectivity failure, missing data and persistence failure. Handle loading, command disabling, retries, disposal and subscription lifecycles. ViewModels expose actionable state without leaking low-level storage exceptions into widgets.
8. Inject dependencies through constructors and wire them in a composition root. Inject a clock, ID generator and simulated connectivity/latency behavior for deterministic tests. Use feature-scoped ViewModel lifetimes and app-scoped repositories/services where appropriate; avoid hidden service-locator calls inside Views/ViewModels.
9. Local persistence belongs behind a Service; repositories decide seeding, account scoping, invalidation and reset behavior. Mock sign-in goes through the new AuthRepository and mock authentication Service, never the old sign-in flow. Server address is local configuration through SettingsRepository and a local persistence Service; it is never contacted.
10. Add an ARCHITECTURE.md describing concrete responsibilities, allowed dependency directions, aggregate choices, mutation/recalculation flow, dependency injection, storage and the future backend replacement seam. Map the actual files/classes to those roles. Explain architecture decisions briefly before implementation, then proceed to build and verify without waiting for approval.

Recommended organization (adapt names to the package, preserving boundaries): lib/app/ for bootstrap/theme/router/composition; lib/ui/<feature>/ for Views and ViewModels; lib/domain/ for immutable models, repository contracts, policies and focused use cases; lib/data/repositories/ for implementations; lib/data/services/ for Service interfaces and implementations. Test layers separately. Do not build a generic framework; implement these boundaries concretely for TW.

## Visual implementation

- Use Flutter's material library, MaterialApp, ThemeData and a coherent Material 3 ColorScheme. Use Material typography, spacing, icons, controls, focus states, dialogs and feedback instead of reproducing the HTML's monochrome borders or browser controls. Choose one restrained seed color. Support the system light/dark appearance.
- Keep the layout and information hierarchy recognizable from the wireframe. Add vehicle belongs after the last vehicle in the scrollable Vehicles list, or below the empty-state message when there are no vehicles. Do not put it in the top app bar or a floating button. There are no vehicle-level overdue/due-soon count badges.
- Each vehicle previews at most three due maintenance items: overdue first, then due soon. Preserve per-item status. Show “{count} more...” only for remaining items; it opens that vehicle's Due tab.
- Bottom NavigationBar: exactly Vehicles and Settings. Show it throughout the signed-in shell, including nested screens, and hide it while signed out. Vehicles opens the garage. Settings has only one field, Server address, with http://localhost:8080 as the initial value, plus Save.
- Vehicle-local Due / Schedule / History navigation remains separate: tabs on compact screens and a local rail on wide screens. Use width-based layout, not OS-based layout. Start with the spec's suggested breakpoints; prefer those over the HTML's coarse preview breakpoint.
- Build responsive layouts for phone and desktop, including text scaling, safe areas, keyboards and mouse/keyboard input. Make action placement consistent. Use full-screen/constrained form routes as specified.

## Mocking and functional scope

- No app network requests, HTTP clients, actual server calls, real Google OAuth, Firebase setup or credentials. The Server address field is saved locally and never contacted. Package installation during development is separate from application networking.
- Simulate Google sign-in using the sign-in button and a fake identity. Do not launch a browser or Google account picker. Remember this mock sign-in state across app restarts. Sign out returns to the sign-in screen and clears account-scoped cached maintenance data as in the spec. The demo may re-seed the same fixtures at the next mock sign-in. Make the simulated nature clear in the project README without adding extra product fields.
- Implement Vehicles, add/edit vehicle, Due, Schedule, archived items/restore, schedule-item details/history, add/edit schedule item, service history/details, log/edit/delete service, Settings and the account/sign-out menu.
- All forms and actions must update a shared local data model. Do not copy the reference's illustrative save toasts that leave records unchanged. Support custom operations and mileage-only services.
- Persist mock session and settings between launches. Persist mocked maintenance records locally too, so a restart does not discard recorded work; document how to reset demo data. Keep persistence simple and cross-platform, behind the repository boundary.
- Implement the mandatory architecture above. The mocked nature of the app is not permission to collapse Services into Repositories or put data/business logic in ViewModels/widgets. Add dependencies only for concrete needs.
- Use simulated short delays for async load/save feedback. Represent loading, empty, error and cached/offline states with a documented test/demo mechanism outside normal product navigation; do not add extra Settings fields or copy the wireframe review toolbar.
- Show overdue and due-soon examples, a vehicle with more than three due items, one with fewer, mileage-only history, linked and custom operations, and archived items. Compute seed dates relative to an injectable clock so fixtures remain useful after October 2026. Include both miles and kilometers in fixtures.
- The fake repository supplies a deterministic estimated odometer and clearly labels it Estimated; do not design a production estimator in this phase. Keep that estimate consistent with accepted actual readings, and recalculate derived status after writes. Keep a predictable offline/as-of snapshot.

## Rules to preserve

- A month is exactly 30 days. N months means N × 30 days. Due soon means within 30 days or within 1,000 of the vehicle's distance units. Reaching either exact limit is overdue. Count each item once.
- A vehicle's units are chosen at creation and cannot be edited. Linked service history shows an item's current description after renaming. Custom operation text does not change when schedule items are renamed.
- Without a linked completion, use manufacture date and zero distance as the maintenance baseline. A mileage-only entry updates mileage but never resets maintenance.
- Service date and actual mileage are required. Default date to today; leave mileage blank and show the estimate as a hint. Reject future dates and readings inconsistent with chronological neighbors. Allow equal mileage.
- Suggest overdue items only for today's service, initially unchecked; make other active items available below. Hide suggestions for past dates while retaining selections. Users can save zero operations.
- All seven defaults in section 3 of the UX spec are approved. Preserve them, including same-day ordering, archive selection rules and dirty-form protection.

## Verification and delivery

Run dart format, flutter analyze and focused Flutter tests scoped to the target Flutter package. Test domain boundary rules and meaningful interaction flows: mock login persistence, preview/more navigation, mileage-only save, past-date suggestions, edit/delete recalculation and archive/restore. Test Services with fake storage boundaries, repositories with fake Services, ViewModels with fake repositories, and widgets with controlled ViewModels/dependencies. Verify persistence round-trips, account scoping and consistent derived data after mutations. Add an import/dependency-boundary check where practical, including absence of server/shared runtime imports and old real-auth integrations. Test narrow/wide rendering for overflow where tooling permits. Remove obsolete tests for the replaced application; keep/add relevant tests for the new architecture and behavior.

Run or build the web target to check that this is an actual working Flutter app. Inspect rendered phone/wide layouts if a browser or device is available; otherwise state that limitation. Do not claim to have validated native platforms unavailable on this host. Cross-platform source does not imply every native target has been built.

Finish with working code, ARCHITECTURE.md, a concise README explaining mocked behavior and reset/run instructions, a summary of removed legacy logic, checks run and their results, and remaining limitations. Report concrete blockers rather than silently skipping screens. Do not wait for approval between ordinary reversible implementation steps.

## Local commands

Open a terminal inside the existing monorepo's Flutter application package (the directory containing its Flutter pubspec.yaml). Extract the handoff there, then start the coding agent:

```sh
codex
```

Suggested first message:

> Read README-CODEX.md and its referenced UX files. In this existing Flutter package, replace all previous application logic, including the real sign-in implementation, with the TorqueWrench mocked Material 3 prototype. Do not use or modify server/shared application code. Follow the mandatory layered architecture with distinct Views, ViewModels, repository contracts/implementations and data-source Services. Implement, run the scoped checks and tell me how to launch it. Do not stop at a plan.

Preview the implemented app:

```sh
flutter run -d chrome
```
