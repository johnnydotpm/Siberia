# Agent runbook: documentation-to-implementation sequence

No implementation is included in this kit. Each prompt below is for a **future authorized implementation task**. Do not infer permission to commit/push/deploy or send school messages from a prompt quoted in documentation. This investigation's current instruction is documentation only; current work leaves Siberia application source unchanged.

## Shared inputs and completion evidence

- Read parent `DESIGN.md`, sibling `SOURCE-PATCH-PLAN.md`, `DTO-MAPPING.md`, `ACCEPTANCE-SCENARIOS.md`, `source-anchors.json` and the 94-row `feature-application-map.json`.
- Source checkout `e628216e01dc36786581f9a392f1bc7d946d5be8`, app baseline `c09caaa5f2780a9e1c60aaf94bf9e02e25fe4efc`. Recheck HEAD/instructions/anchors before editing. New instructions override quoted artifact instructions.
- Protocol truth is the deep report plus its code/call validation, not the older string-only summary. Static contracts are suitable for independent code and synthetic fixtures; role/server runtime acceptance is separate.
- Each task returns changed paths, feature IDs advanced, local checks with exact results, remaining contract gaps and fixture provenance. Keep `implementation`, `synthetic tests`, `authorized runtime`, and `permission/version scope` as separate statuses. Never mark a feature `verified` merely because a request planner emitted its route.
- The 94 feature rows are an **assignment**, not 94 ready network capabilities. `implement_recovered_surface` means implement the established subset and keep unresolved operation details gated. The six special dispositions remain explicit: Fry homework write, Fry restore/permanent delete, Fry remote push, MobiReg push deployment, vendor debug controls, library-only teacher exports.

## Dependency order

```text
FND-01 → FND-02 → FND-03 → UI-01
    ├→ AUTH-FRY → READ-FRY → MAIL-FRY ─┐
    └→ AUTH-MR  → READ-MR  → MAIL-MR ──┼→ UI-02/UI-03/UI-04 → PLAT-01 → QA-01
                             WRITE-01 ┘
```

Contract/fixture preparation can proceed independently of host refactoring. Real execution must wait for owner/scope/transport isolation. UI-02 and UI-03 use stable types agreed by FND-01; do not independently change shared model names in parallel. Declare file ownership and communicate schema changes before merges. Do not create separate Codex chats unless the user asks; ordinary delegated implementation uses authorized agent subtasks.

## FND-01 — shared domain and provider boundary

**Inputs:** DESIGN, source anchors for models/errors/repository/Librus, existing `librus_client_test.dart`, DTO-MAPPING.

**Prompt:** Establish the proposed `ProviderId`, `AuthOwner`, `DataScope`, typed module outcome, contract catalog operation identity, transport boundary and registry in Siberia. Add a Librus adapter around the existing client. Keep generic model normalization outside protocol parsing; preserve old constructors/facades initially so tests don't require unrelated rewrites. Add opaque recipient identity, explicit period/grade scale and typed module metadata. Translate existing Librus errors without copying Portal cases into other provider auth. A registry entry with an unimplemented operation must return unsupported/unverified, never timestamp-only sync success.

**Outputs:** shared domain/binding interfaces; Librus adapter; constructor compatibility; independent decoder/planner test fixtures; mapping decision notes. Expected app paths are the new `lib/src/data/providers/` and `data/librus/librus_provider.dart`, plus domain and repository composition.

**Acceptance:** no provider-specific URL or auth token in the UI; fake provider with same remote IDs routes correctly; Librus transport fallbacks remain tested; unsupported operation preserves prior cache. Run `flutter test test/librus_client_test.dart test/app_controller_test.dart test/grade_average_test.dart test/grade_calculator_test.dart` and analyze/format checks below. Depends on no other implementation task.

## FND-02 — durable identity-scoped storage and migration

**Inputs:** FND-01 types; snapshot store/cache, old key manifest and SOURCE-PATCH-PLAN migration algorithm.

**Prompt:** Implement owner-scoped secure sessions, DataScope-scoped module/snapshot/local-mark/history storage, schema migration and revision-safe writes. Run legacy migration as a restartable transaction with selected-context pointer switched last. Preserve offline content when auth restoration/network fails. Serialize foreground/background commits by persisted revision/generation, including logout during encoding. Shared refresh tokens stay under one auth owner across child/year scopes.

