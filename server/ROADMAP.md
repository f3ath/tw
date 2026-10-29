# Server integration ROADMAP

Based on a static review of the app and server on 2026-10-28. Authentication is
already connected to the server. Maintenance data still uses
`LocalMaintenanceRepository`. The server has basic vehicle CRUD, schedule
create/list/update/delete, and service create/list-by-vehicle/update/delete,
with authentication and ownership isolation.

## Required to preserve current app behavior

- [ ] **Vehicle distance units:** Persist `mi` or `km` per vehicle and prevent
  changing it after creation. Interpret service readings and schedule distances
  in that unit. Vehicles currently store only name and manufacture date, and
  schedule distance is named `interval_miles`.
- [ ] **Optional schedule intervals:** Support distance-only, time-only, and
  combined intervals. Require at least one positive whole interval. Unused
  intervals must be null, not zero. Distinguish omitted update fields from
  explicitly clearing an interval; current `COALESCE` updates cannot clear them.
- [ ] **Schedule archive/restore:** Preserve archived items and their service
  links. Restore the same item with its existing historical completions.
- [ ] **Linked service operations:** Persist the schedule items completed by
  each service. These links drive due calculations and item-specific history.
  Historical linked descriptions must resolve through the current schedule
  name. Services currently expose only date, mileage, and `details`.
- [ ] **Multiple custom service operations:** Round-trip a structured list of
  custom operations alongside linked items. Allow zero-operation mileage-only
  services. Custom text must never reset a schedule baseline, even if it matches
  a schedule name.
- [ ] **Atomic vehicle creation with initial reading:** Create a vehicle and its
  initial mileage-only service dated today in one transaction. Separate requests
  can leave a partially created vehicle when the second request fails.
- [ ] **Authoritative business validation:** Enforce the rules below on the
  server, including consistency under concurrent requests.
- [ ] **Stale-edit protection:** Support conditional updates using a version,
  ETag, or equivalent. Reject edits based on an outdated record with a conflict
  response instead of silently overwriting another client's changes.
- [ ] **Safe create retries:** Support idempotency keys or stable client-generated
  IDs. Retrying after a lost response must not create duplicate vehicles,
  schedules, or services. Current creates generate fresh server UUIDs.

## Server validation rules

- [ ] Require nonblank vehicle names and schedule descriptions.
- [ ] Reject future manufacture dates and manufacture dates later than existing
  services.
- [ ] Reject services before manufacture or after today.
- [ ] Require nonnegative whole odometer readings and positive whole interval
  values, with at least one interval present.
- [ ] Enforce chronological odometer consistency on service creation and edits.
  Same-date services may have different mileage. Use date, then mileage, then a
  stable identifier to select and order completions consistently.
- [ ] Require linked schedule items to belong to the same vehicle and caller.
- [ ] Permit each linked schedule item at most once per service.
- [ ] Reject newly selected archived items, including on past-date entries.
  Allow existing archived links to remain when editing their service.
- [ ] Ignore blank custom operation rows when saving.
- [ ] Agree on the user's local calendar-date context for date validation.
  Date-only rules must match the app rather than accidentally using a different
  server day.

## Additional server contracts

- [ ] **Structured errors:** Return useful validation errors with field pointers
  and meaningful conflict responses. Missing relationships, invalid dates, and
  failed casts should not become generic internal server errors. Some current
  input failures return only a bare bad request.
- [ ] **Current-distance estimates:** Define and expose a server estimate with
  its as-of context, as required by the UX specification. Editing or deleting
  readings must update the result. The app currently uses the latest actual
  reading as a deterministic placeholder.

Due status can remain client-derived initially; a dedicated due-status endpoint
is optional. Preserve the existing scheduling rules: latest linked completion
as baseline, manufacture date and zero distance if none exists, 30 days per
month, either reached threshold means overdue, and due-soon thresholds of 30
days or 1,000 vehicle distance units. Custom and mileage-only operations do not
reset schedule baselines. Archived items are excluded from due selections.

## Useful improvements, not initial wiring blockers

- [ ] Paginated history with deterministic date/mileage/ID ordering. The app
  currently batches the complete local history in groups of 30.
- [ ] A consistent aggregate-read mechanism for vehicles, schedules, and
  services, to avoid assembling mismatched snapshots during concurrent writes.
- [ ] Individual schedule and service fetch endpoints. Initially, the app can
  resolve details from complete per-vehicle collections.

## App/shared follow-up after server support

- [ ] Replace `LocalMaintenanceRepository` with an API-backed implementation.
- [ ] Extend `TwApiClient` for the new fields, operations, conditional writes,
  idempotency, and structured errors.
- [ ] Map server-generated IDs or adopt a compatible client ID scheme.
- [ ] Retain account-scoped offline caching, read-only offline behavior, and
  draft retention on failures and reauthentication.
- [ ] Clear local account cache on sign-out while retaining server records.

## Source references

- [App repository contract](../app/lib/domain/repositories.dart)
- [App models](../app/lib/domain/models.dart)
- [Scheduling and validation policies](../app/lib/domain/policies.dart)
- [Local save and conflict behavior](../app/lib/data/repositories/local_repositories.dart)
- [Form behavior](../app/lib/ui/forms/form_view_models.dart)
- [Current composition](../app/lib/app/composition.dart)
- [UX requirements](../app/docs/ux/car-maintenance-ux-spec.md)
- [Shared API client](../shared/lib/src/api/client/tw_api_client.dart)
- [Database schema](assets/db/0000-init.sql)
- [Vehicle controller](lib/src/vehicles/vehicles_controller.dart)
- [Schedule controller](lib/src/schedules/schedules_controller.dart)
- [Schedule persistence](lib/src/schedules/schedules_tdao.dart)
- [Service controller](lib/src/services/services_controller.dart)
- [Service resource](lib/src/services/service_resource.dart)
- [Server error handling](lib/src/server/server.dart)
