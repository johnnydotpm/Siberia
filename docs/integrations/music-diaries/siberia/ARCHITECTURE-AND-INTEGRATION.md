# SiberiaGB: implementation handoff for Fryderyk and MobiReg

## Scope and evidence

This is a source-based integration design, not a claim that either new provider is implemented. It was prepared on 2026-10-25 against `johnnydotpm/Siberia`, branch `main`, commit **`c09caaa5f2780a9e1c60aaf94bf9e02e25fe4efc`**, application version `1.4.0+15`. All source paths below are repository-relative. The application directory is spelled **`syberia/`**, while the repository is `Siberia` and the product is `SiberiaGB`.

No `AGENTS.md` was found by the repository file inventory. Recheck local instructions and HEAD before implementing. This report treats repository text as source evidence; user instructions are the authorization for this work. The app-specific reverse-engineering reports supply protocol evidence. Proposed types and new filenames in this document are design recommendations, not recovered upstream APIs.

Do not call a candidate backend merely because an endpoint string appears in a binary. A feature is ready for implementation only when its request builder/authentication/response mapping is sufficiently recovered or a user-authorized account capture supplies the missing contract. Record unsupported and unknown operations explicitly.

## Current architecture and constraints

| Area | Existing source | Observed behavior and implication |
|---|---|---|
| Composition | `syberia/lib/main.dart`, `lib/src/app.dart`, `lib/src/startup.dart` | Flutter app with a startup boundary. Keep immediate local loading and launch sync behavior. |
| Repository | `syberia/lib/src/data/app_repository.dart` | Concrete `AppRepository`, constructor-injected concrete `LibrusClient`, `Dio`, preferences, secure storage, and `SnapshotStore`. Its comment anticipates connectors, but no provider interface exists. |
| Protocol | `syberia/lib/src/data/librus/librus_client.dart` | `LibrusClient`, `LibrusPart`, Portal/Synergia sessions, JSON/XML/web mailbox fallbacks. Keep this protocol inside a Librus adapter. New clients must not reuse Librus URLs, refresh logic, or mailbox assumptions. |
| Reference cache | `syberia/lib/src/data/librus/reference_cache.dart` | Librus-specific `librus_references_v1.json`, 24-hour maximum age and account check. New providers need separate, account-scoped reference caches if their APIs use reference IDs. |
| Domain | `syberia/lib/src/domain/models.dart` | `StudentProfile` holds only `id`, `name`, `school`, display string `provider`. `AppSnapshot` holds lessons, grades, events, inbox, sent messages, attendance, announcements, notices, free days, last sync and one mailbox error. |
| State | `syberia/lib/src/state/app_controller.dart` | `ChangeNotifier`; exposes Librus login and linked Synergia accounts, sync, messaging, timetable weeks, preference actions. Async safety mostly compares `snapshot.profile.id`. That is insufficient when two providers or schools return the same ID. |
| Snapshot persistence | `syberia/lib/src/data/snapshot_store.dart` | One `librus_snapshot_v1.json`, with legacy `last_librus_snapshot_v1` preference fallback/migration; writes are queued and atomically renamed. Generalize identity without losing that behavior. |
| Serialization | `syberia/lib/src/data/snapshot_cache.dart` | No top-level schema version. Optional old fields are accepted; broad decoding failure returns null. Add explicit schema/version migration and preserve old cache decoding. |
| Errors | `syberia/lib/src/domain/librus_error.dart` | The comment calls the vocabulary provider agnostic, but types are `LibrusErrorCode` / `LibrusException` and include Synergia/Portal-specific cases. `AppError.from` recognizes only `LibrusException`. |
| UI | `syberia/lib/src/ui/app_shell.dart`, `lib/src/ui/shell/*.dart` | Ten fixed pages, numeric indices and cached page widgets. Librus-only login/account sheet in `shell/account.dart`; fixed shell entries must become capabilities-driven for provider-specific modules. |
| Localization | `syberia/lib/src/l10n/app_localizations.dart` | Existing Polish, English, Russian, German, Ukrainian maps. Add provider/auth/feature/error labels in all five languages. Avoid literal backend diagnostics as the default UI text. |
| Notifications | `syberia/lib/src/school_notifications.dart` | Eight categories: grades, messages, announcements, notices, attendance, events, homework, timetable. Snapshot diff and test/homework reminders; seen keys only include `profile.id`. |
| Background | `syberia/lib/src/background_notifications.dart` | A fresh `AppRepository` is constructed inside Workmanager isolate. Android periodic task every 30 minutes with network/battery constraints. iOS dispatcher is accepted, but periodic registration currently returns except on Android. Do not promise iOS polling parity. |
| Widgets | `syberia/lib/src/home_widget.dart` plus Android/iOS native files | Shared lesson JSON `v: 1`, 14-day horizon, maximum 60 lessons; excludes cancelled lessons. Controller currently clears it for non-Librus/non-demo profiles. |
| Homework completion | `syberia/lib/src/homework_done.dart` | `homework_done_v1` is global local-only data keyed by event ID; logout removes it. A new backend completion/submission state must remain a separate concept. |
| Demo | `syberia/lib/src/data/demo_data.dart` | Fictional in-memory account, long press login logo for 5 seconds. Keep demo offline and nonpersistent; use it to demonstrate provider-specific modules without real credentials. |

