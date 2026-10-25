# MobiReg implementation specification

This folder is **documentation and synthetic examples only**. It adds no provider implementation to Siberia. Use it with the shared [operation catalog](../../contracts/operations.json), [transport cookbook](../../TRANSPORT-COOKBOOK.md), and the existing Siberia architecture handoff. Read the target repository's instructions before changing its source.

The target is the supplied music-school parent/student clients: legacy Android2.1.79 and modern Android3.1.7 build116. The modern Android source revision is `6f4e7b8`; iOS3.1.7 build116 uses `d20dd8d`. Shared feature strings do not prove identical transport implementations. Modern code evidence below is Android ARM64 `libapp.so` SHA256 `22dd67993cd25ccb0a56fca7eef87ffc1d40cc1bffd9057b671c7268afc4d97a`. Legacy evidence is the supplied APK SHA256 `6cf44e486c7d8d6560aa5e5b1e946c46c1b86cbe545c6882db9bc7b70d4476e8`.

Every observation here is static. No vendor backend was contacted and no original app was executed during this phase. A synthetic fixture is an independently authored illustration of recovered structure; it is never a server recording or proof of current permission/acceptance.

## Reading order and deliverables

1. Read this specification and [discovery-auth.json](discovery-auth.json) for onboarding/account ownership.
2. Implement the exact operation IDs from the central catalog through separate transport families. [recipes.json](recipes.json) describes operation ordering, response consumers and invalidation.
3. Use [decoder-shapes.json](decoder-shapes.json) and its readable [DECODERS.md](DECODERS.md) companion for actual constructor field evidence, aliases, types, missing/default behavior and explicit unknowns. These cover client-consumed fields, not an invented complete server schema.
4. Build tests from [41 synthetic cases](fixtures/synthetic-cases.json), then add redacted authorized runtime fixtures when available. Examples marked field subset are not complete valid model objects.
5. Complete each stable feature ID in [feature-traceability.json](feature-traceability.json) / [CSV](feature-traceability.csv). All61 source rows remain represented, including local/platform features and an explicitly excluded teacher-library residue row.
6. Use [runtime-gates.json](runtime-gates.json) as the exact remaining-work register. It includes per-field dimensions still unresolved rather than hiding them inside a global “supported” flag.

## Proposed Siberia structure and identities

Use two related identities. The **session owner** is provider `mobireg` + canonical legitimate diary authority + school code + account/login identity. Secure JWT/password/refresh/messagesToken storage and refresh deduplication belong to that owner. The **data context** adds selected pupil and selected academic period/year. Scope module snapshots, unread/new indicators, cache requests and async result guards to that context. Do not duplicate one rotating refresh token into independent child/year sessions.

The original source can use a mutable current account. Siberia should pass an immutable owner/context to every request and discard results whose generation no longer matches after switch/logout. Account switching must replace mailbox/homework configuration and cookies together. A school URL, pupil ID or message ID is never globally unique by itself.

Capability state should distinguish supported, denied, unavailable, unverified and error. Modules can fail independently. A mailbox session failure must not erase valid grades or sign out another account. Preserve last valid cache with stale/error metadata. Do not return empty lists to represent malformed JSON, an unsupported envelope version, a denied module or expired authentication.

These are integration design recommendations. They do not imply this repository already implements a generic provider registry or that the original vendor app uses the same abstractions.

## Modern password login, QR and refresh

### Password flow

Use `MA-PASSWORD`, JSON POST to `https://{cleanAddress}/{school}/modules/api/auth.php` with Content-Type `application/json; charset=UTF-8` and Accept `application/json`. Fields are exactly `login` and `password`.

The source trims login and school. It tests `password.trim().isNotEmpty` but sends the **selected original password text**, including its spaces. Otherwise it uses the stored account password. If neither is available it attempts the account's refresh token; no password/refresh returns false. The settings controller → `AppState.performLogin` → `AuthService.login` → JSON value chain has no MD5 transform. Applying legacy MD5 here is a concrete protocol bug.

