# Acceptance scenarios for the future integration

Every case below is a test specification. Nothing here asserts the provider integration is implemented or a real account was tested. Use deterministic synthetic fixtures with injected clock/transport/stores for most cases; label fixtures synthetic. Runtime cases require a consenting account and explicit authorization for mutations. A source package feature, recovered request, implemented behavior and runtime-confirmed behavior are four distinct claims.

## Migration and owner/data isolation

| ID | Setup/action | Required observable result |
|---|---|---|
| MIG-01 | Seed old `active_profile_v1`, `syberia_portal_session_v1`, legacy snapshot preference, local done and notification history. Start offline. | Existing Librus child loads immediately; v2 owner/data scope bound; original module counts/IDs retained; no auth network needed to read offline data; no history notification flood. |
| MIG-02 | Repeat the same startup/migration, including both old preference snapshot and new file. | One chosen authoritative v2 state, no duplicated items, migration idempotent. Verified new pointer/read wins only after durable checkpoint. |
| MIG-03 | Interrupt after owner write, after module file, before selected pointer, and after pointer before legacy cleanup. Restart each. | Completes or rolls back safely; no orphan context becomes selected; old data not removed before new verification; tokens never in ordinary JSON. |
| MIG-04 | Old profile ID differs from snapshot profile; old snapshot corrupt; one optional new module has future enum/schema. | Do not attach unrelated child data. Retain/quarantine material and report recoverable module state; healthy account/modules still load. |
| MIG-05 | Unknown provider/schema in persisted selected record. | No destructive removal. Offline data retained with unsupported/update-required recovery; account settings accessible. |
| SCOPE-01 | Create Librus, Fryderyk and MobiReg records all remoteID1; two schools and two pupils also ID1. | Canonical AuthOwner/DataScope keys differ appropriately; no data/history/local done/file/session leaks. Display label translation does not alter identity. |
| SCOPE-02 | Parent token serves two children and two years; concurrent reads require refresh. | One owner refresh, consistent rotated pair shared by dependent scopes; child/year caches remain isolated. No duplicated independently refreshed token records. |
| SCOPE-03 | Same login at two MobiReg page/school origins. | Separate owner credentials/module cookies. Removing one preserves the other; selected child display correctly follows owner. |

## Async and module merge

| ID | Setup/action | Required observable result |
|---|---|---|
| RACE-01 | Suspend accountA read; select B; resolve A with valid data and identical profile.id. | A cannot update B UI/cache/widget/reminders or selected pointer. A may update only its own scope when policy explicitly permits and auth/data generations still valid. |
| RACE-02 | Suspend auth refresh; logout/reconnect same ownerID; resolve old refresh. | Old auth-generation write rejected; new session not overwritten or resurrected. |
| RACE-03 | Older background response races newer foreground commit. | Persisted revision protocol preserves newer data; atomic files never half-read; an in-memory queue alone is insufficient proof. |
| RACE-04 | Send/download/timetable week fetch resolves after child switch, logout, or switch back to same child. | Captured generation suppresses stale state and platform side effects; temporary downloads cleaned or retained only by documented owner policy. |
| MERGE-01 | Grades succeeds, messages fails, timetable unfetched, one module denied. | Existing messages/timetable retained with separate error/freshness; grades update. Denial doesn't sign out account. No global fake-success timestamp. |
| MERGE-02 | Successful complete timetable day/range is empty; another cached week exists. | Only confirmed fetched range replaced; other cached days survive. Failed/unsupported empty response removes nothing. |
| MERGE-03 | Sent loaded during normal sync; messages sent while sync awaits. | Same-scope Sent changes preserved; cross-scope Sent never merged. |
| MERGE-04 | Manual-only mode and offline startup, then user refresh. | Startup reads cache and performs no diary request; explicit refresh routes to selected provider; failures leave cached modules visible. |

## Authentication and transport contracts

