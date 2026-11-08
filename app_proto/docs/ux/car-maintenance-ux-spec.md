# TorqueWrench (TW) — UX specification and wireframe handoff

Version 9 · October 25, 2026 · Flutter Material 3 · Android, iOS, web, Windows, macOS, Linux

## 1. Product intent and scope

Help an owner identify overdue and upcoming maintenance, record performed work, and maintain an accurate history. Start with a garage, rather than a dashboard of unrelated metrics. One signed-in user owns multiple vehicles. No sharing or roles in this version.

The accompanying interactive wireframes illustrate layout and navigation, not production styling or live server behavior. Example dates, vehicles, histories, and counts are illustrative.

Project codename: TorqueWrench (TW). The Flutter prototype is to replace the existing Flutter application logic, including the real sign-in flow, inside an existing monorepo. Server and shared application code must not influence this implementation and must remain untouched. The UX below describes the intended product; for this implementation phase, README-CODEX.md explicitly replaces real authentication/networking with new mocked Services and repositories. It also requires strong Flutter layering with separate Views, ViewModels, repository interfaces/implementations and data-source Services.

## 2. Confirmed decisions

| Area | Decision |
| --- | --- |
| Platforms | Android, iOS, web, Windows, macOS, Linux. Use Material components throughout. |
| Authentication | Google OAuth only; login required; remember the signed-in user across launches. |
| Global navigation | Bottom Material NavigationBar with Vehicles and Settings; visible only while signed in, on all screen widths. |
| Settings | One field: Server address. Example: http://localhost:8080. |
| Landing page | Vehicle list with a preview of up to three due maintenance items per vehicle and an optional “{count} more...” link. No vehicle-level overdue or due-soon count badges. |
| Vehicle | Display name, manufacture date, current mileage, distance unit per vehicle, fixed after creation. Adding creates a mileage-only service dated today. |
| Schedule | Manually entered items with description, months and/or distance interval. Either reached limit makes an item overdue. |
| No service history | Use manufacture date and zero distance as the starting baseline. |
| Mileage | Service records are the primary readings; server estimates current distance from history. Label estimates and use them for due status. |
| Due soon | Within 1,000 miles or 1,000 km, depending on vehicle unit, or within 30 days. |
| Threshold boundary | At the interval limit, classify as overdue. |
| Service | Required date and mileage; zero or more operations. Each operation links to one schedule item or contains custom text. No notes, costs, attachments or parts fields. |
| New service | Today by default; mileage blank with estimate shown separately; suggest only overdue items, initially unchecked. Other active schedule items available. |
| Past service | Hide suggestions; offer all active schedule items. |
| Corrections | Edit and delete any service, including the initial mileage-only entry. Recalculate status. |
| Validation | No future service dates; enforce chronological consistency between odometer readings. |
| Archive | Archive/restore schedule items; preserve service history; show an item's past services. |
| Schedule edits | Edit description and intervals, applying the intervals to current calculations. Linked historical operations show the current description. |
| Month definition | One month is exactly 30 days; N months means N × 30 days. |
| Connectivity | Browse cached data offline; server connection required for writes. |
| Exclusions | Vehicle archiving/deletion, reminders, templates, imports, offline writes. |

## 3. Approved defaults

All seven defaults below were approved by the user on October 24, 2026. Treat them as confirmed UX requirements for implementation, alongside section 2.

1. Use exact manufacture dates, not model-year estimates. Dates cannot be in the future. All date-only rules use the user's local calendar date; the server must apply the same date context.
2. Values are nonnegative whole odometer units and positive whole interval values. At least one interval is required; an unused interval is blank, never zero.
3. For multiple services on the same date, use nondecreasing mileage; use a stable server ordering for equal readings. Same-date records may have different mileage. Choose the latest completion by date, then mileage, with a stable identifier tie-breaker. Use this ordering consistently in the backend and client presentation.
4. Permit each active schedule item at most once per service. Multiple custom operations are allowed; blank custom rows are ignored on save. A custom operation does not reset a schedule item, even when its text matches.
5. Archived items are unavailable for new selections, including past-date service entry. Existing links to archived items remain visible and retained when editing their service; show an Archived label. Restoring includes existing historical completions in calculations.
6. Preserve unfinished forms during temporary connection loss and reauthentication in the running session. Prompt before leaving a dirty form. Persisting drafts across process termination is outside initial scope.
7. No independent account deletion, data export, account settings or profile editing flows are specified. Sign out is available. Production store/privacy requirements need a separate release review.

