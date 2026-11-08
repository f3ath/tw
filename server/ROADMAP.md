# Server integration ROADMAP

Originally based on a static review on 2026-10-28; updated against the code and
use-case tests on 2026-11-01. Authentication is connected to the server. The API
supports vehicles, schedules, services, and service operations, with ownership
isolation and business validation. Maintenance data in the app still uses
`LocalMaintenanceRepository`; API wiring can begin now.

## Required to preserve current app behavior

- [x] **Vehicle distance units:** Persist `distance_unit` (`mi` or `km`) per
  vehicle and expose it on create/fetch/list/update responses. Reject invalid
  units on creation and any `distance_unit` attribute on updates (HTTP 400).
  Existing vehicles and creates that omit the unit default to `mi`.
  `TwApiClient.createVehicle` accepts `distanceUnit`.
- [x] **Unit-neutral distance fields:** Interpret service readings and schedule
  distances in the vehicle's unit. Rename the legacy `mileage` and
  `interval_miles` fields to `odometer` and `interval_distance`, respectively.
- [x] **Optional schedule intervals:** Support distance-only, time-only, and
  combined intervals. Require at least one positive whole interval. Unused
  intervals must be null, not zero. Distinguish omitted update fields from
  explicitly clearing an interval. Updates preserve omitted fields and persist
  explicit nulls.
- [x] **Schedule archive/restore state:** Persist `is_archived`, include archived
  items in schedule collections, and restore the same ID, description, and intervals.
- [x] **Archive/restore linked history:** Preserve operation IDs and schedule
  references while archiving and restoring items. Existing historical completions
  remain available for client-derived calculations.
- [x] **Linked service operations:** Persist operations in `service_operations`,
  linked to a service and optionally a schedule. Scheduled operations expose
  read-only `name` and `details` from the current schedule, including after edits.
- [x] **Multiple custom service operations:** Persist multiple custom operations
  with editable `name` and `details`, alongside scheduled operations. Services can
  have no operations. Custom text never implicitly creates a schedule link.
- [ ] **Atomic vehicle creation with initial reading:** Create a vehicle and its
  initial mileage-only service dated today in one transaction. Separate requests
  can leave a partially created vehicle when the second request fails.
- [ ] **Atomic service and operation saves:** Commit service fields and all operation
  additions, edits, and removals in one transaction. Current endpoints save each
  resource separately, so a failed request can leave a partially saved service.
- [x] **Core business validation:** Enforce names, intervals, dates, odometer
  consistency, operation ownership, duplicate selections, and archive restrictions.
  Service writes and manufacture-date edits coordinate through vehicle locks;
  operation writes serialize selections per service and lock referenced schedules.
- [ ] **Stale-edit protection:** Support conditional updates using a version,
  ETag, or equivalent. Reject edits based on an outdated record with a conflict
  response instead of silently overwriting another client's changes.
- [ ] **Safe create retries:** Support idempotency keys or stable client-generated
  IDs. Retrying after a lost response must not create duplicate vehicles,
  schedules, services, or operations. Client create methods do not currently expose
  stable IDs or idempotency keys.

## Server validation rules

- [x] Require nonblank vehicle names and schedule descriptions.
- [x] Reject future manufacture dates.
- [x] Reject manufacture dates later than existing services.
- [x] Reject services before manufacture or more than seven calendar days ahead.
  The seventh day is allowed on both creation and editing.
- [x] Require positive whole schedule interval values, with at least one interval present.
- [x] Require nonnegative whole odometer readings.
- [x] Enforce chronological odometer consistency on service creation and edits.
  Equal readings across dates and different readings on the same date are allowed.
  Exclude the edited service's previous version from its bounds calculation.
- [x] Require linked schedule items to belong to the same vehicle and caller.
- [x] Permit each linked schedule item at most once per service, including under
  concurrent requests.
- [x] Reject newly selected archived items, including on past-date entries.
  Allow existing archived links to remain or be removed while editing.
- [x] Preserve calendar components for vehicle and service dates. PostgreSQL uses
  `DATE`; client serialization and DTO parsing do not convert dates between timezones.
  Validation uses the clock's calendar components, with the service allowance above.
