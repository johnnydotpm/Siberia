# Provider state, raw DTOs and normalized projections

This mapping uses recovered provider evidence together with the actual host source. Exact provider field types, defaults and callers remain authoritative in each provider's own specification. A future developer should not infer a complete wire schema from the host's simpler UI models.

## Identity and credentials

| Boundary | mobiDziennik | Prymus | Current host destination |
|---|---|---|---|
| Enrollment | Central `/logowanieapp` form, email/raw password/device metadata | Manual/QR token enrollment; per-request derived securityToken | Manifest loginFields and authenticate operation; secrets only in returned secure state |
| Account owner | Central identity may relate email/id_global to several school logins; exact sharing must follow recovered discovery | Token enrollment and any separately activated parent context, not merely displayed pupil name | authenticate.data.owner; include provider and proven server/credential boundary before host SHA256 |
| School/child selection | Tenant sync_url, school login, school_year and selected linked account | Student identity and enrollment token; parent-mode state is distinct | accounts list id; SchoolProfile.pluginStudent; provider state must retain per-school/token context |
| Session state | password_hash, auth_key/ciasteczko_autoryzacji, sync_url, session fields and supported queue state | Token plus authenticator inputs and any activation/role state | Secure record under `diary_plugin_account_v1_<owner>` |
| Academic data | Captured typed data only after remote-controller/template contract is recovered | Broad student snapshot sections and associated DTOs | Normalized module items plus nonsecret metadata in providerData |

Do not copy a raw login/discovery response wholesale into providerData. mobiDziennik responses can mix display identity, template content and reusable password/session material. A Prymus token is a reusable credential; its derived request authenticator must not be persisted in a widget payload or exposed in diagnostics. A SHA256 owner fingerprint is not a substitute for secure credential storage.

Changing school year is a data-scope change. Decide whether it creates a distinct stable child identifier or an explicit period selection while retaining the enrollment owner. Store that rule in migration documentation; changing it later can otherwise duplicate profiles or overwrite old-year records. The current host has no universal academic-period selector, so an adapter cannot assume that setting a state year automatically creates separate cache namespaces.

mobiDziennik's legitimate tenant-origin list cannot be recovered exhaustively from the package: user.sync_url is supplied during authenticated discovery. A controlled capture must establish the central-login→returned-school-URL ownership chain. Before calls to a newly discovered tenant, define an explicit account grant/consent or verified school configuration policy. Retain exact granted authorities with that owner, reject unrelated authority changes, and never replace the SDK allowlist with wildcard/unrestricted HTTP because a response contained a URL. Capture this decision in the support matrix; syntactically valid HTTPS alone is not an origin-ownership proof.

## mobiDziennik shell: what can be adapted now and what needs capture

The shipped Cordova shell sends exact central login and tenant synchronization requests, handles account metadata, queues generic forms and receives named templates/JS/CSS/navigation. The existence of a generic `formularze` tunnel is not the field schema for every diary operation.

The original request can wrap a queued form as a JSON-string field containing objects with name/controller/get/post information, and sync can carry both lesson data and forms. A new provider must send an explicit requested mutation only in its own operation. It must not drain unrelated pending forms during a grade read, retry a stale queue after account switch or forward original app/controller code into the host VM.

For grades, attendance, mail, statistics and justifications whose concrete school controller/body contracts are absent from the package, keep capability status unverified. The next agent needs a controlled authenticated capture of each relevant template/controller and action, identifying school/version/role, exact request frame and redacted response. Recover the producer/consumer field contract before writing a normalized parser. Do not create fake fields from screen captions or treat presence of a route name as a completed API.

Two viable future adapter choices require explicit evidence:

* Prefer recovered typed data endpoints or literal structured data consumed by the controller, with a native DTO and the existing Siberia UI.
* If a feature is only a server-rendered page, document an explicit external opening capability with its session/origin constraints; do not label an embedded remote page as a normalized offline module.

