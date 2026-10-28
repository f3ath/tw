# TorqueWrench architecture

This Material 3 application uses server-backed authentication through the shared TwApiClient and local demo maintenance data. The original prototype brief is retained in README-CODEX.md; the current authentication implementation supersedes its mock-only restrictions. The implementation follows Flutter's [architecture guide](https://docs.flutter.dev/app-architecture/guide), [recommendations](https://docs.flutter.dev/app-architecture/recommendations), and [data-layer case study](https://docs.flutter.dev/app-architecture/case-study/data-layer).

## Dependencies and concrete responsibilities

```
Views → ChangeNotifier ViewModels → repository contracts → immutable domain models
                              ↘ focused session use case → repository contracts
Local repository implementations → domain policies + data-source service interfaces
Platform persistence service → shared_preferences
Composition root → constructs and injects all implementations
```

- `lib/domain/models.dart`: immutable Vehicle, MaintenanceItem, ServiceRecord, Garage, typed AppFailure/FailureKind, date-only helpers, structural record comparisons. Collections are defensively copied and unmodifiable. Small hand-written value classes avoid code generation for this prototype.
- `lib/domain/repositories.dart`: pure Dart AuthRepository, SettingsRepository and VehicleMaintenanceRepository contracts. No Flutter, storage plugin, network client, or monorepo shared imports.
- `lib/domain/policies.dart`: SchedulingPolicy owns latest linked completion selection, 30-day intervals, OR thresholds, inclusive overdue/soon boundaries, due ordering and unknown-distance treatment. ValidationPolicy owns vehicle, interval, archived-link and chronological mileage rules. Date comparisons count calendar days, including across daylight-saving transitions. Same-day service order is date, mileage, then stable identifier. Equality is permitted.
- `lib/domain/session_use_case.dart`: SessionUseCase coordinates authentication and account aggregate opening/clearing. Repositories never call one another.
- `lib/data/services/services.dart`: separate AuthenticationService, LocalPersistenceService and Simulation contracts; MockAuthService returns a fake identity, PreferencesPersistenceService wraps SharedPreferencesAsync and JSON encoding, DemoSimulation supplies injectable latency/connectivity/failure behavior. Only this service imports the storage plugin. It owns no observable maintenance or screen state.
- `lib/data/services/api_auth_service.dart`: builds TwApiClient from saved Settings, adapts HTTP transport, creates/polls/restores/revokes sessions, persists bearer credentials with their server URL, and maps request/storage failures. OAuth browser adapters reserve a popup synchronously on web and launch the external browser on native platforms.
- `lib/data/repositories/api_auth_repository.dart`: owns the active identity and exposes server authentication behind AuthRepository. Composition.local uses this implementation. LocalAuthRepository/MockAuthService are retained for isolated demo/widget fixtures.
- `lib/data/services/garage_codec.dart`: explicit raw JSON/domain mapping at the storage boundary. No schedule calculations in serialization.
- `lib/data/repositories/local_repositories.dart`: LocalAuthRepository persists session identity; LocalSettingsRepository validates and persists the server address; LocalMaintenanceRepository owns seeding, account cache, mutation serialization, validation, snapshot publication and error mapping. Services are constructor-injected.
- `lib/ui/core/command_view_model.dart`: shared command lifecycle, repeated-submit guard, typed errors and disposed-notifier protection.
- `lib/ui/session/session_view_model.dart`: session restoration/sign-in/sign-out and simulated expiry state.
- `lib/ui/garage/garage_view_model.dart`: observable garage/vehicle/item/history projections, policies for presentation, archive/delete/refresh commands. Cancels its repository subscription on disposal.
- `lib/ui/forms/form_view_models.dart`: feature-scoped vehicle, item, service and settings drafts; parsing, field errors, dirty state, save commands. Only repository contracts are injected. Today's suggestions and past-date regrouping retain selection/custom drafts. Required actual mileage is never taken from the estimate.
- `lib/ui/forms/form_views.dart`, `lib/ui/garage/garage_views.dart`: Material rendering, controllers, input forwarding and width-based layout. Views never instantiate repositories or access Services. Tabs below 840px; a vehicle-local rail at 840px and above. Forms constrain to 640px; details to 760px. All scroll above the persistent global NavigationBar.
- `lib/app/composition.dart`: explicit dependency construction, injectable clock and ID generator, app-scoped repositories/Services and ViewModels, form factories. Developer simulation controls live here, outside product navigation.
- `lib/app/torque_wrench_app.dart`: theme, authentication route, RouterDelegate/parser, signed-in shell, form lifetime ownership, discard/destructive dialogs, route composition. Deep links are validated against the opened account snapshot. Reauthentication overlays the retained shell, preserving running-session drafts. Popped drafts dispose after their widgets leave the frame.
- `lib/main.dart`: binding initialization and composition only.