## 4. Information architecture and adaptive layout

App routes: Sign in → signed-in shell with Vehicles and Settings destinations. Vehicles → Vehicle (Due | Schedule | History). Nested routes: Add/edit vehicle, Log/edit service, Service detail, Add/edit schedule item, Schedule-item detail. Account is a small menu showing Google identity and Sign out.

The garage is always the landing route after restored login. A bottom Material NavigationBar has exactly two NavigationDestinations: Vehicles and Settings. It is visible throughout the signed-in shell, including detail and form routes, on compact and wide screens. Hide it on sign-in/session-expired authorization screens. Vehicles is selected throughout vehicle-related routes; tapping it opens the Vehicles screen. Settings opens the Settings screen and selects Settings. Do not put vehicle-local Due/Schedule/History tabs in this global bar. Guard destination changes from dirty forms with the existing discard confirmation. Keep body content and actions above the bar with a bottom SafeArea; the app bar stays at the top. Returning from a nested route preserves the selected vehicle, local tab and scroll position. A cold launch returns to Vehicles. Browser refresh/deep links should restore the requested route after authentication; validate ownership and show Not found if inaccessible.

Compact (<600 logical px): single-column Scaffold, AppBar back arrow on nested screens; vehicle-local Material TabBar with Due, Schedule, History. Vehicle-screen primary actions appear in the AppBar or a labeled ExtendedFloatingActionButton, never both. The garage uses its explicitly specified trailing Add vehicle button instead. Forms are full-screen routes with Cancel/back and Save.

Medium (600–839 logical px): same hierarchy, constrained reading/form widths; avoid stretching narrow inputs. Wide (>=840 logical px): NavigationRail for the selected vehicle's Due, Schedule and History; title and breadcrumb back to Vehicles above. Content occupies the remaining space. Forms retain a readable maximum width rather than filling the window. These are proposed layout breakpoints, not platform detection rules.

Global bottom navigation remains in place on wide screens; the vehicle-local NavigationRail is separate and does not replace it. Settings has no vehicle-local tabs, rail or back arrow.

Use a consistent focus order; browser and OS back navigation should behave like the visible back button. Dialogs are for destructive confirmation and discard decisions, not long forms. Support safe areas, scrolling keyboards, resizing and 200% text scale. Minimum Material touch targets: 48 logical px. Do not encode status only by color.

## 5. Screens and component mapping

### S01 — Session restoration and Google sign-in

Start by restoring the session with a neutral progress state; avoid flashing Sign in during a normal token refresh. Signed-out screen: app name, short purpose, Continue with Google. Use Google's compliant sign-in control in implementation; the wireframe button is a placeholder. OAuth opens a platform-supported authorization surface and returns to the app. Successful sign-in → Vehicles, or the authorized requested deep link.

Cancel → same sign-in screen with a quiet message. Failure → actionable inline message and retry. Expired/revoked credentials → Sign in again; retain the active unsaved form in memory, then return to it. Offline with a remembered, locally authorized account → cached garage; no previously authorized session → sign-in screen with connection message. Sign out clears session and account-scoped cached content and returns to S01. Show which account is active in the account menu.

Material: Scaffold, progress indicator, sign-in button, inline error text, account MenuAnchor/PopupMenuButton.

### S02 — Vehicles / garage

AppBar: Vehicles title and account menu. Place one Add vehicle FilledButton after the last vehicle in the scrollable list content on both compact and wide screens. It scrolls with the list and sits above the bottom navigation, rather than being pinned to the viewport. For an empty garage, show it beneath the empty-state message. Keep its text label visible. Disable it offline with the same connection-required explanation as other server write actions. Each tappable vehicle row/card shows name; unit; estimated current mileage explicitly labeled Estimated, or recorded mileage labeled Recorded; last actual reading/date. Do not display vehicle-level overdue or due-soon count badges. The vehicle heading opens that vehicle's Due tab.

Below each vehicle summary, show up to three due maintenance items: overdue first, then due-soon items, preserving the same within-group ordering as the vehicle's Due tab. Each preview row shows the current item description, a text status, and a concise due reason (e.g. Overdue by 240 mi or In 24 days). These are scheduled maintenance items, not past service records. Do not include later or archived items.

When the combined overdue + due-soon count exceeds three, show a TextButton labeled “{count} more...” where count = combined count − 3. It opens the vehicle's full Due tab; it does not expand the card inline. Hide the link when no items remain. With one or two due items, show only those items; do not pad the list. With zero due items and complete status data, show No maintenance due soon. Unknown or stale status retains the existing unavailable/as-of treatment. Previews are read-only; use the vehicle heading or the more link to navigate, avoiding nested tap targets.

