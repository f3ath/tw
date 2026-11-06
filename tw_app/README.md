# Torque Wrench — learning project

This README tracks progress and provides handover between teaching sessions.
Read it before continuing work in `tw_app/`.

## Collaboration agreement

- The user is a professional developer proficient in Dart, learning Flutter and mobile application development.
- Teach incrementally: explain concepts and tradeoffs, give a small exercise with an observable checkpoint, then review the result.
- The user writes application code. Do not implement features or provide complete solutions unless explicitly asked. Documentation updates are authorized.
- Focus on Flutter and platform concepts without reteaching basic programming or Dart.
- Use `../app/` as a reference, not a template to copy wholesale.
- Introduce abstractions when needed; keep the first iteration small.
- Testability and coverage are essential. Tests are the source of truth for app behavior; teach and add meaningful behavior tests alongside features.
- Use ports/adapters: application orchestration and its tests depend on semantic ports, not HTTP messages or TwApiClient. Keep transport concerns in adapters and adapter-specific tests.
- User explicitly chose to skip API adapter unit tests while mappings are trivial and TwApiClient is evolving. Keep application behavior tests; revisit only if adapters gain substantial logic.
- User confirmed null-to-empty User field mapping is deliberate and exceptions cross ports unchanged for now. URI completeness/scheme validation is deferred by explicit user choice; retain the adapter's missing completion URI handling.

## Agreed scope

Platform priority: **web → iOS → Android**. Native Linux and macOS are optional.

First iteration:

- Google login, session restoration, and logout.
- Logout must always let the user leave the account: clear local authentication/session state and return to welcome even when server revocation fails. A pending or failed server request must not block local logout or restore the logged-out account.
- CRUD for vehicles.
- CRUD for schedules belonging to vehicles.
- CRUD for services and their operations, including custom operations.
- Minimal design using Material components.
- Use the existing server and shared Dart API client in this repository.
- Handle ordinary loading, validation, and request errors.

Out of scope: offline mode, synchronization, and advanced network behavior such as atomicity. Do not carry these features over from the reference app.

Web priorities include meaningful URLs, browser back/forward and refresh, responsive layouts, and keyboard/mouse interaction alongside touch. Isolate platform-specific authentication and persistence where necessary.

## Next iteration — deferred work

These tasks are outside the first iteration; this backlog does not imply they have been implemented.

- Clean up old server sessions, including sessions left behind when logout cannot revoke them. Define the cleanup policy and mechanism in that iteration.
- Finish authentication hardening: local logout independent of pending revocation, handled revocation failures, lifecycle guards, and retained credential cleanup. User accepts current login/logout implementation as sufficient for the first iteration; do not block vehicle work on these items.

Offline mode, synchronization, and advanced network behavior remain out of scope; they are not committed next-iteration features.

## Proposed learning sequence

Adjust this sequence with the user as the application develops.

1. App shell: widget tree, MaterialApp, theme, Scaffold, layout constraints, and hot reload; placeholder login and garage screens.
2. Navigation: routes, URLs, browser history, details and form destinations.
3. Authentication: existing API, Google flow, session restoration, logout, asynchronous UI state, and browser/mobile differences.
4. Vehicle CRUD: lists, forms, validation, and confirmation dialogs.
5. Schedule CRUD within a vehicle.
6. Service CRUD with scheduled and custom operations; dynamic forms.
7. Usability and platform checks: responsive layout, keyboard/focus, touch, accessibility, lifecycle, and appropriate tests.

Tentative structure: views → view models → repositories → API client. Introduce boundaries through actual features instead of scaffolding every layer first.

## Current checkpoint — 2026-11-02

