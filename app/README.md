# TorqueWrench (TW)

Interactive Flutter Material 3 car-maintenance prototype. Read [ARCHITECTURE.md](ARCHITECTURE.md) for layer boundaries and concrete classes; [README-CODEX.md](README-CODEX.md) and [the UX specification](docs/ux/car-maintenance-ux-spec.md) define the handoff.

## Launch

From this Flutter package directory, with Flutter/Dart supporting Dart 3.13.5 or later:

```sh
flutter pub get
flutter run -d chrome --web-port=8765
```

For a release web bundle:

```sh
flutter build web
python3 -m http.server 8765 --bind 127.0.0.1 --directory build/web
```

Open http://localhost:8765. Keep the same origin/port to reuse web storage. Native targets use the platform preferences store; run `flutter devices` to select an available target.

## Mock behavior

Continue with Google simulates sign-in as `alex@torquewrench.demo`. It opens no Google/browser authorization flow. There are no application API calls, HTTP clients, OAuth credentials or tokens. Server address starts at `http://localhost:8080`, is stored locally, and is never contacted. Flutter's web engine/assets still need to load as part of hosting the application.

Session, server address, vehicles, schedules and services persist locally. The initial demo includes miles and kilometers, five versus two due-item examples, overdue/due-soon items, mileage-only history, linked/custom operations and an archived item. Dates seed relative to the injected clock. The clearly labeled Estimated reading deliberately equals the latest actual reading; this is a deterministic mock, not a production estimator.

Add/edit vehicles and items, log/edit/delete services (including zero-operation mileage updates), archive/restore items, browse linked history, edit Settings, and sign out through the account menu. Units are fixed at vehicle creation. A month is 30 days. The garage previews three due items, with the remainder opening Due. The bottom bar always contains exactly Vehicles and Settings in the signed-in shell.

Hash routes support `/vehicle/<id>?tab=0|1|2`, `/item/<id>`, `/service/<id>` and `/settings`, for example `http://localhost:8765/#/vehicle/runner`. Authentication restores the requested saved-record route; inaccessible IDs show Not found. Forms retain their saved parent URL on refresh; unsaved drafts survive navigation guards and temporary reauthentication only in the running process.

## Reset and state demonstrations

Sign out to clear the current demo account's records and session. Sign in again to re-seed. Settings survives sign out. Clear site/application storage to reset everything. To start with an empty garage, sign out first, then run with `--dart-define=TW_EMPTY=true`.

Optional launch defines (outside the product UI):

| Define | Behavior |
| --- | --- |
| `TW_EMPTY=true` | Seed no vehicles for a new/reset account |
| `TW_OFFLINE=true` | Restore saved data/as-of state; disable maintenance writes. Sign in online once first |
| `TW_FAIL_LOADS=true` | Simulate fetch failure; Retry state without implying an empty garage |
| `TW_FAIL_WRITES=true` | Fail maintenance saves while retaining form fields |
| `TW_DELAY_MS=2000` | Slow asynchronous loads/saves to inspect pending states |

While running, Ctrl+Alt+O toggles simulated offline mode and refreshes the saved snapshot; Ctrl+Alt+F toggles save failure; Ctrl+Alt+E expires the mock session. Reauthenticate to resume the same form. These are developer keyboard bindings, not additional Settings fields. Toggle failure back off and retry the retained draft. Programmatic fake dependencies in tests exercise the same recovery paths.

## Scoped checks

```sh
dart format lib test
flutter analyze
flutter test
flutter build web
```

Tests cover threshold boundaries, chronological readings, account/session persistence, storage round-trips, atomic mutations/failures, mileage-only and linked saves, edit/delete recalculation, archive/restore, past-date suggestions, dirty navigation and phone/wide layouts with increased text scale. Dependency tests prevent UI-to-Service bypass and legacy/shared runtime imports.

## Replacement scope and limitations

Removed the old login controller/state/control, home page, API client factory, app bootstrap behavior and obsolete auth tests. Removed shared, HTTP/interoperability, JSON API and URL-launcher runtime dependencies (including transitive real-auth packages). Flutter tooling regenerated platform plugin registrations. Retained package/application identity, platform runners, assets, build configuration and UX references; updated web presentation metadata and the Android display label and removed the release Android internet permission. No server/shared code or root build metadata was changed.

Local preferences are appropriate for this demo, not a production multi-process database. Real authentication is outside the prototype scope. Verification on this host: formatting and analysis passed; all 19 scoped tests passed; the release web build passed. Phone (390px) and wide (1100px) Flutter render captures were visually inspected; 320px/200% text scale was checked for overflow. Chrome was launched with `flutter run -d chrome`; mock sign-in, preview navigation, mileage-only save, recalculated status and persistence after reload were verified through the live UI. macOS release build/startup, mock sign-in, mileage save and session/data persistence after app restart also passed. The web build emitted a non-fatal optional Cupertino icon-font warning; Material icons are bundled. Drafts are not persisted across process termination; service history is locally batched rather than fetched from a remote server.


## Native build compatibility

`shared_preferences_foundation` is explicitly pinned to 2.5.7. Version 2.6.0's generated Swift failed to compile with this host's Xcode 16.0; the 2.5.7 implementation builds with the same repository/Service API. Keep this constraint until upgrading and rechecking the Apple toolchain.

```sh
flutter build macos --release
flutter run -d macos --release
flutter build apk --debug
flutter build apk --release
flutter build ios --release --no-codesign
```

The macOS release build and Android debug/release APK builds passed on this host. Gradle installed the configured Android NDK, CMake, platform and build tools using the existing SDK licenses. No Android emulator/device was connected, so Android runtime behavior is unverified. After installing iOS 18, the unsigned iOS release build passed (`build/ios/iphoneos/Runner.app`). The app also built and launched on the iPhone 16 Pro iOS 18.0 simulator; mock sign-in, due navigation and a mileage-only save were verified through the live UI. A Flutter hot restart restored the session and saved 91,700-mile reading. Signing is still required for physical-device deployment; no signed device/archive validation was performed. Windows/Linux require their respective build hosts and were not built here.
