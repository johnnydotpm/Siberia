# Source patch plan

All paths in this document are relative to the Siberia repository; the app is in **`syberia/`**. Literal anchors are captured in `source-anchors.json` with file hashes and one-based lines. Use the anchors to find the edit; line numbers are navigation aids only. Do not apply a blind global replacement of `Librus`.

## Foundation composition and data flow

```text
Flutter screens
  → AppController (selected DataScope + generation)
  → AppRepository (local-first state and module merge)
  → provider registry (ProviderId)
  → adapter (DTO decode, auth owner/module session, operation selection)
  → sibling Dart RequestSpec/planner → concrete Dio transport

AuthOwner store       → shared credential/token refresh per auth owner
DataScope module store→ normalized modules + freshness/coverage/errors/cursors
                        ↓
AppSnapshot projection for current screens + typed provider modules
                        ↓
notification diff / reminders / native widget payload
```

In a future implementation, add a Flutter binding layer under `syberia/lib/src/data/providers/` following the proposed interfaces in the parent `DESIGN.md`. Keep `dart:io`, FlutterSecureStorage, SharedPreferences, Dio and platform plugins out of its pure Dart contract layer. The app binding executes prepared requests, persists sessions and maps DTOs; a planner test passing would not establish a decoder/session/transport implementation. This deliverable supplies documentation only, not that layer's source.

Use one registry factory, callable both during app startup and from the fresh Workmanager isolate. Initially register an adapter wrapping unchanged `LibrusClient` and the two new diary adapters. `ProviderId.mobireg` has an explicit **protocol profile**, modern or legacy; do not register legacy and modern as unrelated products or choose a profile solely from Android/iOS. Their password and transport contracts differ.

Shared kit types are authoritative. App-facing optional capabilities should use typed interfaces, for example mailbox read/send/upload and justification read/mutate; do not add dozens of nullable callbacks to `AppController`. The operation catalog namespace qualifies dispatch and capability checks; an arbitrary route name passed by the UI is not an operation selector.

## Exact existing-file recipes

### `syberia/lib/src/domain/models.dart`

Anchors: `class StudentProfile`, `class Lesson`, `class Grade`, `class SchoolEvent`, `class SchoolMessageContent`, `class MessageRecipient`, `class AppSnapshot`, `AppSnapshot copyWith({`.

1. Add explicit selected `DataScope` metadata to the profile/snapshot boundary. Preserve `StudentProfile.id` as a display/source identifier for existing tests; do not use it as a global cache key. Keep display `provider` text for compatibility while routing via `ProviderId`.
2. Change shared recipient identity to an opaque string value, or add `remoteId` alongside a deprecated int accessor while migrating callers. The Librus adapter alone converts a verified numeric string back to its numeric wire field. Modern MobiReg normalizes numeric mail IDs to `user_<digits>`; Fryderyk recipient keys must remain intact.
3. Add the DTO-mapping document's typed period/grade, timetable metadata, homework/solution, mailbox folder/receipt, justification and poll models. Preserve raw codes and source identity. Do not put a justification request into `AttendanceRecord.kind` or a server solution into the local done store.
4. Keep `AppSnapshot` as an initially backward-compatible projection. Add typed module outcomes or an adjacent `DiaryState` containing per-module value, status/error, fetch time and coverage. Projection lists may be empty only when a successful complete module says so. An unsupported/error list must not erase the previous value.
5. Extend `copyWith` deliberately: its current signature cannot replace grades/attendance/announcements/notices/profile/error. Use nullable-clearing sentinels or typed module updates rather than `null` meaning both “clear” and “unchanged”. Add cache round-trip cases for new optional fields and legacy snapshots.

### `syberia/lib/src/domain/librus_error.dart`

Anchors: `enum LibrusErrorCode`, `class LibrusException`, `factory AppError.from(Object error)`.

Introduce provider-neutral operation errors at the binding boundary using the shared kit outcome/error vocabulary. Keep a compatibility translator from `LibrusException` so existing client/tests can remain stable first. Preserve provider, operation ID, recoverable category, HTTP status and remote error code in structured diagnostic fields; display localized safe text. Do not classify every parsed failure as auth expiry or automatically display raw response bodies. Required new states include enrollment required, permission denied, module-session expired, incompatible protocol, malformed response, rate limit, uncertain mutation and partial upload. Never turn unsupported into a successful empty module.