Do not add aggregate mileage or charts. Initial empty state: No vehicles yet; Add vehicle. Distinguish unavailable status from zero due. When estimates cannot be generated, use the latest actual reading with a Recorded label and explain that distance status is based on that reading. Server estimation-failure fallback is a proposed default.

Material: AppBar, ListView with a trailing Add vehicle FilledButton, ListTile/Card, account menu. Do not duplicate Add vehicle in the app bar or as a floating action button.

### S03 — Add / edit vehicle

Fields: Display name; Manufacture date; Distance unit [Miles | Kilometers]; Current odometer on Add only. Supporting copy: This creates a mileage-only service dated today. Save atomically creates vehicle plus initial service; partial creation must not produce duplicate or orphaned entries on retry.

Edit vehicle changes name/date only. Distance unit is read-only after creation; there is no unit-change or conversion flow. Update mileage is a shortcut to Log service with no operations selected, not a second editable mileage field. Manufacture-date changes recompute unserviced schedule baselines and must not invalidate earlier service dates silently.

Empty schedule after Add: Vehicle added; Add maintenance item. The user can skip and return to the garage. No manufacturer lookup or inferred schedule.

Material: Form, TextFormField, date picker with keyboard entry, SegmentedButton/dropdown for unit on creation, read-only unit on edit, FilledButton.

### S04 — Vehicle / Due

Header: vehicle name, Edit vehicle overflow action, Estimated current mileage and latest recorded reading, Update mileage shortcut. Local navigation: Due / Schedule / History. Primary action: Log service.

Overdue group first; Due soon second. Each ListTile shows description, a text status and both available dimensions, for example Overdue by 240 mi; due in 12 days. For equality, show Due now: mileage limit reached, within the Overdue group; never Overdue by 0. A date threshold reached today is Due today in that group. Counts count unique items, not individual breached dimensions. Tapping opens S08. Completing work always uses Log service; there is no one-tap Mark done.

All clear: No maintenance due soon; link to Schedule. No schedule: Add maintenance item. Time-based status still works if distance estimates are unavailable. For offline/cache states, label status as of the last successful fetch rather than silently advancing estimates.

Proposed ordering: Overdue items whose date limit is reached first, oldest due date first; remaining distance-overdue items by greatest excess distance; name as tie-breaker. Due-soon rows with upcoming dates first, earliest date first, then mileage-only rows by least remaining distance. Show both dimensions so this grouping does not imply a common severity scale between miles and days.

### S05 — Log / edit service

Full-screen form on compact; constrained form route on wide. Header: Cancel/back, Log service or Edit service, Save action. Vehicle is shown read-only. Fields: Date (today initially), Odometer (blank initially; numeric keyboard). Hint beneath: Estimated now: 91,240 mi. Enter the actual reading. Do not silently save an estimate.

Today: Overdue suggestions first, all unchecked. Then Other scheduled maintenance, including due-soon and later active items, all unchecked. Do not duplicate an item in both sections. Past date: no suggestion section; show all active items in a single list. Selected count remains visible; changing date/regrouping does not clear selections or custom text. On edit, preload the service's fields and operations. Existing archived links appear separately with Archived label and can be removed.

Checkbox rows select scheduled operations. A separately labeled Custom operations group contains text fields and Remove controls; Add custom operation adds a row. No automatic creation of a schedule item from custom text. Zero selected operations is valid; show Saved as a mileage-only entry as supporting text when nothing is selected. Do not imply that work was performed in this state.

Inline validation next to the relevant field: required date/mileage; future date; before manufacture date (proposed); negative/fractional readings; mileage outside bounds from chronological neighbors. Give useful bounds, e.g. Must be between 90,800 mi on Oct 10 and 91,400 mi on Oct 24. Equal readings are allowed. When editing, exclude this service from the bounds calculation. Dates changed to a past day must not leave current-day suggestions visible.

Save: disable repeated submit while pending, retain all fields on failure. Successful new/edit save → Service detail with a brief Saved snackbar. Update Due, Schedule and due previews after server confirmation. A newly saved older service only changes a schedule baseline when it is the latest linked completion.

### S06 — History