### Existing hard gates that will silently break a naive provider addition

Search these exact strings/types before and after the refactor:

```powershell
rg -n 'Librus Synergia|Signed out|profile\.id|LibrusPart|loginLibrus|SynergiaAccount' syberia/lib/src
```

At this baseline:

1. `AppRepository.load()` accepts only `profile.provider == 'Librus Synergia'`; any other stored provider is removed and the app loads signed out. Adding only a new client and profile name will lose the account on restart.
2. `AppRepository.sync()` returns a delayed copy with a new timestamp for non-Librus profiles, without fetching a backend. A visible successful refresh can therefore be false success.
3. `fetchBackgroundSnapshot()` rejects non-Librus profiles and takes `Set<LibrusPart>`.
4. `AppController.startAutoSync()`, `configureBackground()`, `_updateHomeWidget()`, notification permission logic and `refreshSentMessages()` all test the Librus display string.
5. `AppShell.build()` returns the login screen for a non-Librus/non-demo profile.
6. `SchoolNotificationService._updateReminders()` and `processSnapshot()` reject non-Librus profiles.
7. The account sheet offers linked Synergia accounts for any non-demo signed-in account; replace that control with provider-aware account/child/school selection.
8. Repository/controller cache and in-flight result guards compare only `profile.id`, including Sent-folder preservation and message updates. Namespace them by full account context and session generation.

Merely replacing these strings with a three-element allowlist is an interim compatibility patch, not a complete integration architecture.

### Existing data semantics that must survive

- Foreground bootstrap reads local data before launch sync; manual-only mode continues to work offline.
- Sync preserves the previous inbox when fetching messages fails for the same account; it preserves Sent because a regular sync does not load Sent.
- The repository preserves later timetable weeks on refresh. That logic currently uses `librusSyncWeekStart`; move the range semantics behind the provider or generic sync result instead of assuming all services use the same week coverage.
- Background sync skips within 20 minutes of a saved sync and downloads only notification/reminder parts; unfetched parts are retained. Events and homework currently arrive together. That coupling belongs to Librus and should not be forced onto other providers.
- Snapshot writes are atomic, but the in-object write queue is not a cross-isolate lock. A new provider must prevent a slower background response overwriting a newer foreground state or a newly selected account.
- Opening a Librus message fetches it and marks it read. `markAllMessagesRead()` loops over content fetches. Some new services may expose an explicit read action; do not assume the Librus side effect.
- Sending currently constructs an optimistic Sent item only after the server returns an ID. Keep server confirmation and do not automatically retry ambiguous writes.
- Widgets and reminders are regenerated when state changes and cleared on logout. Preserve this on provider/account/school/year changes too.

## Recommended architecture

