# MobiReg Android 2.1.79: recovered legacy protocol

This document records static code behavior of the supplied music APK. It does not assert that the servers still accept the protocol. Evidence locators are defined in `README.md`.

## Request identity and authentication

The user enters a school diary URL, login and password. `SyncHelperEparent.buildSyncUrl` strips one trailing slash. Legacy `UserAccountForm` accepts HTTP(S) addresses with a host, optional port and one school path segment; do not copy its simplistic regex as Siberia's URL/security policy. School host/path and user identity must remain part of account identity. `SyncHelper.forceHttps` exists in the shared library, but its existence alone does not prove every user URL is upgraded before every call. Require an explicit HTTPS policy in the new adapter.

`SyncParameters.addCredentials` places the following in a UTF-8 URL-encoded POST body:

| Field | Source |
|---|---|
| `login`, `pass` | Application compatibility fields set in `SyncParameters` constructors. Values are available in local decompiler evidence; they are omitted from this public dossier. These fields are separate from the user's credentials. |
| `device_id` | `MobiregLibConfig.getDeviceId()` |
| `app_version` | Source Android `BuildConfig.VERSION_CODE`, 79 |
| `parent_login`, `parent_pass` | User's school diary credentials, included when both present |

Do not claim a compatibility device identity is a server-issued bearer token. Before deploying Siberia, verify whether the server requires enrollment/version constraints or provides an integration registration path. Store user credentials in Siberia's secure store and do not reproduce the legacy client's body logging.

`NetServicesFactory` sets a 120,000 ms connection/read timeout and constructs `User-Agent: Andreg <device_id>` (fallback `Andreg 0`). `BasicHttpAdapter` sends `Accept-Encoding: gzip,deflate`, wraps a gzip response when its header contains `gzip`, requires status 200 and decodes response text as UTF-8. A new client can use its own tested HTTP library rather than duplicating the old Apache client. Handle redirects/cookie scopes explicitly; static request code does not provide a complete redirect/session contract.

## Pupil discovery and server settings

Both requests POST to `{schoolBase}/modules/api/njson.php` with common fields above.

- `view=ParentStudents` expects an object containing `ParentStudents: [...]`.
- `StudentModel` maps server `id` to the diary pupil ID, `name` to first name, `surname` to last name, `sex` to gender and `phone` to mobile. Local `_id` and account references are separate cache identifiers. Never substitute a local row ID for `student_id`.
- `view=Settings` expects `Settings[0]` containing `id`, `protocol`, `time`, `version` and optional `permissions`.
- `protocol` must equal the literal `1.6.0` for this client.
- `id` identifies the database generation; `time` becomes the synchronization cursor. `permissions=1` enables permission-aware logic.

`CommunicationManager` recognizes an error object with `errno`, including a single-element array wrapper in its generic path. `getStudentList` itself expects an object and does not provide robust normalization for arbitrary envelopes. New decoders should test each real endpoint envelope and produce a typed protocol error rather than assume every array is success.

## Full and delta synchronization

`SyncHelperEparent.getSyncParameters` chooses now minus 100 days through now plus 100 days. `SyncParameters` formats dates as `YYYY-MM-DD`; it includes `get_all_mark_groups=1` and a diary `student_id` when supplied.

Full sync POST fields add `start_date`, `end_date`, `get_all_mark_groups` and optional `student_id`. Delta sync adds `last_end_date` (previous window end) and `lmt` (previous server timestamp, formatted by source date library as `YYYY-MM-DD hh:mm:ss`). Treat the source date-format token semantics carefully when porting; Dart's formatter must use an explicitly verified 24-hour or source-equivalent format rather than copying letters blindly.

`DataSyncImportTask.doWork` obtains server settings first. Delta is allowed only when the local cache is valid and its `lastSyncID` equals the server database ID; a changed ID requires a full refresh. It checks protocol compatibility before opening the data transaction. A full refresh clears cached synchronized data. The response contains table arrays; `MappingConfig` defines 34 imported tables, even though the progress denominator constant is 27. Do not use that progress constant as the table inventory.

For each object, JSON `action` defaults to `I`; server `id` maps to cache `_id`:

- `I`: remove an existing row with the same ID and insert the incoming row.
- `U`: update if the ID exists; otherwise insert.
- `D`: delete if the row exists; missing rows do not become a fatal error.

The source importer updates synchronization settings from `Settings.time` and `Settings.id` after the table loop, prunes old records before the requested start date, marks the transaction successful and closes it. For Siberia, commit a new cursor only after successful parsing/application of the entire supported response. Preserve a recoverable failure state if malformed records are tolerated; do not silently mark a partial import fully current merely because the old client did.