Require HTTP200, exact `status == "OK"` and non-null String `token`. Store JWT/password per owner. The password-success path does not independently consume a refresh response field. Do not infer JWT claim validation, token expiry or backend rotation from the storage helper. The source `getToken` simply reads the explicit/current account JWT.

Evidence: `AuthService.login0x7953f8`, URI call `0x7958ec`, field map `0x795988..0x7959bc`, encode `0x7959c4`, POST `0x7959e0`; selected password provenance settings `0x794fc0`, `performLogin0x795274` call `0x795340`, secure write `0x4a4c9c`.

### QR scanner grammar

The recovered parser accepts the following URI family:

```text
mobireg://qrlogin?school=<URI-encoded-school>&code=<URI-encoded-one-time-code>[&addr=<URI-encoded-diary-address>]
```

It trims the whole scanned string before `Uri.tryParse`; compares the scheme with `mobireg` and host with `qrlogin`; reads URI query parameters `school`, `code`, `addr`; trims each; rejects missing/empty school or code; and defaults missing/blank addr to `mobireg.pl`. The parser returns `{addr, school, code}`. The settings caller passes those three values to `performQrLogin`; the exchange sends **only trimmed code** as JSON `{code: ...}` to the chosen diary's `qrlogin.php` endpoint (`MA-QR`). Do not send the whole QR URI as the code.

Getter attribution is a strong static inference from shared dispatch slots: `-0xf44` is also the http/https scheme guard in URL launcher, `-0xed6` supplies the host whitelist in YouTube URL handling, and `-0xec7` supplies route query maps. The exact dispatch table itself was not decoded into getter names. This distinction and malformed/duplicate-query cases remain in `G-QR`.

Evidence: `_QrScanScreenState._parse0x7864e0`, trim/tryParse `0x786500/0x786508`, expected values `0x78654c/0x786590`, query keys `0x7865f0/0x786654/0x7866dc`, default host `0x786718`; caller `0x7926b8`. Scanner iterates detected barcode raw values until one parser result is non-null, stops scanner, then returns that map. Invalid values stay in scanner and display an error.

QR response requires HTTP200/OK/token and reads `user.login`. If an existing school/login account has a password, QR login preserves it while updating JWT/current account/address. Otherwise it stores authType `qr`, JWT and optional refresh, clears password and selects account. `MA-REFRESH` POSTs JSON `{refresh: storedToken}` to `refresh.php`; success stores JWT and a replacement refresh only when supplied. A missing replacement does not establish server revocation. Code expiry/reuse, JWT expiry and refresh rotation remain runtime gates.

### Logout/recovery

Gateway401 raises an unauthorized signal guarded to fire once; `resetUnauthorized0x49ff70` resets the guard. `requestView` does not refresh or replay the request. A future owner-scoped recovery coordinator should perform one auth flow and retry verified safe reads after success. Mutations with an uncertain response must be reconciled rather than automatically resent. Removing a local account should delete its credentials/module cookies/context caches and child associations; remote revocation/logout semantics are not established, so do not claim logout revoked a server token.

## Account, child, module and academic-period discovery

`MA-USERS` is a real account-level request: gateway selector `users`, `requirePupil:false`, no fabricated pupil. `_ensureAccountContext0x49e380` uses cached fetch key users; its actual fetch closure `0x49ff14` calls `requestView` at `0x49ff58`. Strict envelope data must be a map, then `syncUserContext0x49e5dc` consumes:

| Wire field | Behavior/ownership |
|---|---|
| `id`, `role` | Parse `int.tryParse((value ?? 0).toString()) ?? 0` in remote user context |
| `firstname`, `lastname` | Stringify with empty fallback; persisted account uses separate `firstName`/`lastName` names |
| `pupils` | List mapped by callback `0x49fd3c`; child `id` must be int, child `firstname`/`lastname` stringify null to empty |
| `messagingUrl` | Configured mailbox SSO URL; preserve legitimate base path |
| `homeworksUrl` | Independent homework module base |
| `oldHomeworkModule` | Integer parsed from textual representation; source-selector value meanings still gated |
| `messagesToken` | Optional module token stored per owner, distinct from diary JWT |