### 1. Stable session identity and selected data context

Introduce a stable `ProviderId` (`librus`, `fryderyk`, `mobireg`) independent of translated display names. Keep legacy display string decoding for migration. Separate the owner of an authenticated session from the selected scope of school data. Fill their exact remote fields from recovered provider evidence:

```dart
// Proposed sketch, not an existing interface or recovered wire format.
class AuthSessionOwner {
  final ProviderId providerId;
  final String canonicalOrigin;
  final String accountId;
  final String? tenantId;        // school/organization when auth is tenant-bound
  final String? deviceAuthId;    // only when independent device auth is established
}

class AccountContext {
  final AuthSessionOwner sessionOwner;
  final String? studentId;       // chosen child; not necessarily login owner
  final String? academicYearId;
}
```

Use an unambiguous canonical encoding/hash of the session owner for secure authentication records and refresh coordination. Use the complete selected `AccountContext` for snapshot/module caches, local marks, notification history and state guards. Do not concatenate unescaped IDs with `/`, `:` or `|` and assume collision freedom. Full data-context equality determines whether snapshots can be merged. A monotonic context generation invalidates older in-flight data results after selection, even if the user later returns to the same context. A separate auth generation invalidates old authentication results after logout/reconnect.

When one access/refresh pair serves several children or years, retain one session-owner record and one refresh lock shared by those scopes. Do not duplicate a rotating refresh token into independently refreshed child/year credential records: one refresh can invalidate the other copies. Introduce separate child/module auth owners only when provider evidence establishes independent sessions. Module cookies and tokens must still retain their exact proven origin/audience and lifecycle. Selecting a child/year need not revoke a shared parent session; logging out that session invalidates its dependent data contexts.

Authentication can be a staged flow: provider selection → required server/school discovery → credential/QR/link challenge → child/account/year selection → ready. Only show stages the provider evidence supports. `LinkedSynergiaAccount` is Librus-specific and should remain inside that adapter, mapped to a generic `AccountChoice` where appropriate. Do not rename a parent login into a student ID.

Keep one selected context initially while allowing multiple saved contexts. This limits disruption and still supports school/child selection. An aggregated multi-account dashboard is a separate product decision; prevent accidental mixed snapshots while the implementation is single-selected-context.

### 2. Protocol adapters and capability model

Suggested new files:

```text
syberia/lib/src/domain/provider.dart
syberia/lib/src/domain/account_context.dart
syberia/lib/src/domain/provider_error.dart
syberia/lib/src/data/providers/diary_provider.dart
syberia/lib/src/data/providers/provider_registry.dart
syberia/lib/src/data/librus/librus_provider.dart
syberia/lib/src/data/fryderyk/fryderyk_client.dart
syberia/lib/src/data/fryderyk/fryderyk_provider.dart
syberia/lib/src/data/fryderyk/fryderyk_models.dart
syberia/lib/src/data/mobireg/mobireg_client.dart
syberia/lib/src/data/mobireg/mobireg_provider.dart
syberia/lib/src/data/mobireg/mobireg_models.dart
```

Retain `AppRepository` as the local-first orchestration boundary. It selects an adapter from a registry; the UI never branches on URLs, XML names, raw action codes or auth tokens. Inject registry/transport/storage for tests. The registry must also be constructible in the Workmanager isolate without a widget tree.

Use a generic `SyncPart` in domain code; map to `LibrusPart` internally. Expose a base session/sync interface plus optional typed operation interfaces for messaging, absence justification, required-poll answers, homework solutions and other evidenced modules. Avoid a giant interface whose unsupported methods pretend to succeed.

Capabilities are **per context and current permission**, not merely per brand. Represent at least `supported`, `unsupported`, `unknown`, and `temporarilyUnavailable`, plus role/permission requirements and reason codes. Distinguish read, create, edit, delete, attachment upload/download, read receipts, pagination, and server-side completion. An endpoint's existence does not establish permission for a student/parent/teacher account. Preserve service-denied modules without discarding the whole account.