**Outputs:** migration store/schema implementation; fixture-seeded migration/race tests; documented key format/rollback/retention. Keep Librus reference cache isolated. A new schema read failure quarantines affected module rather than signing out everything.

**Acceptance:** scenarios MIG-01–05 and RACE-01–04 below; old profile/session/snapshot round trip; repeated migration no duplicate notifications; remove one owner leaves another untouched. Add `test/provider_migration_test.dart`, `provider_scope_store_test.dart`, `provider_race_test.dart`; run those plus `startup_test.dart`, `auto_sync_test.dart`, `background_check_test.dart`, `homework_done_test.dart`.

## FND-03 — repository/controller dispatch and module merge

**Inputs:** FND-01/FND-02; repository/controller exact anchors.

**Prompt:** Replace all display-string sign-in gates with typed selected scope/capabilities. Keep compatibility methods while dispatching login/sync/timetable/mail through adapters. Define module coverage merge and partial failure behavior. Capture generation before every async request, verify it at state/persistence/widget boundary, and make range replacement adapter-owned. Remove fake non-Librus refresh branch. Mark-read and send results become typed provider behavior.

**Outputs:** usable local-first provider orchestration; fake scripted provider regression suite; no new diary real requests required.

**Acceptance:** tests demonstrate old inbox/Sent/later days survive appropriate partial refresh, empty successful range deletes only that range, old response after scope switch is ignored, manual-only startup never networks, module permissions don't invalidate other modules. Run `app_controller_test.dart`, `sent_messages_test.dart`, `timetable_sync_test.dart`, `auto_sync_test.dart`, `background_check_test.dart`, new module merge/race tests.

## AUTH-FRY — Fryderyk enrollment and token owner

**Inputs:** FND-01/02; `../evidence/FRYDERYK-RECOVERY.md`, contracts JSON and raw instruction validation; FRY-001/002/031/032.

**Prompt:** Implement POST identify JSON username/password/device against configured token origin; persist access/refresh/url/username under AuthOwner; implement reIdentify JSON u/t with atomic token rotation and serialized refresh. Data requests use identify-returned URL+/api, not bootstrap hostname. Implement manual mobile credentials and verified deep-link c Base64 UTF8 colon split grammar; treat `/login` as app path, `/validate` as version endpoint. Logout clears local keys/cache; no invented revocation endpoint. Validate discovered origin and keep enrollment tokens out of ordinary snapshot/logs.

**Outputs:** client auth lifecycle/decoder; redacted structural synthetic fixtures; typed account/linked child mapping using recursive User.fromJson student decoding, with unresolved field optionality represented explicitly; provider UI state transitions.

**Acceptance:** original-password preservation; expiry/rotation concurrency; malformed Base64/foreign scheme/host/path; decoded colon handling matches contract; discovered origin rejection doesn't leak token; offline reopen; version426 state; no hidden logout request. Synthetic transport tests first; runtime requires authorized enrollment response. Run new `fryderyk_auth_test.dart`, `fryderyk_deeplink_test.dart`, `provider_origin_test.dart` plus scope/race tests.

## AUTH-MR — modern and legacy MobiReg sessions

**Inputs:** FND-01/02; MODERN-AUTH-GATEWAY and LEGACY-CONTRACT-CORRECTIONS; MR-F001–009/F042; parent catalog operation IDs.

**Prompt:** Keep modern JSON password, QR code and refresh flows separate from legacy digest credentials and form sync. Modern password emptiness check trims but sends original selected string; do not MD5 it. Legacy raw-input boundary produces lowercase MD5 once, while saved digest stays unchanged. Persist account auth type/password/JWT/refresh owner scope. Normalize legitimate page+school/login; handle parent/student self and child selection. Implement gateway POST form and proven module origin discovery. Mail and homework module cookies are independently scoped; sharing one cookie jar with all origins is prohibited. Scanner grammar remains gated to traced exact scheme/host/query contract, not inferred endpoint arguments.

**Outputs:** two explicit protocol profiles; modern gateway/envelope decoder; account-owned session/module stores; school normalization and QR parser tests; profile discovery results.