The local persisted `Account.fromJson` differs from this remote decoder: `userId`, `role`, `oldHomeworkModule`, `contextVersion` are strict integer fields with null→0; strings are not globally interchangeable with integer IDs. Do not apply one universal coercion function to both data shapes.

`Account.pupilsOrSelf0x49fc38` uses the supplied pupil list. If empty, `role == 1` and `userId > 0`, it creates a self pupil with userId and account names. This is an observed self-role condition, not a complete numeric role taxonomy. Parent discovery `pupils` can be empty legitimately or through unavailable context; do not invent a child.

After a child is selected, `MRA-02` gateway `terms` consumes `Term` fields `id,parentId,label,isYear,dateFrom,dateTo`. Semester/year relationships are explicit. Use a year term's range when available; source has a valid-range fallback. Do not infer an academic year from current device month. Terms `isYear` recognizes numeric1/string1, while `AttendanceTerm` separately requires an integer isYear. Wire date-range helper `DateHelper.toIso0x49805c` outputs zero-padded `yyyy-MM-dd` wall dates, without converting to UTC. Inclusivity/timezone policies remain in `G-PERIOD`.

## Shared modern transports

| Family | Auth and encoding | Response |
|---|---|---|
| Password/QR/refresh PHP | JSON; Accept/Content-Type, no gateway JWT alias fields | HTTP200 + statusOK + token fields |
| Main gateway `app.php` | POST URL-encoded form `view,format=json,token,JWTToken`, optional nonzero string `pupilId`; extras merged last | HTTP200 nonblank strict envelopev1 |
| Justifications REST `/api` | Bearer JWT, JSON Content-Type, build User-Agent | GET200 envelope-or-raw fallback; mutations2xx raw JSON or null for empty body |
| Mail API | Separate mailbox Cookie, JSON or multipart | Ordinary JSON2xx;401/403 session challenge; upload exactly200 |
| Homework API | Separate homeworkCookie, JSON or multipart | Exactly200;401/419 challenge; source emptybody→{} |

All standard JSON helpers use the recovered15-second timeout. Do not assume multipart requests inherit that timeout without checking the upload path. User-Agent is `MobiReg/3.1.7 (6f4e7b8)` in this build; it is evidence of source behavior, not a mandate to pretend Siberia is a vendor build forever.

### Gateway merge order and envelope

Build form defaults in this order, then pupil field, then merge extras:

```text
view = operation
format = json
token = accountJWT
JWTToken = accountJWT
pupilId = nonzero pupil ID converted to String, if supplied
addAll(extraParams)   # duplicate extra keys replace defaults
```

This matters for `MA-FCM-REGISTER`/`MA-FCM-UNREGISTER`: extras deliberately provide `token=FCMtoken`, so the final form has FCM token under `token` and the account JWT under `JWTToken`. Register optionally sends comma-joined `keepLogins`. Both disable requirePupil. Do not rewrite both fields to JWT after extras are applied.

Strict envelope shape is `{v:1,data:<module payload>,ttlFresh?:number,ttlRetain?:number,serverTime?:string}`. Integer or textual version1 is accepted. The ARM64 comparison rawSmi2 means Dart1, not protocol2. Missing v/data, incompatible v, empty body or data-map `errno` must become typed failures. Numeric TTL seconds default60 and1209600 (14days), use toInt then seconds; textual TTL values are not established. `serverTime` is parsed, but the observed constructor does not retain it; do not assume it drives cache freshness. REST GET fallback alone wraps envelope-less JSON with protocol0/defaultTTL. Never globally relax gateway parsing because REST is permissive.

### Academic views and writes

The central MRA records carry exact parameters. Common pitfalls:

- `marks` sends string `termId`; marks cache abbreviation `t` is not a wire key.
- `timetable-events` and `justification-events` send `dateFrom/dateTo`; cache `from/to` is separate.
- `dashboard` sends string `weeks/attMode`; cache `w/a` is separate.
- `reprimands` sends string limit `100`.
- `announcements` accepts raw list or a data list in its module payload and optional pendingCount; detail is a separate `announcement` view with string id. Opening detail may acknowledge read state.
- `announcement-answer` merges string id with answer String or decline String`1`; payload `success` must be literal true before treating the choice as accepted. Optional userAnswer/declined/pendingCount update source state. Refresh announcement list/detail/dashboard.
- `justification-events` groups data by day then numeric event ID. `JustifyEvent` id comes from the enclosing key, not a fabricated id field inside the short-key map.
- Justification create POST JSON contains `pupil_id,message,event_ids`; update PUT contains only `message,event_ids`; DELETE carries no body. Create reads numeric id from raw JSON. Update/delete source wrappers return true when the HTTP helper completes, without an extra success field. Reconcile after writes. These submit requests; they do not directly edit official attendance.

Read decoders must preserve text/descriptive grades, count-to-average exclusions, grade categories/weights/comments/styles, term proposed/final assessments, corrections/hierarchies, substitutes/original lessons, multiple teachers/groups/rooms, exams embedded in timetable and custom attendance symbols. Unknown enums must remain visible raw values with an explicit unknown type rather than be dropped or relabeled.

## Mail SSO, folders, recipients and partial send

SSO uses **original** configured messagingUrl:

```text
GET {messagingUrl}/{schoolCode}/{Uri.encodeComponent(messagesToken)}
Accept: text/html
User-Agent: <build UA>
followRedirects: false
```

Cookies can arrive on302. Source collects case-insensitive Set-Cookie, takes the cookie pair before the first semicolon from each, then joins with `; `. Success needs a nonempty cookie. Keep owner-scoped mailbox cookie persistence independent from homework. The source mailbox **API** base removes exactly one trailing `/sso` from messagingUrl; otherwise it retains the value. Do not append `/api/messages` to raw `/sso`, hardcode a universal mailbox domain, or substitute diary address.

Folder operations POST JSON with numeric `limit:20`, numeric skip offset, optional nonempty query. Raw ARM64 immediate0x28 is tagged Dart20. Folder payload fields are `items` and `total`, independent of the main gateway envelope. `MM-UNREAD` is a separate JSON school/messagesToken request; HTTP200 body is integer text, source malformed text falls back0. Siberia should report malformed count separately rather than claim no unread mail.

`MM-READ` GET `/api/messages/read/{id}` returns detail and can mark it read. Response uses `subject`, while send uses `title`. Sending PUT includes title,content,`odbiorcy` as **String-ID list**, optional previousMessageId. Recipient decoder prefixes numeric textual IDs with `user_`; nonnumeric IDs remain opaque, and leading zeroes should survive. Do not force every recipient into Siberia's existing numeric-only model.

Send body first, require returned int message id, then upload attachments individually to `/api/messages/{id}/files` using multipart binary field `files` and caller filename. Body success followed by failed attachment is partial success. Show sent message and failed filenames; do not resend the whole message. The source JSON wrapper forces re-SSO and retries once for401/403; the new adapter must distinguish a confirmed auth rejection from a timeout after delivery.

Star toggle path spelling is `/stared`; trash DELETE and restore POST are separately recovered. A toggle is not idempotent. After an uncertain toggle, refresh state before another user operation. Preserve thread `previous`, author/recipients/read timestamps/files. Verify actual deletion policy/permissions with a test account before claiming universal reversibility.

Mail downloads GET dynamic attachmentURL **with mailbox Cookie**, accept200 bytes and write a temporary file. Keep host/redirect authorization explicit. Do not log a signed URL, cookie or messagesToken. File constraints and cleanup behavior are release gates.

## Homework source, cookie, solution and archive