- Scope and teaching approach agreed.
- User created the default Flutter project in `tw_app/`.
- `lib/main.dart` launches `TwApp` from `lib/app/tw_app.dart`.
- `TwApp` configures the Material title/theme and displays `WelcomeScreen`.
- `WelcomeScreen` uses Scaffold → SafeArea → Center → FilledButton and logs button presses. Counter demo removed.
- Discussed widget keys (not forwarded to children) and Material versus Cupertino.
- Completed the async login simulation: StatefulWidget/State, busy flag, synchronous setState callbacks, two-second delay, mounted check, disabled button and changing label. Reviewed source; behavior not independently run.
- Explained that rebuilding reevaluates onPressed and restores the callback when the busy flag becomes false.
- User implemented simulated failure with try/catch/finally and SnackBar. Review found SnackBar invocation wrapped in a custom mounted-checking setState helper; next correction is to show the SnackBar directly after a mounted check and reserve setState for the busy flag.
- Source reviewed; browser layout/keyboard checks have not been independently verified. No builds or tests run by the assistant.

## Next session

Latest direction: user explicitly accepts login/logout as good enough for iteration one and wants to move on. Start vehicle listing: loading, empty, populated, failure/retry states using semantic vehicle port and test-controlled results. First small exercise: application-owned Vehicle model and GarageScreen populated rendering test with supplied vehicles, then ListView.builder/ListTile implementation. No CRUD forms or API wiring yet. Existing shared Vehicle fields: id, name, manufactureDate, distanceUnit.

Latest review: user deferred name layout constraints. App-level name assertion added and verified; `flutter test test/ui/tw_app_test.dart`: 1 passed. TwApp.logout now clears User in finally, which covers completion/failure but still blocks on pending revocation, rethrows failure into IconButton callback, and can call setState after disposal. Next add controlled logout failure/pending tests; clear local UI immediately and explicitly handle background revocation failure. Session credential cleanup remains separate from merely clearing displayed User.

Latest name-display review: TwApp retains nullable User and passes name to GarageScreen; isolated garage test checks keyed Text data. Full flutter test: 10 passed. Follow-ups: constrain AppBar name width (ellipsis alone does not bound Row child), center/pad name, add long-name narrow-layout test and app-level assertion for authenticated user's name. Logout still awaits server before clearing User, contrary to latest always-local-logout requirement; add pending/failure tests and fix as next auth task.

2026-11-05 decision: local logout must always succeed independently of server revocation. This supersedes earlier suggestions to retain the garage on logout failure or require a revocation retry before leaving. Next exercise: tests proving local logout clears authentication and returns to welcome on server success, failure, and a pending request; then user implements that behavior. Ensure saved credentials cannot restore the account after local logout. Old server-session cleanup is deferred to the next iteration. Documentation only changed in this session; no tests run.

Latest verification: user updated test/ui/tw_app_test.dart to inject a controlled Completer<User> through AuthServiceStub.loginResult, assert pending state before completing login, then verify garage/logout. Obsolete two-second pump removed. Assistant ran full flutter test: all 9 passed. Earlier review items (port location and HTTP resource ownership) remain pending unless source changes show otherwise.

### Earlier checkpoints (historical; latest decisions above take precedence)

Latest error-presentation checkpoint: UserCancelledException moved to application/auth/auth_exceptions.dart; WelcomeScreen silently handles cancellation and retains generic failure snackbar. Both welcome tests now create Completers/counters inside testWidgets, and pass. Full flutter test: 8 passed, 1 failed in test/ui/tw_app_test.dart:25. That test's login stub completes immediately, so after pump the welcome button no longer exists; replace stub login result with controlled Completer<User> (complete after busy assertion), remove obsolete two-second pumping. main no longer closes HTTP client immediately after runApp; lifecycle ownership still deferred. AuthServicePort remains in tw_app.dart.

Latest composition review: main constructs http.Client → TwApiClient → TwAuthApiAdapter → AuthService, injected via AuthServicePort into TwApp. Full flutter test: 8 passed. Critical fix needed: main's try/finally closes HTTP client immediately after runApp returns (runApp does not await application lifetime). Other findings: remove leftover two-second UI login delay and control pending login via Completer in widget test; logout needs mounted guard and busy/error handling (GarageScreen currently passes async callback directly to IconButton). AuthServicePort is declared in tw_app.dart, causing data service to import Flutter app library; move port to standalone application/domain file. No production/test edits by assistant.