**Acceptance:** AUTH-01–05; same login at different schools doesn't share credentials; blank password edit preserves prior credential; child switch shares refresh owner safely; QR/password matching follows selected profile; absent refresh doesn't trigger guessed endpoint. Tests `mobireg_auth_test.dart`, `mobireg_legacy_credentials_test.dart`, `mobireg_module_session_test.dart`, `provider_origin_test.dart`. Do not probe each found domain automatically.

## READ-FRY — common academics and typed detail mapping

**Inputs:** FND-03, AUTH-FRY; Fry deep decoder-owned model records; FRY-003–013/F016–018; DTO-MAPPING.

**Prompt:** Implement current user, grade overview/list, attendance overview/lesson absences/request reads, lessons by day, homework detail/files and status. Preserve decoder-owned nested periods/teachers/accompaniment/exams and raw provider codes. Fixed grade-list10 and optional-null limit0 are wire semantics; do not substitute UI page-size guesses. Current calendar/widget projection is loss-aware and typed detail holds missing fields.

**Outputs:** DTO decoders with optional/unknown handling, generic module outcomes/range coverage, synthetic mapping fixtures and state projection.

**Acceptance:** DATA-01–06; text grades, predicted/final distinction, exact custom substitution codes, provider aggregate counts, arbitrary lesson durations, child/range isolation. Fry homework write stays unavailable. Run `fryderyk_read_test.dart`, `provider_mapping_test.dart`, existing attendance/grade/homework/timetable/Today tests that changed.

## READ-MR — gateway academic reads and legacy transactional sync

**Inputs:** FND-03, AUTH-MR; academic-contracts18 operations; legacy protocol/mapping/schema corrections; MR academic/cache/sync rows.

**Prompt:** Implement gateway selectors marks/terms/tests/attendance-stats/reprimands/timetable-events/dashboard/announcements/announcement/pending/justification-events with exact wire extra keys. Cache abbreviations are not wire names. Add independent legacy importer with full/delta/tombstone transaction and server-settings cursor. Decode server date T grammar separately from lmt space grammar. Implement modern module source detail with exact source-specific envelopes, keeping unknown role/server limits explicit.

**Outputs:** typed read repositories and DTOs; synthetic fixtures for both profiles, cursor/range/import transaction tests; projection mappings.

**Acceptance:** legacy invalid/mismatched cache forces correct full import; server cursor advances only after committed transaction; unknown table doesn't delete other modules; modern call fixtures assert POSTform and selected pupil; literal string limit100 preserved; same taskID diary/module distinct. Run `mobireg_gateway_test.dart`, `mobireg_legacy_sync_test.dart`, `mobireg_mapping_test.dart` plus changed UI regressions.

## MAIL-FRY — newer Fryderyk mailbox

**Inputs:** FND-03, AUTH-FRY; iOS deep messaging contracts and corrected pool validation; FRY-020–029.

**Prompt:** Implement established folder listing/search/count/detail/mark read, recipients, compose with CC/BCC and context/action, upload/remove attachment and delete. countUnread and read/delete/remove are POST with shared jsonEncode(null), not inferred GET or absent body. Sending uses recipients keys while decoding reads corresponding v2 arrays. Upload occurs before create and returns attachment IDs. Folder/page/action UI arguments and file policy stay bounded contract gates where still unresolved. Do not invent restore/permanent delete.

**Outputs:** mailbox capability adapter, paged state, typed drafts/receipts/files and transport fixtures. No automatic real school message tests.

**Acceptance:** MAIL-01–07; BCC isolation, URL query encoding, no inferred read receipt, unknown folder/page constraints explicit, failed upload keeps draft recoverable, uncertain send doesn't replay. Run `fryderyk_mail_test.dart`, provider attachment tests, `sent_messages_test.dart`, `message_read_and_layout_test.dart`.

## MAIL-MR — modern mailbox with post-send file handling

**Inputs:** FND-03, AUTH-MR; MODERN-MODULE-CONTRACTS21 operations and decoder keys; MR-F037–045.

**Prompt:** Use normalized messaging URL removing exact trailing/sso only for API base, and proper SSO cookie setup. Implement POST folders limit20/skip/query, GETread detail, PUTsend title/content/odbiorcy/optional previousMessageId, recipient discovery, star spelled stared, DELETEtrash/POSTrestore, unread count and authenticated downloads. Body send precedes per-message multipartfiles uploads; retain messageID and partial success. 401/403 reauth wrapper in original source is not blanket authorization to replay uncertain writes in Siberia.