Keep diary-source and module-source homework as distinct types. Diary list consumes teachers/items and `Homework.fromDiaryJson`; module datatable consumes data and `Homework.fromModuleJson`. Their field names/date parsing/status information differ. `oldHomeworkModule` exists, but exact selector value semantics and server rollout need validation; do not guess a fallback on any generic error.

Homework SSO is independently configured:

```text
GET {homeworksUrl}/{schoolCode}/account/ssov2/{Uri.encodeComponent(messagesToken)}
```

Session persistence key is `homeworkCookie` and source module name ZADANIA. Normal API sends include that Cookie plus JSON headers/UA. HTTP401/419 challenge only this session; exactly200 succeeds, empty body maps{}. Source malformed JSON returns null like a session challenge, but a robust adapter should expose malformed success separately. Source force-reauth/retry once does not justify blind replay of uncertain solution/archive writes.

`HW-DIARY`: main gateway view `homeworks`, selected pupilId, no extras; closure `0x494b64` calls requestView at `0x494bb0`. Envelope data uses teachers/items and diary decoder.

`HW-LIST`: POST `/api/homeworks/datatable`, JSON listFilter active/archive, sortInfo prop deadline_at/order ascending. `HW-SHOW`: GET `/api/homeworks/{id}?student={pupilId}`. `HW-SOLUTION`: PATCH `/api/homeworks/{id}`, JSON content/files/student. `HW-UPLOAD`: multipart POST `/api/homeworks/{id}/files`, binary **files** plus string **student**. `HW-ARCHIVE`: PATCH `/api/homeworks/{id}/archive` with `{}` toggles active/archive. No separate archived=true/false field was recovered.

Do not invent the solution `files` reference structure from an attachment name or upload success boolean. That exact structure/upload response is a write gate. Preserve teacher_comments, solution content/sent_at/files, statuses and per-student fields independently; source numeric status meanings remain unverified. Homework downloads use dynamicURL GET **without automatic Cookie headers**.401/403 invokes parent detail refresh to obtain a renewed URL, then asks retry. Do not forward mailbox credentials to that URL.

## Legacy compatibility and table import

Select legacy mode only through verified server capability/protocol information; client operating system is not the protocol selector. Legacy Android2.1.79 uses njson.php forms, whereas both supplied modern platforms are Flutter generations. Do not silently downgrade a failed modern credential attempt into legacy MD5 requests.

Common legacy form fields: app compatibility login/pass (embedded values intentionally excluded from this handoff), device_id, app_version79,parent_login,parent_pass. The legacy editor hashes entered password using MD5 and stores the lowercase zero-padded32hex digest; it is that digest passed unchanged as `parent_pass`. Android's intended default byte encoding is UTF8; use nonASCII compatibility vectors before release. Empty editor input preserves saved password in the source.

The omitted app compatibility fields are fully locatable. In a private local decompilation of the supplied APK, open class `pl.mobireg.mobireglib.sync.SyncParameters`: both its zero-argument and two-argument constructors assign fields `login` and `pass`; method `addCredentials(List<NameValuePair>)` emits them as form keys `login`/`pass`, and emits `parentLogin`/`parentPassword` separately. The current local JADX path is `analysis/mobireg/jadx/sources/pl/mobireg/mobireglib/sync/SyncParameters.java` (constructor assignments lines26–27/32–33; form emission59–60). Caller `pl.mobireg.eparent.sync.SyncHelperEparent.getSyncParameters` supplies user credentials; this prevents confusing app compatibility values with the password MD5. To reproduce privately: verify the supplied legacy APK SHA256 above; run the locally installed JADX1.5.6 against it into a private output folder; inspect that class's constructors and `addCredentials`, then the caller. REA's Android class/method inspection can inspect the same fully qualified symbols. Do not publish the extracted literals or body logs. These locally recoverable constants are separate from the still-open question of current backend permission/integration enrollment.