| ID | Setup/action | Required observable result |
|---|---|---|
| AUTH-01 | Fry identify synthetic success with access_token/refresh_token/url; then data request. | Identify POST JSON username/password/device; academic resource sent to returned legitimate data origin+/api with bearer, not bootstrap host. Invalid discovered origin yields explicit error without token forwarding. |
| AUTH-02 | Fry reIdentify rotates pair; version check and logout. | Refresh JSONu/t; version POST/validate belongs to VersionService; logout performs scoped local deletion without invented revocation request. Unauthorized/update-required errors mapped distinctly. |
| AUTH-03 | Fry deep link good/malformed Base64, foreign host/path/scheme, decoded empty fields and multiple colons. | Only established grammar accepted; no accidental navigation/secret logging. `/login` never treated as HTTP endpoint. Password-with-colon handling not silently invented. |
| AUTH-04 | Modern MobiReg raw password has leading/trailing spaces; blank-edit saved password; QR session with/without refresh. | Emptiness check may trim, wire selected original password unchanged. Correct JSONauth/QR/refresh branches; no legacy hash. Missing refresh doesn't create fictitious successful session. |
| AUTH-05 | Legacy MobiReg raw Unicode password and already-stored digest. | Transform raw once to lowercase MD5 bytes per explicit compatibility encoding; digest reused unchanged; no trim/doublehash. Cursor grammar/credential form scoped to legacy profile only. |
| AUTH-06 | Mail SSO returns302 cookie; homework module uses other origin/cookie. | Capture legitimate Set-Cookie at302 without requiring200 first; API mail base removes exact trailing/sso; cookie scopes never merged; no main JWT indiscriminately sent to module/download URLs. |
| AUTH-07 | Partial auth expiry after one child/module fails. | Owner/main auth and module-session errors distinguished; force renew only appropriate session; no retry loop; saved unrelated module/account remains intact. |

Operation fixtures assert exact method/URI/header/body encoding rather than only returned data. Include wrong status, malformedJSON, HTML error, structured denial, timeout, rate limit and incompatible protocol. Keep auth-bearing query/QR/cookies redacted from test output.

## Data semantics

| ID | Setup/action | Required observable result |
|---|---|---|
| DATA-01 | Descriptive mark, percentage/points scale, missing weight, excluded grade, predicted+final record, server average. | Text preserved; unsupported calculator disabled; final/proposed not added to ordinary weighted average; provider average visibly distinct from local estimate. |
| DATA-02 | Semester/year hierarchy crosses New Year and child changes. | PeriodID/parent/isYear preserved; selecting year doesn't force semester1/2 or clear unrelated stored periods. |
| DATA-03 |30-minute individual lesson,60-minute ensemble, nested accompaniment/exam, overlapping session, weekend, cancelled substitution. | Exact intervals/teacher collections preserved; nested children don't duplicate calendar period count; unknown substitution code retained; cancelled omitted from next-lesson projection. |
| DATA-04 | School wall time near DST boundary, viewing in different device timezone, date-only deadline. | Date/range remains in declared school semantics; no accidental UTC date shift. Legacy responseT/cursor-space distinction maintained. |
| DATA-05 | Provider attendance summary disagrees with count of currently fetched records. | Server summary/denominator preserved with range; no claim all absent records loaded. Unknown/missing/unrecorded distinct from absent; explained vs excused not blindly summed. |
| DATA-06 | Same homeworkID exists in diary and module source with different pupil statuses. | Distinct source-qualified tasks; detail/feedback/status/archive for correct pupil; local done independent. |
| DATA-07 | Legacy delta with insert/update/delete, tombstones, unknown table, duplicate row, mismatched server settingsID, malformed import. | Transactional all-or-nothing cursor commit; server cursor used, not device now; valid old tables survive failed import; full-resync decision explicit. |

## Mutations and user-visible confirmation

| ID | Setup/action | Required observable result |
|---|---|---|
| WRITE-01 | Fry absence draft includes optional nullid and contiguous lesson range. | JSON id/student_id/start/end/absence_type3/reason matches builder. Tagged6 never sent. No direct AttendanceRecord edit. Server validation error leaves draft and current attendance. |
| WRITE-02 | MobiReg create/update/delete justification. | Create POSTpupil_id/message/event_ids; update PUTmessage/event_ids only; delete DELETE no body. Create consumes rawJSONid; read endpoints use envelope. Request/attendance/dashboard invalidation scoped correctly. |
| WRITE-03 | Poll answer and decline, open/closed/pending/answered states. | Gateway POSTform id+answer or id+decline1. Accepted only decoded data.successtrue; server fields reconcile pending count/answer/declined; no auto-answer/bypass. |
| WRITE-04 | MobiReg solutionfile failure, save failure, later teacher feedback. | File errors explicit; no claim task sent without confirmed save; selected pupil kept fixed; unknown filesJSONschema remains disabled until resolved. |
| WRITE-05 | Archive PATCH succeeds but response lost; user refresh. | Do not automatically retry toggle; fetch state and show actual archived flag before next action. |
| WRITE-06 | Request reaches server but times out, then reload finds created object. | Uncertain outcome shown, no blind duplicate; reconcile using confirmed ID/read where supported. Synthetic transport can model this without real school writes. |

Authorized runtime mutation tests must specify target child, exact operation and cleanup/reconciliation expectations before execution. This documentation does not send or authorize messages, votes, justifications or solutions by itself.

## Messaging and attachments