Reverse-chronological ListView grouped by date if helpful. Each row: date, odometer, operation summary; mileage-only entries explicitly say Mileage update. Tap → S07. Primary action remains Log service. No operation-only history filter in initial scope; per-item history lives on S08. Paginate long histories without blocking access to current due status.

### S07 — Service detail

Date, odometer, read-only operation list; linked items open their item detail, custom operations are plain text. Mileage-only entry: No maintenance operations recorded. Actions: Edit; Delete in overflow. Delete confirmation identifies date/mileage and says Due dates and estimated mileage will be recalculated. On success return to History. Failure retains the record and offers Retry. Deleting the last service leaves an unknown mileage state; never silently assume the vehicle currently has zero mileage. Date-only schedule calculations remain available.

### S08 — Schedule item detail

Description; recurrence (Every 5,000 mi or 6 months, whichever comes first); current status; next due distance/date; last completed date/mileage, or No recorded service — calculated from manufacture date and 0 mi. History of linked services, newest first; tap → S07. Actions: Edit; Archive in overflow; archived detail instead offers Restore and an Archived label, without an active due status.

Archive confirmation: Stop tracking this item? Its service history will be kept. Restore immediately recalculates status and can make the item overdue. No permanent item deletion.

### S09 — Schedule list

Active list by description, each with recurrence and current status; tap → S08. Primary action: Add item. A clearly labeled Active / Archived filter exposes restorable items. Archived items are excluded from due previews, Due and new service selections. Empty active schedule: Add maintenance item; if archived items exist also offer View archived.

### S10 — Add / edit schedule item

Required description; optional Every [distance] mi/km; optional Every [months] months. At least one positive interval is required. Supporting copy beneath both fields: When both are set, maintenance is due when either limit is reached. One month = 30 days. Units follow the vehicle’s fixed unit. Do not show separate AND/OR settings.

Edit helper: Changing intervals recalculates when this item is due. Linked history uses the current description (confirmed). Custom operation text is unchanged by schedule-item renames. On Save return to item detail and refresh status/counts. Adding an item with no linked history immediately uses the zero/manufacture baseline; do not ask for a second hidden baseline. If users know a prior completion, provide a normal Log service path to record it.

### S11 — Settings

A top-level signed-in destination with AppBar title Settings. Show exactly one field: Server address, using http://localhost:8080 in the wireframe. Use a URL TextFormField with the visible label Server address, and a Save button below it. No other settings fields. Keep the bottom navigation visible with Settings selected.

Proposed interaction default: initialize from the locally saved address; accept absolute HTTP/HTTPS URLs; show validation adjacent to the field and Saved feedback after explicit Save. Store this client setting locally rather than posting it to the maintenance server, so it can be edited offline. Switching destinations with unsaved text uses the standard discard prompt. Endpoint connection testing, session transitions when switching servers and a pre-login configuration path have not been specified; the wireframe does not simulate those network effects.

Material: Scaffold/AppBar, Form/TextFormField, FilledButton, SnackBar, NavigationBar/NavigationDestination.

## 6. Scheduling contract for design and implementation

The server is authoritative for estimates, due classification, counts, validation bounds and recalculation. The client formats values consistently and does not implement an independent estimator.

For each active item, select the latest service that contains its linked operation. Use that service's date and odometer for both baselines. If none exists, use manufacture date and zero distance. Mileage-only services update mileage/estimation but never reset maintenance intervals. Custom operations never reset them.

- Distance due = baseline distance + distance interval, when provided.
- Date due = baseline date + (month interval × 30 days), when provided.
- Overdue = current estimated/available distance >= distance due OR local today >= date due, considering only available dimensions.
- Due soon = not overdue AND (distance due <= current distance + 1,000 selected units OR date due <= local today + 30 days), considering only available dimensions.
- Later = neither overdue nor due soon, provided relevant dimensions are known.
- Incomplete data = show any known time/distance result but never claim All clear for an unknown dimension. Item may be known overdue by time while distance remains unknown.

No estimate and no recorded reading: current mileage is unknown; time checks continue. There is no client extrapolation. Offline: preserve the last computed classification and show its as-of time. On reconnection refresh estimates, counts and classifications.

## 7. Empty, pending, failure and session states

