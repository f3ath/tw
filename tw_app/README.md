# Torque Wrench — learning project

Session handover for `tw_app/`. Read this before continuing; inspect current source for changes made between sessions.

## Working agreement

- The user is a professional Dart developer learning Flutter and mobile development.
- Teach through small exercises: explain concepts and tradeoffs, define an observable checkpoint, then review the user's implementation.
- The user writes application code. Do not implement features or provide complete solutions unless asked. Documentation updates are authorized.
- Tests are the source of truth for behavior. Add meaningful tests alongside features, using controlled futures/time for asynchronous behavior. Prefer TDD where it makes sense.
- Do not add dedicated tests for InMemory repositories. Use them as test doubles in application, view-model, and widget behavior tests.
- Use `../app_proto/` as a reference, not a template to copy. Introduce abstractions through concrete needs.
- Do not add widget previews; the user prefers to omit them.

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
- Use ports/adapters. Application logic and its tests depend on semantic ports, not HTTP messages or TwApiClient. Repository types use singular resource names (VehicleRepo, ScheduleRepo) and methods list/create/update/delete where supported; backend adapters translate to TwApiClient’s resource-specific method names.
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
- GarageScreen owns/disposes ListViewModel<Vehicle>. VehicleCard owns card/menu rendering and emits actions; navigation, deletion feedback, and refresh remain in the screen. GarageScreen.vehicleCardKey supplies list-item identity.
- Deletion refreshes after both success and exceptions because a lost response can leave the outcome uncertain. Exceptions show “Could not confirm deletion. Refreshing...”. Cancellation skips deletion and refresh. Manage schedules opens ScheduleScreen for the selected vehicle; Back returns without reloading the garage. Its title shows the schedules icon and vehicle name. Due-services content is a placeholder.
- VehicleFormScreen shares create/edit validation and submission/error handling, with persistence extracted into a private method. Both forms use SafeArea with a ListView, 10-pixel padding, and a 16-pixel gap before Save. VehicleFormScreen disables name/unit/date inputs while saving and guards repeat submissions, matching schedule submission behavior. DateFormField provides typed date selection and supports enabled/disabled state.
- TestRobot contains shared utilities; WelcomeRobot, GarageRobot, and VehicleFormRobot own screen-specific interactions. Robot APIs use tapNewVehicle/tapNewSchedule, findVehicleCard/findScheduleCard, and tapRetry. New-form navigation defaults to PumpMode.settle; submission/retry defaults to frame, and text entry pumps one frame. Date/menu/dropdown transitions settle. PumpMode selects none/frame/settle. Menu and dropdown finders target typed, hit-testable entries.
- ScheduleRepo.list(vehicleId) is wired through main → TwApp → GarageScreen → ScheduleScreen. BackendScheduleRepo delegates to TwApiClient; ListViewModel<Schedule> owns loading/error/list state and is disposed with the screen. Rows show schedule names and optional details, with loading, error/retry, and empty states.
- InMemoryScheduleRepo defaults to empty, accepts initialSchedules, filters by vehicle ID, counts list calls, and supports one-request pauseNextList and pauseNextCreate gates. ScheduleRepo.create(vehicleId, ...) is implemented by both adapters, returning Future<void>; the backend delegates to TwApiClient.createSchedule. The fake generates unique IDs without overwriting seeds. Sample schedules seed the fake backend and tests. Widget tests cover vehicle filtering, loading, empty results, retry, rebuild behavior, pending-request disposal, and garage navigation.
- InMemoryVehicleRepo defaults to empty and accepts initialVehicles. pauseNextList/Create/Delete gates affect one request each. Sample users/vehicles live in lib/testing/samples.dart; the test harness and fake-backend setup seed explicitly.
- Latest verification: all **136 tw_app tests pass** after extracting ListViewModel<T>; static analysis is clean. Builds were not rerun.

## Next exercise

Schedule creation is wired end to end. ScheduleFormScreen validates a nonblank name, positive whole-number intervals, and at least one interval, matching server rules. Optional blank intervals become null; name/details are trimmed. Save and fields are disabled while pending, exceptions show a keyed snackbar and retain inputs for retry, and success returns true so ScheduleScreen reloads. Back/cancellation does not reload. Edit opens prefilled fields and saves through ScheduleRepo.update(scheduleId, ...), sharing validation and submission feedback with creation. BackendScheduleRepo delegates to TwApiClient.updateSchedule; the in-memory implementation preserves ID, vehicle association, and archive state, and supports pauseNextUpdate(). Cleared intervals are sent as null, and cleared details as an empty string. Form widget tests in schedule_form_screen_test.dart cover submission results, validation, clearing either interval, and failure/retry without creating another schedule. Schedule-screen tests retain list/navigation behavior and a successful creation/list-refresh flow. Delete opens a keyed confirmation dialog naming the selected schedule. Cancel/dismiss maps to false and Delete to true. Confirmed deletion invokes ScheduleRepo.delete and reconciles the list after success or exceptions. Exceptions show a keyed “Could not confirm deletion. Refreshing...” snackbar; cancellation skips deletion and refresh. Mounted checks guard the post-dialog request and subsequent UI work.