**Outputs:** mailbox and download adapter, independent folder/total decoder, post-send upload outcomes, cookie/origin tests.

**Acceptance:** raw Smi40 becomes JSON20; numeric recipient prefix user_ only when contract says; subject-response/title-send distinction; files failure never triggers repeat body; cookie-isolated dynamic downloads. Run `mobireg_mail_test.dart`, `provider_download_test.dart`, partial-send tests and current messaging regressions.

## WRITE-01 — justifications, polls and MobiReg solutions

**Inputs:** FND-03, corresponding auth+reads; Fry absence body; modern academic poll/justification and homework module contracts; FRY-014/015; MR-F023/031/032/034/035.

**Prompt:** Implement each established write as a typed capability with exact eligibility/validation and confirmation. Fry absence_type is integer3, not tagged6; serialize optionalid and formatted start/end per builder. Modern justifications JSONPOST/PUT/DELETE differ from gateway poll answers; poll extra id/answer or decline1 is POSTform. Modern solutionPATCH/ multipartfiles/student / archivePATCH{} use separate cookie module. Keep solutionfiles shape, approval code meanings and policy gates unresolved until evidence. Present affected child/record/action, then user submission; reconcile uncertain result by read, no blind replay.

**Outputs:** mutation capabilities and UI-facing draft/result states, synthetic success/denial/uncertainty fixtures, controlled runtime test protocol for later authorization.

**Acceptance:** WRITE-01–06; no direct official attendance edit, pending/approved preserved, pollsuccess exactlytrue, selected-child identity fixed across upload/submit, archive-toggle uncertain result doesn't auto-toggle again. Run `justification_test.dart`, `announcement_poll_test.dart`, `homework_solution_test.dart`, provider mutation policy tests.

## UI-01 — provider/account/settings/errors and navigation foundation

**Inputs:** FND-03, auth workflows, full feature map, exact shell/account/l10n anchors.

**Prompt:** Add provider picker, account owner/child/year selection, settings/help and localized error recovery. Introduce stable ScreenId and capability-driven destinations; preserve current Librus order/Glass/classic/wide behavior. Clear cached pages on scope+capability revision changes. Keep global visual preferences while binding account-owned preferences explicitly. Add only evidenced provider actions; vendor debug/library exports remain engineering records. Fictional demo covers new state types without networking/persistence.

**Outputs:** screens/sheets/menu mapping; PL/EN/RU/DE/UK labels; expanded demo; provider UI tests.

**Acceptance:** UI-01–04, unsupported/error/empty distinguishable, invalid selected index recovers, identical profileID never leaves old child page, login guidance brand-correct, 5-second demo preserved. Run `widget_test.dart`, `glass_shell_test.dart`, `demo_mode_test.dart`, `localizations_test.dart`, `settings_test.dart`, `screen_preferences_test.dart` and new provider navigation/account tests.

## UI-02 — academic detail and shared screens

**Inputs:** READ-FRY/READ-MR, DTO mapping, feature rows for Today/grades/attendance/timetable/exams/remarks.

**Prompt:** Extend existing screens for typed periods/assessments/server averages, actual lesson duration/teacher collections/accompaniment/exams/remote links, provider attendance totals and standalone exam detail. Add stable exams destination if needed. Reuse current Grade/SchoolEvent/Lesson projection only where semantics match. Gate local grade calculator to supported grading schemes and keep server averages visible separately.

**Outputs:** exact changed shell parts/new exams detail, selected scope filters, accessibility/localization fixtures.

**Acceptance:** DATA/UI scenarios; run `attendance_by_subject_test.dart`, `attendance_navigation_test.dart`, `grade_average_test.dart`, `grade_calculator_test.dart`, `details_test.dart`, `timetable_messages_test.dart`, `timetable_sync_test.dart`, `today_design_test.dart`, `today_grades_test.dart`, `free_days_test.dart` plus new provider screens.

## UI-03 — homework, polls and justification workflow

**Inputs:** READ/WRITE tasks, DTO mapping; events_homework/announcements/attendance anchors.

**Prompt:** Add rich task detail, source-qualified solution/teacher feedback/archive, justification record/candidate/draft flow and announcement lazy detail/poll gating. Local done remains an independent personal checkbox. Show stale/permission/partial states and don't fake an upload/submission with a local toggle. Wire only capabilities whose contracts are ready.