Unknown operation contracts must remain disabled with a tracked evidence gap. A feature advertised by one supplied version is not automatically available in the other platform/version.

### 3. Partial fetches, pagination, and state

Have each sync return typed module outcomes: success with complete/range coverage, unchanged, unsupported, permission denied, authentication required, or failure. Include server cursor/revision/time where actually available, plus local fetch time. An empty result is only a deletion/replacement when the provider confirms complete coverage for that module/range.

Do not overwrite cached grades/lessons/messages because an optional module request failed. Extend `AppSnapshot` or compose module stores so every module can carry freshness/error state, rather than only `messagesError`. Preserve unfetched parts and merge paginated/ranged responses using stable provider IDs. Store cursors only alongside the correct account/school/year and reset them on scope changes.

Deduplicate token refresh and session bootstrap per authenticated session owner, sharing that coordination across its child/year data contexts. Bound safe read retries and distinguish transport failure, explicit auth expiry, malformed response, rate limiting, school maintenance and permission refusal. Mutation retries require a provider-supported idempotency key or proof that the previous request did not commit; otherwise present an uncertain outcome and offer a refresh.

### 4. Domain mapping and loss prevention

| Existing model | Reuse | Required decision before mapping new provider data |
|---|---|---|
| `StudentProfile` | Display name and school | Add stable provider/context/role/year/child identity; school display text is not a tenant identifier. |
| `Lesson` | Subject, teacher, room, actual start/end, cancellation/substitution | Music lessons may have arbitrary lengths and no lesson number. Preserve actual timestamps; allow ensemble/individual/group metadata and source lesson ID. Do not invent a fixed 45-minute period. |
| `Grade` | Raw string value, date, description/category | Current mandatory `double weight` and integer semester can misrepresent unknown weight, points or annual/exam results. Preserve native grading scheme, raw value, optional numeric value/weight, period ID/name and classification. Gate average/calculator by compatible grading scheme. |
| `SchoolEvent` | Event/homework/exam display | One date and three kinds are insufficient for multi-day appointments, deadline + publish date, submission state or lessons/tasks with media. Add typed structures rather than encoding fields into the title. |
| `SchoolMessage` | Inbox/Sent list basics | Add opaque recipient IDs (`MessageRecipient.id` is currently **int**), thread/folder/type IDs and per-recipient receipts only if supplied. Distinguish unknown receipts from false. |
| `SchoolMessageContent` | Text, attachments, receivers | Current body is a string and attachments only have ID/name. Add content format, MIME/size metadata and authenticated download abstraction. Current UI launches attachment URL externally; this fails when a download requires bearer/cookie headers. Implement a provider-owned authenticated download stream or explicitly supported one-time URL. |
| `AttendanceRecord` | Date, subject, raw type/symbol, broad kind | Keep provider attendance ID/type and optional actual duration/lesson ID. A justification request has workflow/status/reason/attachment and is not equivalent to locally changing `kind`. |
| `SchoolAnnouncement` / `StudentNotice` | Announcements and remarks | Preserve type, author, visibility, read/action metadata. Do not collapse unrelated correspondence/consent/status objects into generic notices. |
| `FreeDay` | Holiday/teacher absence display | School calendars and teacher absences may be fetched separately; retain supplied scope and affected groups. |
| No existing model | — | Add dedicated models and screens for evidenced modules lacking a faithful home: typed exams/term assessments, absence-justification workflow, required-poll answers, rich homework solutions and provider-specific mailbox state. Use the provider reports to determine which modules apply; do not introduce hypothetical music-school features. |

Keep provider DTOs separate from shared domain models. Unknown fields/enums should not crash the account or be silently coerced into a false category. Add forward-compatible raw codes/labels and traceable source IDs. Avoid storing secrets or signed URLs in general snapshot JSON.

Treat school date-only values as dates, schedule times with the school's timezone, and timestamps as instants. Poland's DST changes and account viewing from a different timezone must not shift an event date. Include 30- and 60-minute lessons, overlapping individual/group sessions, weekends, moved/cancelled sessions, no period number and academic-year transitions in fixtures.

