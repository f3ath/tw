# TorqueWrench architecture

This Material 3 application uses server-backed authentication and maintenance data through the shared TwApiClient. The original prototype brief is retained in README-CODEX.md; the API implementation supersedes its mock-only restrictions. The implementation follows Flutter's [architecture guide](https://docs.flutter.dev/app-architecture/guide), [recommendations](https://docs.flutter.dev/app-architecture/recommendations), and [data-layer case study](https://docs.flutter.dev/app-architecture/case-study/data-layer).

## Dependencies and concrete responsibilities

```
Views → ChangeNotifier ViewModels → repository contracts → immutable domain models
                              ↘ focused session use case → repository contracts
API repository → domain policies + API/persistence services
Platform persistence service → shared_preferences
Composition root → constructs and injects all implementations
```

- `lib/domain/models.dart`: reexports shared Vehicle, Schedule, Service and Operation DTOs from `package:shared/model.dart`; retains Garage, typed AppFailure/FailureKind, date-only helpers and edit comparisons. Aggregate collections are defensively copied and unmodifiable.
- `lib/domain/repositories.dart`: pure Dart AuthRepository, SettingsRepository and VehicleMaintenanceRepository contracts. No Flutter, storage plugin or network client imports.
- `lib/domain/policies.dart`: SchedulingPolicy owns latest linked completion selection, 30-day intervals, OR thresholds, inclusive overdue/soon boundaries, due ordering and unknown-distance treatment. ValidationPolicy owns vehicle, interval, archived-link and chronological mileage rules. Date comparisons count calendar days, including across daylight-saving transitions. Same-day service order is date, mileage, then stable identifier. Equality is permitted.
- `lib/domain/session_use_case.dart`: SessionUseCase coordinates authentication and account aggregate opening/clearing. Repositories never call one another.
- `lib/data/services/services.dart`: separate AuthenticationService, LocalPersistenceService and Simulation contracts; MockAuthService returns a fake identity, PreferencesPersistenceService wraps SharedPreferencesAsync and JSON encoding, DemoSimulation supplies injectable latency/connectivity/failure behavior. Only this service imports the storage plugin. It owns no observable maintenance or screen state.
- `lib/data/services/api_auth_service.dart`: builds TwApiClient from saved Settings, adapts HTTP transport, creates/polls/restores/revokes sessions, persists bearer credentials with their server URL, and maps request/storage failures. OAuth browser adapters reserve a popup synchronously on web and launch the external browser on native platforms.
- `lib/data/repositories/api_auth_repository.dart`: owns the active identity and exposes server authentication behind AuthRepository. Composition.local uses this implementation and shares the authenticated service with maintenance requests. LocalAuthRepository/MockAuthService are retained for isolated demo/widget fixtures.
- `lib/data/services/api_maintenance_service.dart`: wraps typed TwApiClient collection and mutation methods using the active authenticated client. It assembles all vehicle schedules, services and operations for a garage read.
- `lib/data/repositories/api_maintenance_repository.dart`: owns the active garage, account-scoped cache, validation, stale-edit checks and sequential API writes. Publishes snapshots through the repository stream and returns server IDs from saves.
- `lib/data/services/garage_codec.dart`: explicit raw JSON/domain mapping at the storage boundary. No schedule calculations in serialization.
- `lib/data/repositories/local_repositories.dart`: LocalAuthRepository persists session identity; LocalSettingsRepository validates and persists the server address; LocalMaintenanceRepository retains seeding and atomic local saves for test fixtures. Services are constructor-injected.
- `lib/ui/core/command_view_model.dart`: shared command lifecycle, repeated-submit guard, typed errors and disposed-notifier protection.
- `lib/ui/session/session_view_model.dart`: session restoration/sign-in/sign-out and simulated expiry state.
- `lib/ui/garage/garage_view_model.dart`: observable garage/vehicle/item/history projections, policies for presentation, archive/delete/refresh commands. Cancels its repository subscription on disposal.
- `lib/ui/forms/form_view_models.dart`: feature-scoped vehicle, item, service and settings drafts; parsing, field errors, dirty state, save commands. Only repository contracts are injected. Today's suggestions and past-date regrouping retain selection/custom drafts. Required actual mileage is never taken from the estimate.
- `lib/ui/forms/form_views.dart`, `lib/ui/garage/garage_views.dart`: Material rendering, controllers, input forwarding and width-based layout. Views never instantiate repositories or access Services. Tabs below 840px; a vehicle-local rail at 840px and above. Forms constrain to 640px; details to 760px. All scroll above the persistent global NavigationBar.
- `lib/app/composition.dart`: explicit dependency construction, injectable clock and ID generator, app-scoped repositories/Services and ViewModels, form factories. Developer simulation controls live here, outside product navigation.
- `lib/app/torque_wrench_app.dart`: theme, authentication route, RouterDelegate/parser, signed-in shell, form lifetime ownership, discard/destructive dialogs, route composition. Deep links are validated against the opened account snapshot. Reauthentication overlays the retained shell, preserving running-session drafts. Popped drafts dispose after their widgets leave the frame.
- `lib/main.dart`: binding initialization and composition only.