`MRL-DISCOVER`: POST njson.php view ParentStudents. `MRL-SETTINGS`: same view Settings. Settings[0] includes id,protocol,time,version and optional permissions; this client requires exact protocol`1.6.0`. ParentStudents with a token extra also registers FCM under legacy `MRL-FCM`. Each account uses its own school URL and credentials.

Full import adds start_date,end_date,get_all_mark_groups1 and optional student_id. Delta adds last_end_date and lmt. Delta is allowed only with valid local cache and matching server databaseID; ID change forces full. Source Settings.time is `yyyy-MM-dd'T'HH:mm:ss`; source delta cursor uses a space-separated local-wall timestamp `YYYY-MM-DD hh:mm:ss` in its date4j formatter. Do not transplant format letters blindly into Dart/intl.

Import response is named table arrays. The [34 imported table mappings](legacy-table-mappings.json) provide every wire key → local column/type/default and source line. Local SQLite has37 tables, so not every local table is synchronized; the old progress denominator27 is not a table inventory. The export map is shared teacher-library residue and must not enable parent-app teacher writes.

Rows have `_s` actions I/U/D with primary-key identity; I inserts/upserts as established, U updates known columns, D deletes/tombstones by ID. Missing and explicit null differ: importer defaults absent fields when configured; explicit null writes null. Many absent fields have no default and source may produce a per-record data-format error. Attendances has a duplicate students_id mapping; keep one semantic field and never emit duplicate JSON keys. Key aliases include id→_id and types_id→attendance_types_id; Attendances.new defaults locally1.

Begin one transaction only after settings/protocol checks. For a full reset, clear only that owner's selected synchronized scope. Parse/apply every supported table, prune rows before range start as applicable, then commit cursor using **server Settings.time and Settings.id** only after success. On malformed required rows, interrupted import or unknown incompatible wrapper, roll back and preserve prior cursor/data. Record partial issues instead of claiming fully current data. Unknown table/column tolerance must be explicitly tested against protocol fixtures.

Legacy read acknowledgement is a separate POST `/modules/api/messages.php` action=read,message_id with account credentials and no pupil field. Source marks local state first and its IO worker can still return success after failure; Siberia should track pending/read-ack failure explicitly. No compose/delete mailbox mutation is established by that legacy read path.

## UI and completeness acceptance

The61feature register is the UI checklist. Implement typed exams, term assessments, justifications, polls, source-aware rich homework, opaque recipient messages and attachment outcomes where existing Siberia models are insufficient. Local app parity includes account removal/cache cleanup, manual refresh, stale/error views, subscription/sync-limit explanations, help/version/update state, accessibility and appearance, dashboard settings, file pickers/media/open/share, notification routing/preferences and diagnostics. Prefer Siberia's own UI conventions and translated resources over cloning vendor assets.

No payments, repertoire, practice log or teacher write workflow was established; do not create unsupported feature scope. The teacher-library row remains documented as excluded. A feature is complete only with contract scope, implementation path, meaningful fixtures, supported role/server/version and runtime verification status recorded separately.

## Exact limits and next-agent workflow

The shape index intentionally contains unresolved values. `runtime-gates.json` enumerates their exact constructor/key/PC and unknown dimensions. Some strings, dates, enums, nested collections and defaults still require focused branch tracing or authorized fixtures; this kit is not claiming all244 wire-field dimensions are complete. A verified primary read flow can be implemented while preserving unresolved raw fields; do not enable a mutation dependent on an unknown upload/eligibility/status contract.

Start with owner/context separation, modern auth+users+terms and error-preserving cache. Add academic reads, mailbox/homework sessions and reads, then one explicit write capability at a time. Test branch/merge/type subtleties using the synthetic vectors, especially modern raw password vs legacyMD5, FCM token overwrite, envelopev1, POST form vsJSON, mail subject/title distinction, strict numeric IDs, account/child switch races and partial sends. Complete per-operation gates with authorized runtime fixtures before claiming production support. No credentials or student records need to enter Git.