**Outputs:** new detail/justification/poll UI parts and actions; localized denial/pending/uncertain states.

**Acceptance:** task/poll/justification tests plus `homework_test.dart`, `homework_done_test.dart`, `details_test.dart`, `announcements` fixtures in widget tests. Fry write and unknown restore stay disabled. All five locales/classic/Glass/wide layouts reviewed.

## UI-04 — mail, rich content, downloads and file picker

**Inputs:** MAIL-FRY/MAIL-MR, relevant homework adapter; current messages/compose anchors.

**Prompt:** Extend folders/search/paging/receipts/compose context/CC/BCC, provider-specific draft/upload lifecycle and authenticated download/open/share. Rich content must preserve safe usable content and handle media failures; don't blindly execute embedded scripts or expose auth headers to remote resources. Add file/camera/gallery permission denial and desktop fallback; accepted limits come from confirmed policy, not invented constants.

**Outputs:** mailbox UI/service boundary, file lifecycle, partial-success and uncertain-send recovery; no actual school sends by default.

**Acceptance:** MAIL/DOWNLOAD scenarios; existing `sent_messages_test.dart`, `message_read_and_layout_test.dart`, `timetable_messages_test.dart`, new folder paging/content/upload/download tests; target plugin builds when adding native dependencies.

## PLAT-01 — notifications/background/widgets

**Inputs:** FND storage/repository+all read projections; platform source anchors; current tests.

**Prompt:** Construct the same provider registry in background isolate, intersect enabled parts/capabilities, keep polling policy and atomically merge freshness. Scope diff history/reminders to correct DataScope, baseline first fetch, preserve muted-as-seen. Route notification deep links to owner/child safely. Keep native widget v1 when fields suffice; immediately clear on selection/logout and reject stale updates. iOS periodic registration remains a separate OS limitation. Vendor push requires a separately configured legitimate backend/project; don't use original Firebase credentials.

**Outputs:** generic background/diff/widget integration, account-safe platform lifecycle tests, explicit push-versus-poll support matrix.

**Acceptance:** PLAT-01–06; run `background_check_test.dart`, `school_notifications_test.dart`, `notification_kinds_test.dart`, `test_reminders_test.dart`, `home_widget_test.dart`, `auto_sync_test.dart`; native Swift/Kotlin checks if payload/platform changes.

## QA-01 — parity ledger and release-readiness audit

**Inputs:** completed implementation tasks; original94feature register + new contract catalog; fixture provenance and authorized runtime evidence.

**Prompt:** Reconcile every original feature row with implementation paths, synthetic test IDs/results and runtime role/server/app version coverage. Preserve blocked/vendor-only/library-only rows with reason. Audit source display-string guards, credentials in logs/fixtures, scope identity, session origin/cookie separation and mutation uncertainty. Compare implemented behavior with original app only using authorized sessions. Publish no runtime claims from local fixture tests.

**Outputs:** updated acceptance register, precise residual gaps, tested support matrix, relevant documentation changes. Do not commit/push unless separately authorized at that time.

**Acceptance:** all requested verified features traced to tests; open gaps not mislabeled unsupported vendor behavior; existing Librus suite passes; no private data/tools/vendor code copied. Run full project checks below and requested target builds. App source changes are reviewable independently from evidence documents.

## Check commands and platform scope

Run from repository `syberia/`, using pinned project SDK/lockfile (baseline CI Flutter3.47.4 / Dart requirement^3.13.3; recheck current workflow):

```text
flutter pub get --enforce-lockfile
dart format --output=none --set-exit-if-changed lib test
flutter analyze --fatal-infos
flutter test <task-specific files>
```

After the integration is complete, run `flutter test` for the full suite. These are future task instructions; the documentation-only investigation did not run application implementation tests.

If native auth callbacks, file-picker/download/open/share, QR camera, notifications or widget schema changes, build affected targets with the repository's current `.github/workflows/build.yml` or local supported toolchain. Keep iOS widget type-check invocation from that workflow. Test Windows/Linux when adding platform-dependent plugins. Do not blindly upgrade dependencies or remove the existing `path_provider_foundation` override: its repository comment explains IPA signing compatibility.