## Maintenance aggregate and publication

Vehicles, schedules, service history and operations form one immutable garage snapshot. One repository assembles the full snapshot from API collections and derives due status locally. Each mutation:

1. Acquires a repository write guard and refreshes current server data.
2. Validates the draft and compares expected original records and operations for stale edits.
3. Calls the typed API endpoints. Creation returns server IDs. Service edits preserve operation IDs, add new operations, update changed custom operations and delete removed operations. Blank custom drafts are filtered before submission.
4. Reloads the server collections, publishes the new snapshot, and caches it.

These requests are sequential; combined service/operation saves and vehicle/initial-reading creation are not atomic. Partial-save recovery is deferred. Refreshed comparisons detect existing changes but do not provide server-enforced conditional writes.

Mileage-only/custom operations never reset scheduled baselines. Linked historical names resolve through the current item. Archived items remain in history and are excluded from due/new selections. Existing archived links are retained on service edits. Restore reuses their linked completions. The mock estimate is exactly the latest accepted actual reading; deleting the last reading produces unknown mileage while date calculations continue.

## Storage, scoping and recovery

Preferences store session credentials, Settings and `api.garage.<server URL>/<user ID>` snapshots under the existing `tw.v1.` prefix. Account changes clear in-memory data before loading the next account. Sign-out removes the local cache while preserving server records and global Settings.

A connectivity failure while loading maintenance data can fall back to a cached snapshot with its original as-of date. Writes remain disabled until refresh succeeds. Startup session restoration still validates credentials online. Authentication failures during maintenance requests open reauthentication and retain the running draft. Services map HTTP failures to authentication, validation, conflict, missing or connectivity failures; persistence failures remain separate. Server responses currently have limited validation detail, so client policies provide field-specific messages where possible.

The default composition constructs ApiAuthRepository and ApiMaintenanceRepository with a shared ApiAuthService. Local repositories and simulations remain available for deterministic tests. API URLs and bearer state remain in Services, and credentials stay bound to their original server even after Settings changes.

## Verification

Tests separate pure policies, repositories with fake Services, persistence Service with a fake preferences boundary, ViewModels with fake repositories, and widgets with injected Composition/ViewModels. `test/boundaries_test.dart` enforces imports, including no concrete data/Service imports in UI, no Flutter/data imports in domain, storage-plugin imports confined to Services and network/browser imports confined to Services, with shared model-only imports permitted in other layers. API repository tests also run against localhost:8080 with TestOAuth. See README for scoped commands and platform limitations.

## Verified native compatibility

The Apple storage implementation is constrained to `shared_preferences_foundation: 2.5.7` for Xcode 16 compatibility; no plugin cache or generated Swift was patched. macOS release compilation and live session/data persistence work through the same PreferencesPersistenceService used on web. Normal Flutter tooling regenerates plugin registrations. Unsigned iOS release compilation and live simulator sign-in/service save also pass with iOS 18 installed. See README for per-platform results and signing limitations.