| ID | Setup/action | Required observable result |
|---|---|---|
| MAIL-01 | MobiReg folder request uses raw immediate0x28; pages with items/total and search query changes. | Wire limit20/skip/query, folder/query states isolated, termination obeys confirmed total/empty behavior. Don't interpret raw immediate as40. |
| MAIL-02 | Fry response recipient_v2 keys versus compose request keys; CC/BCC/reply context. | Decoder names/opaque keys preserved; send keys recipients/cc_recipients/bcc_recipients; BCC not exposed through forwarding; unresolved action mapping remains gated. |
| MAIL-03 | Modern MobiReg recipient digit-only42 and opaqueuser_42/group key. | Normalization produces expected user_ form only where source contract specifies; no int cast of opaque values; per-role directory choices preserved. |
| MAIL-04 | Fry countUnread/read/delete/remove attachment. | All use recovered POST, shared omitted body jsonEncode(null) semantics; empty/unread state doesn't trigger guessed GET. |
| MAIL-05 | MobiReg message body succeeds and one file upload fails. | SentID retained; report body sent and failed file; retry file only if supported, never resend body. |
| MAIL-06 | Legacy local read succeeds, server acknowledgement IOException; modern read detail GET401/403; Fry explicitreadPOST fails. | Separate local/pending/confirmed acknowledgement; source's permissive worker behavior not presented as guaranteed server read receipt. Appropriate scoped auth retry only. |
| MAIL-07 | Send/delete ambiguous response, duplicate tap, account switch. | Button/action deduplication, no blind transport replay, state/query refresh reconciliation, old owner result can't modify current mailbox. |
| DOWNLOAD-01 | Mail URL requiresCookie; redirects to other origin. | Only allowed auth scope getsCookie; redirect decision prevents credential forwarding; local file opened after confirmed download. |
| DOWNLOAD-02 | Homework URL GET without explicitauth returns401/403. | Detail renewed through recovered callback/state, user retry shown; don't append mailboxCookie/JWT. URL never logged as harmless filename. |
| DOWNLOAD-03 | File cancellation, camera permission denied, partial bytes, invalid filename/MIME, desktop no camera. | Recoverable draft/error, bounded safe temp path, cleanup on owner removal/logout; file picker/manual fallback usable on desktop. Server size/count/extension policy not guessed. |
| CONTENT-01 | HTML images/links/audio/video/YouTube + failed media or malicious script. | Safe readable content with explicit external/media action; no embedded script execution with app credentials; localized fallback doesn't lose original text/files. |

## Navigation, localization and platform state

| ID | Setup/action | Required observable result |
|---|---|---|
| UI-01 | Switch Librus→Fry→Mobi with unsupported selected page and identical profileID. | Stable ScreenId selection fallback, correct titles/actions, no old page state, usable account/settings. |
| UI-02 | Module empty vs unsupported vs denied vs stale-with-error. | Different honest states and recovery actions; capability display doesn't fabricate data. |
| UI-03 | Classic/Glass/wide layouts, long names/HTML, largest text scale and all five locales. | No clipped submit/status/recipient controls, accessible labels; translations added for every new key; brand-specific login instructions remain inside proper provider. |
| UI-04 | Enter/exit5-second demo, reset settings, logout/remove one owner. | Demo no networking/persistence; reset visual prefs doesn't remove accounts; logout scoped state cleared; other saved owners intact. |
| PLAT-01 | New account first module fetch, muted category later enabled. | Initial history not replayed; muted-as-seen preserved; only new relevant successful data produces alerts. |
| PLAT-02 | Background fresh isolate, manual-only, unsupported module,20minute pause. | Same registry/config, no UI dependency, no unsupported requests, no false alerts on network failure; selected/auth generation checked. |
| PLAT-03 | Background older response overlaps foreground; legacy taskID migration. | Revision protection; only one scheduled generic/legacy periodic task; no duplicate notifications. |
| PLAT-04 | Child/provider switch/logout while reminders/widget update pending. | Old reminders cancelled, widget cleared immediately, stale update discarded; new valid lessons republish. |
| PLAT-05 | Next lesson with arbitrary duration, weekend/DST, no lessonNumber, cancellations. | Shared widgetv1 supported shape maintained; correct actual interval/countdown; bounds14days/60lessons respected. |
| PLAT-06 | iOS periodic sync absent; Android polling active; source vendorFCM feature listed. | Support matrix explicitly distinguishes these; no false vendorpush claim and no original Firebaseproject/config reused. |

## Verification report template

For each implemented feature, record featureID → operationID(s) → client/decoder/repository/UI paths → synthetic test names/results → runtime result/scope or `not_performed` → unresolved permission/schema/policy. A runtime result records app version, school/server class, parent/student role, date and redaction method without credentials or child data. Keep blocked rows in the ledger.

Run task-specific tests once relevant code exists, then locked dependency resolution, format check, fatal-info analyze and full `flutter test` from `syberia/`. Use the existing workflow's native checks/builds for changed platform surfaces. A passing documentation/anchor review is not a passing application implementation test.