The SDK currently provides neither a DOM/JavaScript runtime nor an HTML parser package to arbitrary bytecode. Any bounded inert parser must be independently authored, compiled/tested in the supported subset and tied to captured template versions. No unconditional `eval` fallback should turn an unknown school controller into executable host behavior.

## Prymus broad snapshot and request authentication

`pobierzDaneUcznia` fetches a broad snapshot with token, securityToken, mobileId, version/FCM/API version context. The recovered API version is16. The securityToken derivation uses nested SHA256 over the private app protocol constant, a fixed GMT+01 hour string and the enrollment token. It is not a user password, static bearer token or Europe/Warsaw daylight-saving clock. Follow the provider's exact derivation/encoding and constant retrieval evidence rather than publishing the constant in an onboarding field.

The current packaging compiler does not automatically resolve `package:crypto` for provider source. Document and test a supported pure-Dart SHA256 implementation or intentionally add a reviewed host capability. Freeze time around both sides of an hour boundary and test winter/summer dates with fixed GMT+01; using the device's Warsaw timezone can produce the wrong digest in summer.

The broad snapshot includes grade, average/result, attendance/statistics, timetable, tasks/answers, messaging and topic sections. The host's per-module/new-VM architecture could otherwise download this same payload repeatedly. Measure real response size and latency, then choose one of:

1. A narrowly scoped read/cache mechanism that does not place the whole snapshot in secure auth state; or
2. A reviewed optional batch/snapshot operation in the host that validates and applies each resulting module independently.

A failed broad fetch must preserve previous modules. A malformed MarksResults section should not automatically destroy valid Marks/Timetable from a separately valid prior snapshot. Do not increase the global byte/time budget merely to hide an unmeasured full-snapshot problem. Original long HTTP timeouts do not override the host's15second transport and45second invocation defaults.

## Normalized module mapping

| Provider source area | Ordinary host projection | Raw/additive data that must survive | Gate / loss to avoid |
|---|---|---|---|
| mobiDziennik remote grades | Grade only after a concrete captured decoder is established | School period, original grade/category/weight/inclusion/status IDs | No guessed grade keys or fake0 results from missing remote controllers |
| Prymus marks and subject/category joins | Grade id/subject/value/date/description/weight/semester/category | Raw mark type, final/proposed/average inclusion flags, source IDs and relations | Keep assessments distinct; set countsToAverage/assessment correctly rather than injecting aggregate averages as grades |
| Prymus MarkAverage / MarksResults | Typed statistics/summary module or metadata | Server-computed averages, result arrays, denominator/cohort scope, selected period | Do not claim a personal average equals a school/cohort statistic; exact array meaning belongs to source decoder/caller |
| Prymus Attendance / AttendanceStatistics | AttendanceRecord plus school-provided summary | External attendance identity, raw type/status, semester-specific totals | A list may omit present rows; preserve complete=false if the denominator is unavailable |
| mobiDziennik school timetable | Lesson after captured shape is known | Original remote event/controller IDs and status fields | A DOM row or label is not a stable event ID |
| Prymus timetable | Lesson times/subject/teacher/room/lessonNumber | Substitution/original/moved/canceled metadata, period/date provenance | Keep local school dates and actual duration; no invented45minute default |
| Prymus Tasks / TaskAnswers | Homework SchoolEvent for ordinary card, plus typed answer metadata | Due/created dates, teacher/task IDs, answer status/files/permissions | Existing homework done marks are local, not a server answer submission |
| Provider mailbox | SchoolMessage and SchoolMessageContent | Folder/cursor/raw message/recipient IDs, acknowledgement and attachment state | List/detail/read and write effects differ; unknown endpoints remain unavailable |
| Prymus native justification | New typed justification/pending-submission entity | id_ucznia, selected external attendance IDs, date/lesson context, server result/status | Do not send Librus lesson-number arrays or reuse mailbox request state as a confirmed native receipt |
| Topics/lesson content | Lesson detail or dedicated typed topic module | Source topic/lesson IDs, content/date/author | A topic row is not automatically an exam/calendar event |