Latest platform checkpoint: open_login_window.dart conditionally exports native vs web using dart.library.js_interop; each exposes synchronous openLoginWindow(), with private concrete classes. Async navigate stub added for test URI. Assistant ran full flutter test: all 8 passed. Browser/native launch not exercised by widget tests. Native close comment remains incomplete. Next composition lesson: construct long-lived HTTP/API/auth dependencies outside build, inject authentication callbacks/service into TwApp while keeping widget tests on fakes; wire real login/logout without losing testability.

Latest platform adapter review: user added LoginWindowNative using url_launcher externalApplication and LoginWindowWeb wrapping web.Window. LoginWindow.navigate now returns Future<void>, awaited by AuthService. Native implementation matches intended limited capabilities. Conditional factory/export not yet present. Assistant ran auth_service_test.dart: 2 passed, 4 failed because Mocktail navigate is unstubbed and returns null instead of Future<void>. Next add shared stub `when(() => window.navigate(any())).thenAnswer((_) async {});`, then rerun. Complete native close comment to explain external browser cannot be closed by this adapter.

Latest adapter review: TwAuthApiAdapter implemented (pending-null preserved, User maps null name/email to empty strings, missing completion URI throws ServerException, logout delegates). User opts out of API adapter tests. Review considerations: blank defaults lose absent-value distinction; completion URI currently checks null only; client exceptions currently cross the port unchanged. No adapter tests run or required for this step.

Latest review: user added asynchronous getCurrentUser failure cleanup test and restored short cancellation interval. Assistant ran auth_service_test.dart: 6 passed. One correction remains: duration assertion uses same(tenSeconds); prefer equals(tenSeconds) to require value equality without object identity. Login orchestration coverage is sufficient to proceed to AuthApiPort adapter. No production/test edits by assistant.

2026-11-04 cleanup review: simplified polling loop with local final user and cancellation guard; common mock defaults moved to setUp. Assistant ran full `flutter test`: 7 passed. Review notes: cancellation test now waits real default 2-second delay; inject fake clock/delay. Assert Duration equality rather than truncated inSeconds. Cleanup changes deadline/cancellation precedence: timeout wins if both conditions hold at next iteration (previous version favored cancellation). Decide/test deliberately if relevant. getCurrentUser failure cleanup test still missing.

2026-11-04: cancellation test improved and reviewed. First pending user lookup changes window.isClosed to true; test expects UserCancelledException, exactly one lookup, and no redundant close. Assistant ran auth_service_test.dart: all 5 passed. This scenario is valid without requiring closure during an injected delay. Next exercise: getCurrentUser asynchronous failure preserves original exception and closes open window. Cancellation currently takes effect after the polling delay; immediate interruption is not implemented.

Latest cancellation review: LoginWindow moved into auth_service.dart; service checks isClosed in polling condition and skips close when already closed. Assistant ran auth_service_test.dart: 5 passed. Cancellation test currently closes window based on getter read count and uses throwsException. Next improve with explicit closed flag toggled during a simulated wait and a distinct cancellation exception, asserting no further polls; cover getCurrentUser failure cleanup. Timeout/cadence test now uses fixed baseline and checks inDelay on user lookup.

Latest timing review: user changed ClockMock to advance elapsed time only when an asynchronous fake delay completes, with an inDelay guard against overlapping delays; timeout expects TimeoutException and exactly three delays. Async failure stub corrected. Assistant ran auth_service_test.dart: 4 passed. Suggested small improvement: assert !inDelay within getCurrentUser stub to directly prove no polling during delay; use a fixed baseline DateTime. Current timing approach is acceptable without requiring Completers. Next missing behavior: window cancellation and polling failure cleanup.