| Context | Presentation / recovery |
| --- | --- |
| Initial fetch | Centered or inline progress; no fabricated zero counts. |
| Refresh with cached content | Keep content visible; subtle progress. |
| Offline with cache | Persistent Offline · showing saved data · last updated [time] banner; disable and explain write actions. Allow navigation. |
| Offline without cache | No saved data available; Retry; no empty-garage implication. |
| Failed fetch with cache | Keep old content and show Couldn't refresh + Retry; label as-of time. |
| Failed fetch without cache | Couldn't load vehicles/item/history + Retry. |
| Save failed / connection dropped | Keep form, inline error; Retry save. Never pretend success. |
| Save result uncertain | Reconcile or retry using server idempotency; avoid duplicate service/vehicle creation. |
| Stale edit / changed data | Keep edits, show record changed, offer Reload or review. Do not silently overwrite. |
| Dirty form back | Discard changes? Keep editing / Discard. |
| Session expired during form | Sign in again, preserve in-session form, revalidate before saving. |
| Wrong account / inaccessible route | Not found or unavailable; Back to vehicles. Never reveal another user's vehicle. |
| Sign out with dirty form | Apply discard confirmation before clearing session/cache. |

## 8. Flutter implementation notes

Use Scaffold/AppBar, bottom NavigationBar with two NavigationDestinations, NavigationRail, TabBar/TabBarView, ListView/ListTile, CheckboxListTile, Form/TextFormField, date picker, SegmentedButton or DropdownMenu, FilledButton, TextButton, ExtendedFloatingActionButton, AlertDialog, SnackBar, progress indicators and accessible overflow menus. The monochrome wireframe does not prescribe a final palette, type scale or icon set. Do not turn the wireframe's review controls into app navigation.

Separate UI drafts from saved records. Use MVVM with Views and ViewModels; immutable domain models and pure-Dart policies; abstract repository contracts and concrete implementations; and distinct data-source Services for mock authentication and local persistence. Views/ViewModels never call Services or storage directly. Repositories own application data consistency, delegate persistence to Services, and delegate reusable scheduling/odometer rules to domain policies. Use constructor injection with an explicit composition root. The mocked phase uses no existing real sign-in or server/shared logic; any future real integration must replace implementations behind these contracts. Full mandatory architecture, scoped removal instructions and layer-specific verification are in README-CODEX.md.

For the future server-backed product, surface server field errors next to inputs; retain drafts through retries, invalidate related vehicle/list/item queries after writes and use account-scoped cache keys. Real OAuth/token configuration remains outside this mocked implementation.

## 9. Review scenarios / acceptance checklist

1. First launch → Google sign-in → empty Vehicles → add vehicle → automatically created mileage-only history entry → add schedule item.
2. Relaunch with a valid session → Vehicles without asking for Google again. Both actual and estimated mileage are clearly distinguished.
3. Item without history uses manufacture date and zero odometer. Reaching either exact threshold places it in Overdue; a dual-threshold item counts only once.
4. Within 1,000 selected units or 30 days → Due soon. An item already overdue never appears in both groups.
5. Log today's service: mileage blank; only overdue items suggested, unchecked; any active scheduled item and multiple custom operations can be added.
6. Save zero operations → Mileage update history row; estimates refresh; scheduled baselines do not reset.
7. Change date to the past → suggestions disappear, selections remain, mileage validated against neighboring readings. Backdated work does not replace a newer completion.
8. Edit/delete a service → server recalculates due status, counts and estimates; archive item → no reminders/counts; restore → existing history reused.
9. Unit is chosen when adding a vehicle and cannot be edited. The 1,000 km due-soon threshold is intentional. Renaming an item updates its linked historical labels.
10. Disconnect → cached browsing remains; writes disabled; reconnect refreshes. Failed save retains user input; expired session can resume the form.
11. Garage previews show at most three overdue/due-soon items per vehicle, in the same order as Due. A five-item vehicle shows “2 more...”; a two-item vehicle has no more link. Vehicle-level count badges are omitted; the more link counts only items beyond the preview.
12. Bottom navigation has exactly Vehicles and Settings on all signed-in screens; Sign in has no bottom navigation. Settings contains only Server address as a field, using http://localhost:8080; Vehicles opens the garage.
13. Narrow/wide layouts expose the same actions; keyboard navigation, screen readers and increased text scale remain usable.

## 10. Remaining review points

Section 3 is approved; same-day ordering, validation conventions, archived-item selection rules and in-session draft handling are confirmed. Month duration (30 days), fixed vehicle units and live historical descriptions are also confirmed. Other proposals outside section 3 retain their existing review status, including layout breakpoints, due-list ordering, estimation-failure fallback and Settings save behavior. The backend must specify its estimation availability and response contract. OAuth platform support and account lifecycle/store obligations need implementation/release decisions; these are not represented as finished product requirements.