### `syberia/lib/src/data/app_repository.dart`

Anchors: constructor `LibrusClient? librusClient`, field `final LibrusClient _librusClient`, `_profileKey`, `Future<AppSnapshot> load()`, `loginLibrus`, `sync(AppSnapshot current)`, `fetchBackgroundSnapshot`, `_keepLaterWeeks`, `_keepUnfetchedParts`, `logout`, messaging/timetable methods.

1. Add injectable provider registry and scoped state/session stores. Preserve the `librusClient:` constructor compatibility argument until existing test factories are migrated; wrap it in a Librus adapter rather than rewriting protocol logic in the repository.
2. `load()`: migrate/read selected `DataScope`, resolve its provider, then load that scope's last projection without networking. Remove the branch that deletes every non-`Librus Synergia` profile. An unknown future provider ID must yield a recoverable unsupported-provider state with its saved data retained, not destructive sign-out.
3. Login methods: keep `loginLibrus` as a compatibility facade, add a typed enrollment workflow behind provider selection. Save the auth owner only after authenticated validation and then save the selected child/data scope. Fryderyk identify-returned `url` is a separate data origin; MobiReg accounts own page/school/login/password/JWT and child scopes depend on them. See deep auth contracts.
4. `sync`: capture selected scope, auth generation and data generation **before await**; ask the adapter for requested module outcomes; merge only matching, successful coverage; persist with a stale-generation check; project into `AppSnapshot`. Delete the non-Librus fake timestamp-success branch. A global `lastSync` advances only by a documented aggregate rule; every module has its own successful fetch time.
5. `_keepLaterWeeks`: use explicit fetched range coverage from the adapter. Librus may continue `librusSyncWeekStart` internally. Fryderyk day fetches and MobiReg date ranges must not replace arbitrary other weeks. Preserve later cached days, deduplicate stable lesson source IDs, honor confirmed deletions only within the returned complete range.
6. `_keepSent`, `_preserveCachedMessages`, `_updateCached`: guard by canonical `DataScope` and generation. A stale foreground request must not write after child/provider switch even when `profile.id` matches. Separate account-owned mailbox content from child-linked presentation when the provider contract establishes account-level mail.
7. `fetchBackgroundSnapshot`: take generic requested modules/capabilities, intersect supported reads, restore provider/auth owner from persisted context using the same registry, preserve unfetched/failed parts. Keep manual-only and pause behavior; compare persisted revision before commit to prevent overwriting a newer foreground snapshot. Session refresh coordination belongs to the auth owner, including cross-isolate persistence.
8. `fetchMessageRecipients`, `sendMessage`, `fetchSentMessages`, `fetchMessageContent`, `fetchMessageAttachmentUrl`, `fetchTimetableWeek`: delegate through typed capabilities. Replace URL-only attachment method with an attachment download result/stream abstraction while retaining a Librus URL compatibility path. Add typed folder pagination/search/mark-read/CC/BCC/draft upload/delete/restore as needed. Do not automatically call all mutations from sync.
9. `logout`: invalidate generation first, clear the target auth owner and its dependent scoped modules/downloads/notifications/widget, retain other saved accounts. Distinguish local remove account from server account deletion. Fryderyk recovered logout deletes local keys/cache; do not invent a revocation request. No new server logout route should be sent unless established.

Retain the GitHub release-checking Dio client and global visual settings as separate dependencies; adding a diary provider must not route release requests through a school transport.

### `syberia/lib/src/data/snapshot_store.dart`

Anchors: `static const preferencesKey = 'last_librus_snapshot_v1'`, `static const fileName = 'librus_snapshot_v1.json'`, `_resolveFile`, `read`, `write`, `clear`, `_enqueue`, `_writeRaw`.

Keep the existing atomic temporary-file rename and off-UI-isolate serialization. Add `DataScope`/schema-versioned storage paths under app support, constructed from canonical encoded/hashed keys rather than remote names. Pass an explicit scope to read/write/clear. Legacy singleton keys remain read sources during migration only. Do not allow a late `clear()` of account A to delete selected account B. Preserve preferences fallback for tests/web/no support directory, also scoped.