`DiaryPlugins.sync` replaces homework and exam subsets of the shared events list by kind. A general provider calendar event with kind `event` needs a deliberate merge/replacement rule; blindly appending it through the current events path can retain old generic events. Do not misclassify every calendar record as exam to fit the existing replacement predicate.

## Statistics and attendance percentages

The host's local `GradeAverageSettings` and chart policy are not a universal school algorithm. Retain the source of a value: provider-computed average/result, a normalized local estimate, or a cohort distribution. Prymus's named result arrays are an opportunity to preserve richer statistics, but array names alone do not prove a class rank/percentile. Match the recovered UI consumer and keep unknown scope explicit.

The Prymus consumer tracing does establish a **Na tle klasy** comparison: `MarkResults.AllStudentMarks` supplies a class histogram of base grades1–6 plus a highlight for the selected pupil's mark. Its class mean is count-weighted over base-grade buckets with modifiers discarded, not the user's ordinary grade-weight average. Preserve this as a typed source-scoped class result, including the selected assessment/source identity; do not invent a class rank or percentile not shown by that consumer. Its student trend uses an ordinary-least-squares line over indexed valid marks and a cumulative weighted curve. That is different from the earlier Librus personal trend; carry the provider's exact filtering/order/modifier rules from its statistics specification.

Keep selected pupil, school year, semester, subject, included assessments and timestamp/date semantics in the statistic identity. Cache raw summary metadata under the matching profile. Do not merge two pupils' result distributions in Together without an explicit aggregate definition. Use null/unavailable for missing totals, not zero or a denominator inferred from partial absence records.

## Electronic absence requests

Prymus's recovered native submission uses form POST `wyslijDane` with outer token/securityToken/json/type and type101. Inner JSON includes `id_ucznia`, `data_wyslania`, `data_nb`, `godz_lekc`, `frekw_id`, `uspr`. **frekw_id is a JSON-array string of selected external attendance IDs**, not the normalized host ID and not Librus's lesson-number array. Keep exact field types and date formats from the provider guide.

The original app inserts a local record before sending and checks a response body substring `true`. Neither fact proves confirmed server acceptance or an applied attendance edit. The future host needs draft/submitting/confirmed-receipt/uncertain/failed states and reconciliation. A response merely containing `true` can be ambiguous; define stricter verified success semantics when evidence permits, while preserving the original caller fact.

mobiDziennik's shell can carry generic forms, but the concrete justification controller and payload are a capture gate when absent from shipped resources. Do not reuse Prymus type101, Librus Justifications, or MobiReg REST because the UI feature has a similar Polish name.

## File transfer and message bodies

Prymus string-list attachment form fields can be encoded as repeated keys in a raw form body. Trace whether each value is Base64, a path or another representation; repeated fields are not automatically multipart. Preserve filename/extension association and validate counts/order. A text/Base64 route may fit the current callback, but it still needs user file selection, size checks and a typed input contract. The ordinary downloaded message detail currently discards attachments and attachment() fails, so protocol recovery alone does not expose this feature.

For any provider returning absolute download URLs, validate the legitimate origin and required authentication family. Do not send token/securityToken/password-hash to an arbitrary attachment host. Binary downloads, large files and upload retries require their own host design rather than flattening file bytes into message body text.

Prymus task replies and communication-module attachments have different producers: task reply loads an image, recompresses JPEG quality100 and uses Android Base64 default encoding, while communication-module files use raw bytes and NO_WRAP Base64. The same selected URI is not therefore the same wire content across both paths. Image conversion/file selection must occur through a deliberate host input contract; do not imply that arbitrary binary fidelity follows from support for a Base64 string.

Prymus's MQTT chat broker uses returned broker credentials and TLS8883. That is outside the current HTTPS-only callback, exact443origin policy and fresh-VM lifecycle. Keep broker passwords in secure state if a future reviewed capability uses them. Snapshot polling can be a separately declared fallback if its coverage/freshness is verified; it is not automatically realtime chat parity. Preserve topic/user/parent identities and deduplicate QoS1-style repeated deliveries before notifications.