`RegApiReader.nextObject` consumes array records as JSON objects. The default decompiler failed to structure `nextTable`; a focused JADX `simple` pass recovers a token loop that finds named arrays, leaves their array token for `nextObject`, and reconstructs a terminal error object when no table was found. This supports the named table-array grammar, but unknown/nested-table handling and wrapper variants still need fixture tests against actual captures. **Do not treat a hand-authored sample response as a recorded server fixture.**

## Data mapping and display semantics

Use `android-field-mapping.json` for exact import aliases/types. Important differences from cache columns include `id -> _id`, attendance `types_id -> attendance_types_id`, and `new` supplied locally with default1 in the Attendances mapping. The source contains a duplicate `students_id` entry for Attendances; preserve the semantic single field and do not emit duplicate JSON keys. Null-valued and absent fields are distinct: `createContentValues` uses defaults when fields are absent, writes null for JSON null and otherwise converts primitive values by declared type. Most source mappings have no explicit default; absence can raise a per-record data-format error.

Imported tables cover teachers/students/rooms/terms/subjects/groups; event types and teacher/group/term links; lessons, events, topics/issues and substitutions; student groups and group educators; attendance types/records; grade kinds, scales, division/group hierarchies, grade records; reprimands; messages; entitlements. `android-cache-schema.json` additionally lists local settings/results/log tables; a local table is not automatically a synchronized table.

Grade `mark_type` mapping from `MarkType.forId` is 1=scale, 2=points, 3=percent, 4=descriptive. Unknown values stay unknown. Scales may be nonnumeric. Percent ranges are 0–100; point ranges/precision are supplied. Preserve `no_count_to_average`, classification and proposed/final distinctions rather than coercing every display string into a number. `MarkGroup.getWeight` prefers group weight and falls back to the category's misspelled wire/cache `default_weigth`; mark-level weights must also be preserved. `MarkGroup.visibility=0` is visible to pupils; parent display also permits2. Correction chains use parent/child mark-group relationships. Do not use parent-only data in a pupil account merely because the normalizer can represent it.

Attendance `count_as` determines P=present, A=absent and L=late. Only if absent does the source fall back to IDs1/5/2 respectively. Preserve school-defined name, abbreviation, style and type. Do not assume one universal numeric attendance taxonomy.

Timetable rows join student groups to event groups/types, teachers, subjects and rooms. `EventEvents` relates originals and substitutions; source student queries exclude replacement `Events.substitution=1` from ordinary rows and resolve their relationship separately. Preserve event-specific dates/times, teacher lists, room, type/status/attr and topic content. Several numeric enum meanings remain unverified; expose raw values until examples establish their semantics.

## Messages and notifications

`MessageProvider.markAsRead` marks the local message and schedules `MarkMessageAsReadWork`. The worker posts common credentials plus `action=read` and `message_id=<integer>` to `/modules/api/messages.php`. No pupil ID is sent by this declaration. The old worker treats IO failure as success, so local read status need not prove server acknowledgement. Siberia should track pending/failed acknowledgement independently.

`UploadFcmTokenService` declares POST `/modules/api/njson.php` with common fields plus `view` and `token`; the focused `UploadTokenWork.simple.java` call recovers the exact selector **`view=ParentStudents`**, with `token=<FCM token>`. It iterates the selected account(s) using their respective school bases and credentials. This means the pupil-discovery selector also carries token registration when a token is supplied. Push data fields are `title`, `body`, `kind`, `schoolCode`, `userId`, `accountName`, and `noSync` (string `true`). Kinds are messages, marks, absences, reprimands, timetables and other. Notification routing can request synchronization before opening the corresponding feature. Match account and pupil using scoped identities and suppress notifications for accounts absent from the device.

The vendor Firebase project is not automatically a usable push backend for Siberia. Native FCM project ownership/token acceptance must be verified. Polling with local notifications can provide an explicit interim capability, but must not be described as parity with vendor push registration.

## Subscription/limits, support and shared-library residue

`SyncException` maps errno101/102/105/106/107 to login failure,200 to license expired and201 to sync-limit encountered. The account-check path uses a narrower login-code set, so centralize Siberia error mapping with endpoint evidence. `MOBILE_SYNC` permission rows include grant/expiry and quantitative limits. Source UI enables timetable when cache valid and gates grades/attendance/reprimands/messages on cache validity plus available sync allowance. Do not reinterpret this client UI as permission to bypass server entitlements; preserve explicit entitlement errors and show cached content under Siberia's documented policy.

User-facing support includes account management, local database reset, orientation toggle, notification settings, Wi-Fi settings, help/onboarding, feedback email, app version/store update and banner/subscription explanation screens. Siberia should provide equivalent outcomes using its own app identity, support and update flows; do not install a vendor update APK.

The shared library defines 13 export mappings for teacher-like event/attendance/grade/reprimand/topic/log writes and subject-DB version requests through `schedules.php`. These are **not established parent-app features**. Keep them as a documented library-only boundary until a real UI, call chain and authorized role prove use. Do not implement grade editing from a shared serializer's presence.