An in-instance `_writes` queue does not coordinate distinct foreground/background objects. Use persisted revision/CAS or a validated cross-isolate lock+revision protocol, with crash-safe replacement. An auth write's generation is distinct from a data-scope generation. Implement a `writeIfCurrent(scope,revision,generation,...)` equivalent; compare after acquiring serialization control, not only before encoding.

### `syberia/lib/src/data/snapshot_cache.dart`

Anchors: `static String encode(AppSnapshot value)`, `static AppSnapshot? decode(String? raw)`, `_lesson`, `_grade`, `_event`, `_message`, `_attendance`.

Add top-level schema version, context identity and module revision/coverage metadata; continue accepting the original v1 shape. Keep per-provider DTO fixtures separate from cache JSON. Round-trip additive fields with optional defaults. For an unknown optional module version, retain raw quarantined data and load unaffected modules; do not discard the whole account. Unknown enum values need an explicit unknown/raw form rather than `Enum.values.byName` throwing and nulling the full snapshot. Never persist bearer tokens, QR credentials, signed attachment URLs or cookie headers in ordinary snapshot JSON.

### `syberia/lib/src/data/librus/librus_client.dart` and `reference_cache.dart`

Anchors: `enum LibrusPart`, `loginAndFetch`, `restoreAndFetch`, `selectSynergiaAccount`, `_sessionKey = 'syberia_portal_session_v1'`, `LibrusReferenceCache.fileName`.

Create `librus_provider.dart` to translate generic modules into `LibrusPart` and shared outcomes. Keep Portal/Synergia login, XML/web mailbox fallbacks and parsing in existing client. Migrate its session key/reference cache binding behind the adapter; do not reinterpret Librus session JSON for other providers. Keep existing `librus_client_test.dart` transport assertions unchanged during extraction. Numeric recipient conversion and Librus mark-read-on-fetch semantics are private adapter behaviors.

### `syberia/lib/src/state/app_controller.dart`

Anchors: `bool get isDemo`, `startAutoSync`, `configureBackground`, `_updateHomeWidget`, `requestNotificationPermissionIfEnabled`, `refreshSentMessages`, `fetchMessageContent`, `markMessageRead`, `markAllMessagesRead`, `fetchTimetableWeek`, `selectSynergiaAccount`, `sync`, `loginLibrus`, `logout`.

Expose `isSignedIn`, selected scope, current capabilities and typed module state. Replace provider display-string gates with those values; demo remains explicitly in-memory. Replace every capture/compare of `profile.id` in async actions with captured scope+generation. In particular, `fetchTimetableWeek` currently merges after await without a context guard: add one before touching state, cache or widgets.

Keep public compatibility facades while migrating screens. Add stable selected screen ID and typed provider/account/child/year selection. On selection, immediately invalidate page/module state and clear old widget/reminders; then load scoped cache and refresh. Existing `_syncing` prevents some races but not every message/download/child action. Do not solve this by globally freezing all screens during network requests.

`markMessageRead` must call the provider's operation: Librus fetch side effect, Fryderyk explicit POST, modern MobiReg read/detail GET, legacy local read plus deferred server acknowledgement. `SchoolMessage.unread=false` may be optimistic only with separate acknowledgement status. Partial mail send+upload returns a typed result, not a throw that makes the screen say nothing was sent.

### `syberia/lib/src/ui/app_shell.dart`

Anchors: `static const _pageCount = 10`, `_pages = <int, Widget>{}`, `Widget _page(int index)`, provider check in `build`, `_title`, `_SideNavigation`, literal numeric menu entries.

Define stable app `ScreenId` and a list of available screen descriptors derived from capabilities. Use numeric indices only as ephemeral render positions; map deep links/notification categories/Today cards by stable ID. Preserve the existing ten Librus destinations and order. Add exams/justifications as needed; polls live with announcements rather than being disguised as remarks. Settings/account is always accessible for signed-in/failed provider recovery.