Schedule deletion and its widget coverage are complete for this iteration. Tests cover Cancel and dismissal without refresh, targeted deletion preserving other schedules, deleting the final schedule, and error feedback/reconciliation for both retained and already-deleted outcomes. VehicleDeleteDialog and ScheduleDeleteDialog own confirmation presentation and their static dialog/button keys. Screens invoke showDialog and retain repository deletion, error feedback, and refresh responsibilities. Key values are preserved. Stable keys identify state messages, confirmation dialogs, and buttons; dialog wording is not asserted.

ServiceRepo.list(vehicleId) is implemented by BackendServiceRepo (delegating to TwApiClient.listServices) and InMemoryServiceRepo. The fake defaults to empty, accepts initialServices, filters by vehicle ID, counts list calls, and supports a one-request pauseNextList gate. ServiceScreen, ListViewModel<Service>, and ServiceCard now provide a standalone list UI with selected-vehicle loading, error/retry, empty state, and keyed cards. Cards show localized short dates (including year), grouped odometer readings in the vehicle’s unit, and optional details. ServiceRobot, a local test harness, and sample services support widget coverage for filtering, both units, retry, rebuild behavior, and disposal during pending success/failure. No previews were added. ServiceRepo is wired through main → TwApp → GarageScreen → ServiceScreen. The vehicle menu’s Services action opens that vehicle’s history, and Back returns without reloading the garage. Fake mode seeds sampleServices; real mode shares the existing TwApiClient through BackendServiceRepo. Garage navigation tests cover both sample vehicles.

ServiceFormScreen is a shared creation/editing form with date (initially clock.now()), odometer in the vehicle’s distance unit, and optional details. It uses DateFormField, stable field/button keys, and the same SafeArea/ListView layout as the other forms. The New Service floating button opens the form for the selected vehicle, following ScheduleScreen navigation. Back preserves the existing list without reloading. Validation requires a date and a nonnegative whole-number odometer (zero is valid). DateFormField owns the shared picker bounds, January 1, 1900 through January 1, 2100; forms do not supply their own bounds. The app has no seven-day future-date validation; the server still enforces its existing seven-day limit for services. Details remain optional and are trimmed into submission data without changing the entered text. An optional service prefills date, odometer, and details and changes the title to Edit Service. Save validates and creates or updates through ServiceRepo, with shared submission/error handling and a private persistence method. Date, odometer, details, and Save are disabled while pending; a guard prevents repeat submission before rebuild. Exceptions show a keyed snackbar and retain inputs for retry. Success returns true so ServiceScreen reloads; Back returns without refreshing. Mounted checks protect completion after leaving the form. Service-form tests use ServiceFormRobot for descriptive actions and state queries, with the same PumpMode defaults as existing form robots. A direct route harness captures results. lib/testing/fixed_clock.dart provides a configurable FixedClock shared by service-form, vehicle-form, and garage-screen tests; authentication timeout tests retain their advancing clock mock. Tests cover validation, submitted values, pending state, duplicate-save prevention, failure/retry, cancellation, and disposal during pending success/failure. The service-screen suite covers successful creation/list refresh. No previews were added.

ServiceRepo.create(vehicleId, date:, odometer:, details:) now returns Future<void>. BackendServiceRepo delegates to TwApiClient.createService; InMemoryServiceRepo stores the supplied values with unique IDs that skip seeded entries and supports pauseNextCreate() for pending/failure scenarios. Creation is wired through ServiceScreen to ServiceFormScreen.

ServiceRepo.update(serviceId, date:, odometer:, details:) returns Future<void>, with required details so an empty string explicitly clears them. BackendServiceRepo delegates to TwApiClient.updateService. InMemoryServiceRepo preserves service ID and vehicle association, throws StateError for missing IDs, and supports a one-request pauseNextUpdate() gate. ServiceCard now exposes a keyed typed menu with an Edit action; ServiceScreen opens the selected service in ServiceFormScreen and reloads history only after a true result. Back and failed saves do not refresh. ServiceRobot provides tapServiceMenuEdit with typed, hit-testable menu selection. Service-screen tests cover targeted prefilling/Back, updating one of several services with a paused refresh, and failed editing followed by successful retry across both distance units. Robot-based form tests cover both units, prefilled values, preserved identity/vehicle association, clearing details, pending fields and repeat submission, validation, cancellation, and update failure/retry.

ServiceRepo.delete(serviceId) is implemented by BackendServiceRepo through TwApiClient.deleteService and by InMemoryServiceRepo through a one-request RequestGate, with pauseNextDelete() and deleteCalls. The service-card Delete action opens ServiceDeleteDialog, identifying the service by localized date and odometer/unit. The dialog owns stable confirmation/cancel/delete keys; ServiceScreen owns deletion, feedback, and list reconciliation. Cancel/dismiss skips deletion and refresh. Confirmed deletion reloads after success or exceptions; exceptions show the keyed “Could not confirm deletion. Refreshing...” snackbar. Mounted checks guard requests after confirmation and UI work after deletion. ServiceRobot provides typed menu selection and descriptive confirmation/cancellation/dismissal methods. Widget tests cover cancellation, dismissal, targeted deletion preserving other services, the final-service empty state, both retained and already-deleted failure outcomes, and disposal while deletion later succeeds/fails.