### 5. Storage and migration

Current keys that require deliberate handling:

| Legacy key/file | Owner | Migration |
|---|---|---|
| `active_profile_v1` | `AppRepository` preferences | Decode legacy Librus profile into explicit Librus context; introduce versioned selected-context record. Do not discard it merely because the new display name changed. |
| `active_profile_credential` | repository secure storage | Retain until its actual usage is verified; do not mistake it for the full Librus session. |
| `syberia_portal_session_v1` | `LibrusClient` secure storage | Migrate/wrap only inside Librus adapter; leave original until new session restore succeeds. Never reinterpret as a MobiReg/Fryderyk token. |
| `last_librus_snapshot_v1` / `librus_snapshot_v1.json` | snapshot store | Import as Librus v1, add schema version and context binding. Only mark migration complete after successful atomic write/read. |
| `librus_references_v1.json` | Librus reference cache | Keep isolated; do not share reference dictionaries with other providers. |
| `homework_done_v1` | local completion store | Attach existing marks to migrated selected Librus context; namespace future marks. Keep local completion separate from server submission/completion. |
| `school_notifications_seen_v1_<profile.id>` | notification service | Import for the known migrated Librus account; new key uses full account context. Initialize new contexts without replaying all historic notifications. |
| `subject_short_names_v1` | repository preferences | Decide documented global vs account behavior. Subject display aliases may stay global by design, but colliding labels across schools must be considered. |

Use session-owner-scoped secure-storage records for auth material, selected-data-context-scoped schema-versioned snapshot/module files, and atomic writes. Store the selected context separately from saved session owners/accounts. A logout must clear the target auth owner and its dependent contexts' cached sensitive data, downloads, scheduled reminders and widget payload, and invalidate in-flight operations. It must not erase unrelated auth owners if multiple accounts are retained. Switching a child/year clears active UI/platform state and changes data scope without deleting shared parent auth unless the recovered protocol requires it. Do not log credentials, QR registration payloads, refresh/access tokens, full personal records or attachment URLs with credentials.

### 6. UI and platform surfaces

Replace `_Login` and `_LinkedSynergiaAccounts` with provider selection plus typed flow screens, retaining the Librus flow behind its adapter. Let the provider evidence define whether a server address, school search, registration code, QR or username/password is needed. Validate origins and ensure credentials are only sent to the selected legitimate tenant. Show account, provider, school, child and academic year in the account sheet where supported.

Replace fixed page indices as persistent identity with stable screen IDs. The current `_pageCount = 10`, `_page(index)`, navigation title/action switches and controller `tabIndex` all assume a fixed screen list. Capabilities should hide unsupported actions and omit irrelevant pages, preserve a sensible selected page after account changes, and invalidate `_pages` when context/capabilities change. An empty module and an unsupported module need different UI states. Add new module pages according to the complete app feature catalog; existing ten pages are not the definition of parity.

Keep existing Glass/classic layouts, wide navigation, accessibility, search, sorting and five-language support. Provider-specific operations should be discoverable from their corresponding modules. An absence justification or required-poll answer must show its actual server status. A homework solution submission must represent upload/progress/acknowledgement only where that provider's write contract is established; do not show a local checkbox as a successful server update.

Notification settings should intersect categories with active provider permissions; preserve stored preferences when temporarily unsupported. Background selection should ask each adapter for its cheapest supported partial fetch. Existing 30-minute Android registration and 20-minute pause are implementation choices, not claims about vendor push. Proprietary FCM/APNs registration requires a separately established contract and deployment configuration; polling and local notifications can provide initial support. Keep iOS background limitations explicit.

Widget payload v1 can remain unchanged if the normalized lesson fields suffice. Remove controller's Librus gate, clear payload immediately on context switch/logout, and ensure delayed old results cannot repopulate it. Native paths to examine if adding account labels/context or changing payload schema:

- `syberia/android/app/src/main/kotlin/app/syberia/client/HomeWidgetChannel.kt`
- `syberia/android/app/src/main/kotlin/app/syberia/client/NextLessonWidgetProvider.kt`
- `syberia/android/app/src/main/kotlin/app/syberia/client/WidgetConfig.kt`
- `syberia/ios/Runner/HomeWidgetPlugin.swift`
- `syberia/ios/SiberiaWidget/HomeWidgetStore.swift`
- `syberia/ios/SiberiaWidget/SiberiaWidget.swift`

## Sequenced implementation tasks for future agents

### Task A — Freeze contracts and resolve blocking evidence

Read the app-specific feature/API reports and evidence ledgers. Produce one row per feature/action with provider, platform/version, role, source locator, request/auth/body/response/error/pagination knowledge, required shared model/screen and completion status. Separate read/write contracts. Resolve bootstrap authentication, school/child/year selection and one end-to-end read path before pretending a connector is usable.

Acceptance: every recovered feature appears in the tracker; unsupported/unknown is explicit; no fabricated endpoint/body examples are treated as production contracts. Record which runtime/account evidence still requires user participation. Do not remove unknown features from the parity denominator to make completion appear higher.

### Task B — Provider boundary while preserving Librus

Add stable identities, generic sync vocabulary, adapter registry, capabilities and provider-neutral error categories. Wrap the existing `LibrusClient` first. Refactor `AppRepository` and controller to route through it; preserve its transport/fallback tests.

Acceptance: existing Librus behavior, linked accounts, demo, offline startup, sent messages, widgets and reminders pass existing tests. No UI/backend orchestration checks a provider display string for signed-in status. A fake second provider with colliding remote IDs demonstrates correct dispatch and isolation.

### Task C — Account-scoped storage and race protection

Implement schema-versioned caches and v1 migration. Namespace secure sessions and refresh locks by authenticated session owner; namespace snapshots, local marks, reference lists and notification history by their proven data scope. Add data-context generation checks at repository persistence and controller state assignment boundaries, and auth-generation checks to session restoration/refresh. Handle foreground/background races and logout during requests without copying a shared rotating refresh token into independently refreshed child/year records.

Acceptance: a seeded v1 Librus installation survives upgrade without data/account loss; two providers and two children returning `id = "1"` cannot see each other's data; child/year switching preserves shared auth where supported; concurrent requests across those scopes refresh a shared token only once; old data/auth responses after selection/logout are ignored; interrupted migration is restartable; corrupted optional module data does not silently sign out an otherwise valid account.

### Task D — Fryderyk protocol and mapping

Build transport, session, typed DTOs and read/mutation methods from the Fryderyk evidence, preserving version/role differences. Map faithful common modules and add provider-specific module models. Test with sanitized fixtures first. Do not reuse branded client secrets or runtime credentials from artifacts as project configuration.

Acceptance: authentication/restore/expiry/account selection are demonstrated against fixtures and then an authorized account; all established modules have paginated/ranged loading, error states and tested mapping. Unknown contracts remain in the evidence tracker with a concrete next probe.

### Task E — MobiReg protocol and mapping

Follow the MobiReg evidence, explicitly separating older Android and newer iOS contracts when they differ. A database table or DEX method is evidence of a schema/client capability, not proof that a modern school server still accepts it. Keep protocol generations isolated until confirmed compatible.

Acceptance: same lifecycle and complete-feature requirements as Task D; version differences are tested rather than guessed; IDs/permissions/years remain scoped correctly; no legacy sync deletion can wipe unrelated new module data.

### Task F — All user-facing modules and actions

Implement provider login/account selectors, capabilities-driven navigation and each feature catalog item. Reuse common views only when semantics fit. Add the evidenced exam/term, justification, poll, rich homework/solution and mailbox/attachment views missing from existing screens. Mutation UI waits for server confirmation and represents failures/uncertainty accurately.

Acceptance: every feature/action tracker row links to implemented UI/controller/repository/client and verification case, or remains explicitly blocked with evidence required. Both student/parent/other supported roles and denied permissions are covered. No action is shown enabled because a module is merely listed in binary strings.