Change `_pages` key to `(scope generation, ScreenId, relevant layout/capability revision)` or clear it on each such change. Keep `IndexedStack` lazy behavior, Glass wrapper and wide layout. Replace `_title`/icons/menu/actions together: changing `_page` alone leaves an incorrect selection/title or an out-of-range index. If the selected destination becomes unavailable, choose Today or first usable page. Unknown/denied capability status must be visible where a user needs recovery; do not render “no grades” for a failed grade fetch.

### `syberia/lib/src/ui/shell/account.dart`

Anchors: `_LoginRequired`, `_showAccount`, `_LinkedSynergiaAccounts`, `_LoginState.submit`, `controller.loginLibrus`.

Add provider picker and per-provider form/QR/manual fallback bound to a typed enrollment state machine. Preserve Librus email+password and VPN text only inside its flow. Fryderyk mobile username/password + bundled-guide explanation and `fryderyk://app/login?c=<Base64(username:password)>` decoding follow recovered grammar; its `/login` is not HTTP. Modern MobiReg page/school/login/password and QR-code exchange use their own forms; exact scanner payload grammar remains separately unresolved. Keep deep-link/parser input validation before credential submission.

Show saved accounts and selected child/year separately; retain Synergia account choices via Librus adapter. Local account removal and reconnect must explain the actual action. Preserve 5-second logo demo gesture and ensure it never persists auth or synthetic student data.

### `syberia/lib/src/ui/shell/{grades.dart,grade_calculator_sheet.dart,timetable.dart,timetable_views.dart,today.dart,attendance.dart,events_homework.dart,announcements_notices.dart}`

Use DTO-MAPPING.md and the 94-feature map as the concrete screen queue. Grades need server period hierarchy/proposed/final/text scale and averaged-versus-excluded state; disable numeric calculator for unsupported scales. Timetable needs actual durations, teacher collections, exam/accompaniment children, remote links and originals without double-counting nested sessions. Attendance needs provider totals and separate request workflow, not just normalized raw record counts. Homework needs source-qualified detail/solution/feedback/archive state, not a `SchoolEvent.description` string. Announcements need lazy detail and required polls with explicit answer/decline confirmation. New `shell/justifications.dart` and `shell/exams.dart` can be parts of app_shell initially to match project style.

### `syberia/lib/src/ui/shell/{messages.dart,message_compose.dart}`

Anchors: `_MessageFolder`, `_MessagesState._openFolder`, `_MessageDetailSheetState.openAttachment`, `_ComposeMessageSheetState.send`.

Replace the fixed inbox/Sent assumption with provider folder descriptors and independent paged/query state. Implement reply/action context, CC/BCC only when supported, opaque recipients, rich content and upload policy/error states. Fryderyk uploads before create; modern MobiReg sends body then uploads to the returned message ID. Represent `bodySentAttachmentFailures` explicitly and offer retry for failed files only when contract supports it. Do not repeat the send on an ambiguous exception.

Route attachment actions through an app download service: mailbox URL GET with cookie, homework short-lived URL GET without blindly adding auth, and provider-specific renewal. Validate redirect origin/auth policy and MIME handling. Use scoped temporary files cleaned on remove/logout; desktop open/share fallback and camera denial need visible recovery. Keep BCC private. Do not infer remote read receipts from the local read checkbox.

### `syberia/lib/src/homework_done.dart`

Anchor: `static const key = 'homework_done_v1'`.

Add DataScope to read/write and keep 60-day local retention. Import old marks only into migrated selected Librus scope. Keep local done independent from MobiReg solution/status and Fryderyk server submission status. Reminder filtering may use local done for local reminders but must not mutate official homework state.

### `syberia/lib/src/background_notifications.dart`

Anchors: `_taskId = 'siberiagb_librus_notification_check'`, `schoolNotificationCallbackDispatcher`, `final repository = AppRepository()`, `Set<LibrusPart> backgroundParts`.

Create repository from shared registry composition. `backgroundParts` returns generic requested modules, intersected with provider capability/permissions; let adapter coalesce dependencies rather than retaining Librus events/homework coupling globally. Keep 30-minute Android registration/network/battery constraints/manual-only semantics. Either keep legacy task ID for compatibility or explicitly cancel it when registering a new generic ID; do not leave both jobs active. iOS initialization is present but periodic registration is Android-only; do not claim iOS periodic sync parity from this refactor.