VehicleCard has a visible keyed New Service button that emits VehicleAction.newService. GarageScreen owns navigation directly to ServiceFormScreen with the selected vehicle, ServiceRepo, and shared Clock. Saving or cancelling returns to the garage without reloading vehicles while due-services content remains a placeholder. GarageRobot.tapVehicleNewService(id) targets the per-vehicle button; garage widget tests cover both distance units, Back without creation/refresh, and saving a service that appears in the selected vehicle’s history.

OperationRepo.list(serviceId) returns Future<List<Operation>>. BackendOperationRepo delegates to TwApiClient.listOperations. InMemoryOperationRepo defaults to empty, accepts initialOperations, filters by service ID, counts list calls, and supports pauseNextList() through RequestGate. OperationRepo is required through main → TwApp → GarageScreen → ServiceScreen → OperationScreen. Real mode shares TwApiClient through BackendOperationRepo; fake mode explicitly seeds sampleOperations. No dedicated fake/adapter tests were added, following the working agreement.

OperationScreen, ListViewModel<Operation>, and OperationCard provide a service-scoped list with keyed loading, error/retry, empty, and card states. The title shows an operations icon and the localized service date. Cards show operation names and optional details for both scheduled and custom operations. The screen owns/disposes the view model, which loads once and suppresses notifications after disposal. OperationRobot, a local harness, and sampleOperations support eight widget tests covering selected-service filtering, optional details, empty results, retry, rebuild behavior, and disposal during pending success/failure. No previews were added. Tapping a service card’s ListTile emits ServiceAction.operations; ServiceScreen owns navigation to OperationScreen. Operations is not a menu item; Edit/Delete retain their menu behavior. ServiceRobot.tapServiceCard(id) ensures the card is visible and uses the standard PumpMode defaults. Back returns without reloading service history. Service-screen navigation tests target both sample services with another service of the same vehicle present, and a TwApp test verifies login → garage → service history → operations and Back without list reloads.

OperationRepo.create(serviceId, name:, details:) returns Future<void>, with required name and details defaulting to an empty string. BackendOperationRepo delegates to TwApiClient.createOperation without a schedule ID. InMemoryOperationRepo preserves the supplied values, generates unique IDs that skip seeded entries, leaves scheduleId null, and supports pauseNextCreate() through RequestGate. Creation is not yet wired to a form.

Recommended next: OperationFormScreen with a required trimmed name and optional trimmed details, followed by New Operation navigation and submission/list refresh. Scheduled-operation creation and operation editing/deletion remain planned.

Vehicle form tests now live in test/ui/garage/vehicle_form_screen_test.dart with a direct route harness that captures results. They cover isolated validation, creation values, pending-field disabling, creation failure/retry, edit identity/unit preservation, and edit failure/retry. Garage tests retain navigation and list refresh. InMemoryVehicleRepo supports pauseNextUpdate for application behavior tests. A remaining vehicle-test gap is deletion that succeeds server-side before the response fails. Both in-memory repositories use incrementing ID counters and skip existing IDs.

All in-memory repository pauseNext methods delegate to per-operation RequestGate instances in lib/testing/request_gate.dart. The helper consumes and clears the pending future before awaiting it, so only the next request pauses; errors propagate before reads/mutations. Named pause methods and call counters remain on the repositories.

GarageScreen, ScheduleScreen, ServiceScreen, and OperationScreen use ListViewModel<T> from lib/ui/list_view_model.dart directly, providing repository fetch callbacks. It exposes items/isLoading/hasError/load(), copies loaded results into an unmodifiable list, clears errors on load, and suppresses completion notifications after disposal. Each screen owns model creation, initial loading, disposal, and its existing UI/navigation/mutation behavior. The four resource-specific view models were removed. Their existing screen tests remain; the garage view-model tests moved to test/ui/list_view_model_test.dart with an added immutable-results assertion.

## Next iteration — deferred work

- Pull-to-refresh
- Clean up old server sessions, including sessions left behind by failed revocation; define policy/mechanism then.
- Finish auth lifecycle/error handling and retained-credential cleanup. Local logout currently clears displayed User before revocation, but failure handling and credential cleanup remain incomplete.
- Resolve HTTP client lifetime ownership. AuthService and VehicleRepo ports now live in standalone files under lib/app/.
- Revisit name-width constraints and long-name layout checks, explicitly deferred by the user.

Offline mode, synchronization, and advanced network behavior are not committed next-iteration features.

## Maintaining this handover

Replace current-state and next-exercise notes as work progresses; do not append detailed session history. Record meaningful decisions, outstanding limitations, and the latest verification. Distinguish completed behavior from planned work and check source before repeating old review findings.