- [x] Reject blank custom operation names at the individual operation endpoint.
  Filtering blank draft rows before submitting operations is an app responsibility.

## Additional server contracts

- [ ] **Structured errors:** Return useful validation errors with field pointers
  and meaningful conflict responses. Missing relationships, invalid dates, and
  failed casts should not become generic internal server errors. Some current
  input failures return only a bare bad request.
- [ ] **Current-distance estimates:** Define and expose a server estimate with
  its as-of context, as required by the UX specification. Editing or deleting
  readings must update the result. The app currently uses the latest actual
  reading as a deterministic placeholder; this can remain client-derived for
  initial wiring.

Due status can remain client-derived initially; a dedicated due-status endpoint
is optional. Preserve the existing scheduling rules: latest linked completion
as baseline, manufacture date and zero distance if none exists, 30 days per
month, either reached threshold means overdue, and due-soon thresholds of 30
days or 1,000 vehicle distance units. Custom and mileage-only operations do not
reset schedule baselines. Archived items are excluded from due selections.

## Useful improvements, not initial wiring blockers

- [ ] Paginated history with deterministic date/mileage/ID ordering. The app
  currently batches the complete local history in groups of 30.
- [ ] A consistent aggregate-read mechanism for vehicles, schedules,
  services, and operations, to avoid assembling mismatched snapshots during
  concurrent writes.
- [ ] Individual schedule and service fetch endpoints. Initially, the app can
  resolve details from complete per-vehicle collections.

## App/shared follow-up

- [ ] Replace `LocalMaintenanceRepository` with an API-backed implementation.
- [ ] Share authenticated client/session access with the maintenance repository;
  `ApiAuthService` currently holds its client privately.
- [x] Add typed vehicle, schedule, service, and operation DTOs to `TwApiClient`,
  including distance units, nullable intervals, archive/restore, operation
  relationships, and custom operation names/details.
- [ ] Extend `TwApiClient` for atomic saves, conditional writes, idempotency,
  and structured errors once those server contracts exist.
- [ ] Map server-generated IDs to app models and navigation. Preserve operation
  IDs so edits can identify operation additions, updates, and deletions.
- [ ] Replace custom-operation strings in app models/forms with name/details
  values. Map scheduled operations to schedule IDs for due/history calculations.
- [ ] Filter blank custom draft rows before creating operations; remove existing
  operations when their rows are removed from the saved draft.
- [ ] Align app date validation with the server's seven-day service allowance,
  preserving calendar components throughout serialization and caching.
- [ ] Retain account-scoped offline caching, read-only offline behavior, and
  draft retention on failures and reauthentication.
- [ ] Clear local account cache on sign-out while retaining server records.

## Source references

- [App repository contract](../app_proto/lib/domain/repositories.dart)
- [App models](../app_proto/lib/domain/models.dart)
- [Scheduling and validation policies](../app_proto/lib/domain/policies.dart)
- [Local save and conflict behavior](../app_proto/lib/data/repositories/local_repositories.dart)
- [Form behavior](../app_proto/lib/ui/forms/form_view_models.dart)
- [Current composition](../app_proto/lib/app/composition.dart)
- [UX requirements](../app_proto/docs/ux/car-maintenance-ux-spec.md)
- [Shared API client](../shared/lib/src/api/client/tw_api_client.dart)
- [Database schema](assets/db/0000-init.sql)
- [Vehicle controller](lib/src/vehicles/vehicles_controller.dart)
- [Schedule controller](lib/src/schedules/schedules_controller.dart)
- [Schedule persistence](lib/src/schedules/schedules_dao.dart)
- [Service controller](lib/src/services/services_controller.dart)
- [Service resource](lib/src/services/service_resource.dart)
- [Operation controller](lib/src/services/operations_controller.dart)
- [Operation persistence](lib/src/services/operations_dao.dart)
- [Vehicle use cases](test/usecases/vehicles_test.dart)
- [Schedule use cases](test/usecases/schedules_test.dart)
- [Service use cases](test/usecases/services_test.dart)
- [Operation use cases](test/usecases/operations_test.dart)
- [Server error handling](lib/src/server/server.dart)