Latest review: auth tests now cover synchronous popup creation, repeated pending polls leading to success, startLogin failure cleanup, and polling timeout. Assistant ran auth_service_test.dart: 3 passed. Follow-ups: await expectLater in failure test; use thenAnswer async throw to exercise asynchronous failure; replace broad throwsException with TimeoutException or application timeout type; remove wall-clock-dependent poll-count range (Mocktail verifyInOrder also consumes a matching call). Next teach deterministic polling tests with fake_async (including DateTime through its clock) or injected timing. Cancellation and getCurrentUser failure cleanup remain untested/unimplemented as applicable.

Latest auth review: user implemented immediate-success AuthService.login and a Mocktail test asserting returned User identity and startLogin → navigate → getCurrentUser → close order. Assistant ran `flutter test test/data/auth_service_test.dart`: 1 passed. Review caveat: verifyNever inside window factory proves factory precedes API calls, not that factory runs before the first await; add an immediate factory-called assertion after calling login and before awaiting its future. Next tests: pending null user (current user! fails), and window cleanup when startLogin/getCurrentUser fail. User moved User to lib/domain/user.dart.

Latest checkpoint: API dependencies added. User drafted AuthService with AuthApiPort and LoginWindow ports, an application-owned User, and fakes in test/data/auth_service_test.dart. Review: approve ports/adapters direction; getCurrentUser needs nullable result (pending login), or an explicit waiting contract. First orchestration test is currently scaffolding only, with no service invocation or assertions. Next implement fake URI/user responses, call signIn, assert navigation/user/window cleanup, then add pending/cancellation/failure cases. Keep HTTP detail tests confined to the eventual TwApiClient adapter. No test run for this incomplete draft.

2026-11-03 test review completed: user added `test/ui/welcome_screen_test.dart` with controlled Completer attempts for failure and successful retry, including a second tap while pending to verify callback count remains one. User chose to clear SnackBars after successful login (guarded by mounted), retaining the corresponding absence assertion. Assistant ran `flutter test`: both tests passed. Next resume real authentication preparation; API dependencies/client construction have not yet been implemented.

Current priority: testing lesson before real API dependencies/authentication. User replaced the generated counter test with a widget test for welcome → busy → garage → logout → welcome. It uses screen types, stable button keys, enabled/disabled assertions, and explicit fake-time advancement. Assistant ran `flutter test test/widget_test.dart`: 1 test passed. Next cover WelcomeScreen in isolation with controlled injected callbacks for pending/failure/retry behavior. Application/test code remains user-written.

1. Read this README and inspect the current source and working-tree changes.
2. Check for progress made between sessions before assuming this checkpoint is current.
3. Failure-handling correction reviewed: explicit mounted checks, SnackBar outside setState, busy reset in finally. Remove the stray semicolon after the catch block's mounted check.
4. Callback injection completed and source reviewed: WelcomeScreen awaits widget.onLogin(); TwApp supplies the simulated delay/failure. No independent runtime verification.
5. Screen switching implemented and source reviewed: TwApp owns _isLoggedIn, delayed login selects GarageScreen, and injected logout returns to WelcomeScreen. Follow-up corrections: mounted guard after login delay; synchronous void logout matching VoidCallback; Logout tooltip on IconButton. No independent runtime verification.
   Mounted guard and tooltip now verified in source. Logout still returns Future<void> unnecessarily; synchronous signature remains a minor cleanup.
   Next proposed exercise: add the shared API/HTTP adapter dependencies using ../app/pubspec.yaml as the repository reference, resolve packages, and inspect TwApiClient session methods before implementing transport or OAuth.
6. Keep real OAuth and URL routing for subsequent steps. Simulated authentication is temporary UI scaffolding.
7. Verify busy-state recovery, successful screen switching, logout, and browser layout/keyboard behavior before advancing to real authentication.

## Handover maintenance

At the end of a session, update the checkpoint with what the user actually implemented, concepts covered, verification performed, open questions, and the next exercise. Distinguish proposed work from completed work. Preserve the scope and collaboration agreement unless the user changes them.