### Task G — Notifications, background, widgets, release verification

Generalize notification candidates and settings, generic partial-sync routing, account-scoped seen state, reminder lifecycle and widget updates. Preserve battery/manual-only behavior. Update README/provider support matrix and localized unofficial-provider wording. Add clear per-platform supported/limited states.

Acceptance: no history flood on first login; changed grades/attendance trigger intended notifications; failed partial sync causes no false removals/alerts; switching/logging out clears old reminders/widgets; Android polling works from a fresh isolate; iOS scheduling limitations are documented and tested on device where implemented.

## Verification plan and existing tests to retain

Use sanitized fixtures recorded from recovered code or explicitly authorized sessions. Keep a provenance manifest per fixture: provider/version, action, source locator/capture ID, redaction rules and what is synthetic. Do not label analyst-created JSON as observed backend output.

| Concern | Existing tests to retain/extend | New cases |
|---|---|---|
| Protocol/auth | `syberia/test/librus_client_test.dart` | New `fryderyk_client_test.dart`, `mobireg_client_test.dart`: exact method/path/query/body/headers; refresh once per shared auth owner under concurrency across child/year scopes; malformed/empty/denied/rate-limited responses; pagination, version differences. |
| Storage/startup | `startup_test.dart`, `auto_sync_test.dart`, `speed_test.dart`, `demo_mode_test.dart` | v1→new migration, restart, corrupt files, scoped key collisions, old background responses, demo persists nothing. |
| State/races | `app_controller_test.dart`, `sent_messages_test.dart`, `timetable_sync_test.dart` | Context switch/logout during every async operation; same remote ID across providers/schools/children; Sent preservation only for same context; per-part failures. |
| Notifications | `background_check_test.dart`, `school_notifications_test.dart`, `notification_kinds_test.dart`, `test_reminders_test.dart` | Registry creation in fresh isolate, unsupported parts never fetched, generic categories, scoped seen state, no duplicate history, clear old reminders. |
| Widgets | `home_widget_test.dart` and native widget checks | Music lesson lengths, weekends, DST, no period number, cancellations, provider switch and late response; preserve payload-v1 compatibility. |
| Domain screens | `attendance_by_subject_test.dart`, `attendance_navigation_test.dart`, `grade_average_test.dart`, `grade_calculator_test.dart`, `homework_test.dart`, `homework_done_test.dart`, `message_read_and_layout_test.dart` | Unknown grading scales, annual periods, real lesson times, opaque recipient IDs, explicit read action, authenticated download, remote task status vs local checkboxes. |
| UI/localization | `widget_test.dart`, `glass_shell_test.dart`, `ui_consistency_test.dart`, `localizations_test.dart`, `screen_preferences_test.dart` | Provider/role capabilities, stable selection when pages change, empty vs unsupported, every new module in wide/classic/glass and all five languages. |

Baseline CI (`.github/workflows/build.yml`) pins Flutter **3.47.4**, runs locked dependency resolution, Dart format, `flutter analyze --fatal-infos`, full Flutter tests, and macOS Swift type-check of iOS widgets. The local `pubspec.yaml` requires Dart `^3.13.3` at this commit. Future agents should follow repository-pinned versions rather than relying on this report as a current SDK recommendation.

Run from `syberia/` after implementation:

```text
flutter pub get --enforce-lockfile
dart format --output=none --set-exit-if-changed lib test
flutter analyze --fatal-infos
flutter test
```

Build Android/iOS or run their existing workflow when native plugins, auth callbacks, download handling, notifications or widget code change. Verify Windows/Linux for any new platform-dependent plugin or filesystem behavior. No implementation tests were run for this documentation-only source investigation; commands above are future acceptance steps, not claimed results.

## Definition of completion

Support is complete only when every functionality established by the supplied artifacts is accounted for in the shared feature tracker, all implementable contracts have working provider adapters and suitable UI, the residual unknowns have either been resolved or are transparently reported as blockers, and existing Librus behavior remains intact. A connector returning only the fields already present in `AppSnapshot` is not full feature support.