## Maintenance aggregate and publication

Vehicles, schedules and service history form one aggregate. There is one cache and no cross-repository maintenance coordination. Vehicle creation and the first mileage-only service are one snapshot write. Each mutation:

1. Acquires a repository write guard and awaits simulated latency/connectivity.
2. Validates against the current snapshot and, for edits, compares the expected original record. Stale changes produce a conflict with draft retention and instructions to reopen/review. Unrelated refreshes do not falsely conflict.
3. Constructs new immutable records and a new aggregate without changing the old snapshot.
4. Persists a single JSON value through LocalPersistenceService. A failed write leaves observable data untouched.
5. Publishes the committed snapshot through a pure-Dart broadcast stream. ViewModels notify screens; SchedulingPolicy derives all due lists from that same snapshot. Save retries reuse the draft's ID.

Mileage-only/custom operations never reset scheduled baselines. Linked historical names resolve through the current item. Archived items remain in history and are excluded from due/new selections. Existing archived links are retained on service edits. Restore reuses their linked completions. The mock estimate is exactly the latest accepted actual reading; deleting the last reading produces unknown mileage while date calculations continue.

## Storage, scoping and recovery

Storage keys use `tw.v1.session`, `tw.v1.settings` and `tw.v1.garage.<identity>` (the web plugin adds its own storage prefix). Session/settings/maintenance persist across launches. Sign out removes the session and current account's persisted aggregate and cache; the next sign-in re-seeds. Global settings survive sign out. Account changes invalidate the in-memory aggregate before opening another account.

One JSON write is atomic at this prototype's logical aggregate boundary; this is not a transactional multi-process database or guaranteed crash-durable store. Concurrent application instances are outside this prototype's consistency model. History renders in batches of 30 from the locally persisted aggregate.

All asynchronous repository operations use Future success or AppFailure with validation, connectivity, missing, persistence and conflict kinds. ViewModels map failures to inline field/general messages and retain drafts for retry. Pending inputs/submission are blocked. Offline reads retain the saved as-of date and disable writes. Failed initial loads are distinct from an empty garage. Cached refresh failures retain content with Retry. Developer keyboard simulation can toggle connectivity/save failure and expire authentication without losing in-memory forms.

## Future backend seam

Authentication already uses ApiAuthRepository/ApiAuthService and shared TwApiClient. Maintenance remains behind LocalMaintenanceRepository; a later server-backed implementation can replace it without changing Views/ViewModels. Endpoint URLs, browser launches and bearer handling remain in Services. Saved server settings are loaded when constructing API clients. Credentials stay bound to their original server, including logout after a settings change.

## Verification

Tests separate pure policies, repositories with fake Services, persistence Service with a fake preferences boundary, ViewModels with fake repositories, and widgets with injected Composition/ViewModels. `test/boundaries_test.dart` enforces imports, including no concrete data/Service imports in UI, no Flutter/data imports in domain, storage-plugin imports confined to Services and network/shared/browser imports confined to Services. See README for scoped commands and platform limitations.

## Verified native compatibility

The Apple storage implementation is constrained to `shared_preferences_foundation: 2.5.7` for Xcode 16 compatibility; no plugin cache or generated Swift was patched. macOS release compilation and live session/data persistence work through the same PreferencesPersistenceService used on web. Normal Flutter tooling regenerates plugin registrations. Unsigned iOS release compilation and live simulator sign-in/service save also pass with iOS 18 installed. See README for per-platform results and signing limitations.