### `syberia/lib/src/school_notifications.dart` and `test_reminders.dart`

Anchors: `_seenPrefix`, `_updateReminders`, `processSnapshot`, `final seenKey = ...profile.id`, `_candidates`, `buildTestReminders`.

Use selected DataScope and module revision/coverage for seen-state/diff. Replace Librus gates with signed-in capabilities. First successful module fetch establishes its baseline without a history flood; an errored/unfetched module does not produce deletions or advance its baseline. Preserve muted-as-seen behavior. Normalize event/source IDs before notification/reminder identity. Clear/reschedule on account/child/year/logout; do not infer source FCM compatibility from local notifications. Vendor push registration needs an explicit verified deployment/session contract; initial polling is a distinct capability.

### `syberia/lib/src/home_widget.dart` plus native widget files

Anchor: `String buildHomeWidgetPayload(` and payload `'v': 1`.

If normalized Lesson data suffices, retain v1 wire shape and native code unchanged initially. Remove the controller Librus gate, ensure actual dates/durations/cancellations project correctly, and clear immediately on scope changes. A stale async update cannot repopulate old data. Keep 14-day/60-lesson bounds. If adding identity labels/staleness changes JSON, bump payload schema and update Kotlin/Swift readers together.

Native anchors to verify only if payload or channels change: `android/app/src/main/kotlin/app/syberia/client/{HomeWidgetChannel.kt,NextLessonWidgetProvider.kt}`, `ios/Runner/HomeWidgetPlugin.swift`, `ios/SiberiaWidget/{HomeWidgetStore.swift,SiberiaWidget.swift}`. Do not add network/token handling in native widget code.

### `syberia/lib/src/l10n/app_localizations.dart`, `data/demo_data.dart`, README variants

Anchors: existing `account`, `connect`, `loginHelp`, `notificationsDescription`, error translation switch, `class DemoData`.

Generalize common login/status words; retain provider-specific guidance inside per-provider flows. Add all new errors, periods, folders, requests, polls, solution and partial-send labels in PL/EN/RU/DE/UK. Demo fixtures include individual+ensemble lessons, text grade, pending justification, required poll and partially uploaded sent message, all fictional and local. Update README provider/tested-role/version support matrix only after actual integration; a static scaffold is not an enabled provider.

## Migration transaction recipe

1. Read existing `active_profile_v1`, secure session key `syberia_portal_session_v1`, legacy snapshot preference/file and legacy local homework/notification history. Do not remove anything yet. If no valid selected Librus profile exists, preserve/quarantine unbound material rather than attaching it to a new provider.
2. Derive a Librus `AuthOwner` from authenticated portal identity and its legitimate provider origin/session metadata. Derive `DataScope` from chosen Synergia/student/school/year when known. Unknown legacy period is explicit; do not fabricate year. Do not use profile display text as canonical identity.
3. Encode v2 owner, selected scope, module snapshot and local marks to new namespaced keys/files. Auth owner and selected data scope are separate: a rotating parent token pair is not duplicated per child/year. Preserve old Librus client restoration until the adapter can read the migrated session.
4. Atomically write/read back each new record and compare identity/counts; write migration checkpoint only after durable verification. Mark pending migration restartable; if interrupted, reuse validated records and retry missing ones.
5. Switch selected-context pointer last. Establish notification baseline from legacy IDs only for that known Librus scope; no synthetic all-new alerts. Clear native widget while rebinding then publish migrated lessons.
6. Delete legacy personal-state keys only after a successful complete migration checkpoint and successful new read. Retain a bounded rollback copy until policy permits cleanup. Never move tokens into ordinary preferences/cache. Unknown provider/schema material is not silently deleted.
7. Reauthenticate only if legacy credentials cannot be bound/restored; keep offline snapshot available and communicate that state. A network failure during migration must not convert stored data into empty lists.

Test crash points after every durable step, repeated startup, mismatched snapshot/profile IDs, corrupt optional module, same source IDs across two providers/schools/children, and concurrent foreground/background writes. Applying only a new provider allowlist without this migration/scoping work is not acceptable support.
