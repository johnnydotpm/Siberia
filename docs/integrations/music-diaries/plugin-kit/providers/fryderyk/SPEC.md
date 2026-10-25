# Fryderyk implementation specification for a future SiberiaGB provider

## Start here

This is standalone documentation for creating a provider later. It contains no plugin implementation, executable scaffold, production credentials or live API fixtures. Do not copy vendor source/binaries into Siberia. The protocol descriptions were independently written from shipped-client call sites.

Read in this order:

1. This specification: transport/auth and feature behavior.
2. [response-fields.json](response-fields.json) or [CSV view](response-fields.csv): every recovered decoder field, build, exact type/null/default confidence, transforms and source PCs.
3. [request-vectors.json](request-vectors.json): 26 synthetic examples, all network destinations `.invalid`.
4. [feature-traceability.json](feature-traceability.json): all 33 original feature rows and their documentation mapping.
5. [evidence/contracts.json](evidence/contracts.json), [deep analysis](evidence/deep-contracts.md) [additional static facts](evidence/additional-static-facts.json), [enum instances](evidence/enum-instance-values.json) and native validation files when checking a claim.

The implementation author can write all known request recipes and most core decoders from these materials. A user-authorized test enrollment is still needed to confirm the returned school origin and today's service acceptance. Individual unresolved fields are marked explicitly, so they need narrow probes instead of repeating reverse engineering.

## Builds, addresses and confidence rules

| Build | Technology | Primary evidence |
|---|---|---|
| Android Fryderyk1.0.12 | Flutter/Dart3.6.1, ARM64 AOT, compressed pointers | Blutter named ARM64 callers and constructors; librarySHA256 `8fdabb00afead92a3f36b71621ddf5976441191255b504c49de01c9681aeb738` |
| iOS Fryderyk1.1.7(build35) | Flutter/Dart3.8.1, ARM64 AOT, uncompressed pointers | Corrected snapshot/objectpool/native callsite recovery; AppSHA256 `2c11d5a1be3f1f21d85c2b9c4deb8c59d2c3c33dfd9eebf0235657bcc6f7cca1` |

Core diary features exist in both supplied releases. Messaging contracts below are recovered from the newer iOS release; do not describe them as verified in the older Android client. No original application was run, no backend contacted and no authenticated fixture captured in this research.

Confidence levels used here:

- **Static contract:** original caller constructs a method/path/header/body and a decoder reads its result. Good enough to author transport and synthetic tests.
- **Decoder type/default:** an explicit cast, null check or transform is linked to a field. This is what that build accepts, not a complete description of every server response.
- **Design choice:** recommended Siberia behavior, clearly separate from original behavior.
- **Probe required:** the exact missing decision is recorded. Do not guess it or block unrelated read capabilities.

Android addresses are ELF virtual addresses. iOS addresses are original Mach-O PCs, equal to original file offsets. Instruction-image-relative filename suffixes differ; use the explicit PC, not a suffix. The iOS parser originally produced pool indices two too high because it ignored the 16-byte ObjectPool header; uncorrected raw dumps are invalid for contract citation. Only corrected, payload-validated interpretations are summarized here. [iOS validation](evidence/ios-native-validation.json) checks 3,613 instruction bytes,408 direct calls,48 direct pool loads and134 literal-reference occurrences with zero mismatches. [Android validation](evidence/android-native-validation.json) independently checks service instruction references. There is no need to have raw assembly open merely to understand these instructions.

## Transport recipes

Use these symbolic bases:

| Name | Source / meaning |
|---|---|
| `tokenBase` | Packaged production TOKEN_API_URL = `https://swiadectwa.fryderyk.edu.pl/api/tokens` |
| `versionBase` | Packaged production VERSION_API_URL = `https://swiadectwa.fryderyk.edu.pl/api/version` |
| `schoolOrigin` | Exact `data.url` returned from successful identify and saved under secure-storage key `url` |
| `apiBase` | `schoolOrigin + "/api/"`; original code concatenates strings |
| `accessToken` | Secure storage `access-token`, after getAccessToken expiry handling |
| `appVersion` | Original AppHelper.getVersion returns PackageInfo.version, not build number; compatibility policy for Siberia must be explicit |

The current academic host is not established until enrollment returns its `url`. Do not replace it with tokenBase or derive it from an arbitrary identifier. Host validation and refusing token-bearing redirects to unrelated origins are Siberia design requirements. Keep exact school-origin path behavior in a fixture before normalizing trailing slashes; original code does no documented URI resolver magic.

### Headers and body modes

| Request family | Headers | Body |
|---|---|---|
| identify / reIdentify / version validate | Content-Type `application/json`; Accept `application/json`; App-Version `appVersion` | JSON object for identify/refresh; body argument omitted for version validate |
| Core GET and messaging GET | Same plus Authorization `Bearer ` + accessToken | Omitted |
| Absence POST and messaging JSON POST | Same plus Authorization Bearer | JSON-encoded supplied object, or JSON literal `null` if shared wrapper's optional body omitted |
| Attachment multipart POST | Accept `application/json`; Authorization Bearer; App-Version | HTTP library builds multipart boundary/content-type; one file field `file`; filename basename; per-part MIME application/octet-stream |

Do not send HTTP DELETE for messages/delete. Do not change messages/countUnread into GET. Do not treat omitted body, empty string, `{}` and JSON `null` as equivalent. JSON field-name spelling, case and underscores are part of the observed wire contract.

Original GET search concatenates `?query=` with user text directly before Uri.parse. A future provider should encode a query component using the HTTP URI builder; that is a deliberate improvement, not a claim about original escaping. Plain numeric path components are interpolated decimal integers. Date parameters are formatted as below. Recipient keys and text are JSON strings and should be JSON-encoded rather than string concatenated.

### Success and error envelope

The recovered handler reads `Response.body`, JSON-decodes to a map, and requires boolean `success`. If true it returns `data`. If false it reads `error.code` and `error.message`, logs the code and dispatches by HTTP status:

| Error-path status | Original exception | Message fallback |
|---|---|---|
|426|UnsupportedException|localized legacy-app-version-detected|
|401|UnauthorizedException|localized unauthorized|
|other|CustomException|localized unexpected-error-try-again|

If a server message exists it supersedes the localized fallback. JSON parsing happens before status dispatch in this handler: an HTML maintenance page is a protocol failure, not an empty record list. A successful `data:null` is not interchangeable with `{}` or `[]`; let the particular operation decoder decide its result shape. Success does not simply mean status200. Timeout objects are present; a numeric timeout value is not recovered here.

Siberia error categories should preserve: connectivity/timeout, invalid JSON/protocol, credential expiry/revocation, unsupported client/version, structured provider error and unknown enum/schema. Errors must retain old cached data with a stale/error indicator. Synthetic envelope cases are in request-vectors.json; none is an invented real response.

## Auth state machine

Use this state model as the implementation contract. State names are proposed Siberia names; transitions are based on observed code.

| State / event | Work | Next state |
|---|---|---|
|NoEnrollment → user enters mobile credentials|POST identify recipe below; preserve requested account until complete|EnrollmentInFlight|
|Enrollment succeeds|Read access_token,refresh_token,url; store secure username/access-token/refresh-token/url; fetch current profile|Ready|
|Enrollment fails|Show structured error; do not persist half of token pair|NoEnrollment or reconnect-needed|
|Ready → request starts|Read access-token; absent/empty throws UnauthorizedException|Ready or NeedsEnrollment|
|Token nonempty and not expired|Return token|Ready|
|Token expired and refresh future already exists|Await existing in-flight future|Refreshing|
|Token expired with no in-flight future|Set refresh future; POST reIdentify using stored username/refresh-token|Refreshing|
|Refresh succeeds|Rotate access-token and refresh-token; return new access; clear in-flight future|Ready|
|Refresh throws|Clear in-flight future on catch/finally path; surface UnauthorizedException in getAccessToken wrapper|NeedsReconnect|
|User logs out|Delete four secure keys and clear all provider cache|NoEnrollment|

There is **no early-expiry margin** in the recovered iOS code. JwtDecoder.isExpired is `DateTime.now().isAfter(expirationDate)`, where `exp` is interpreted in epoch seconds. Equality is not `isAfter`; it will be considered not expired at the exact equality boundary. Source: iOS JwtDecoder.isExpired0x2a1d9c/getExpirationDate0x2a1e24. If Siberia introduces a clock-skew safety margin, label it an implementation policy and test it independently. JWT parsing here checks expiry; it does not establish signature verification. Do not use unverified JWT role claims as authorization for school actions.

Single-flight refresh is present: TokenService.getAccessToken0x2a1794 stores/awaits a future at tagged field23 and clears it after success and catch. This is per TokenService instance. A future provider should also prevent stale refresh completion overwriting credentials after account switch/logout by using an account generation token (Siberia design choice).

### Identify

`POST tokenBase + "/identify"`

```
{
  "username": "<mobile username>",
  "password": "<mobile password>",
  "device": "<await Device.getName()>"
}
```

The original app's onboarding directs the user to sign into the Fryderyk website, open **Dostęp mobilny**, then **Wygeneruj dane logowania**. Manual identifier validation mentions the `m.` prefix. Do not substitute ordinary web credentials or silently trim/normalize a password. Response envelope.data must supply `access_token`, `refresh_token`, `url`; original login reads them as strings. Source Android _identify0x615ab4, HTTP post0x615c24, login0x6156b0. iOS confirms the same object keys at0x28e8c0/0x28e8d4/0x28e8e4 and post0x28e91c.

### Refresh

`POST tokenBase + "/reIdentify"`

```
{"u":"<stored username>","t":"<stored refresh-token>"}
```

Source Android _reIdentify0x619b34 and HTTP post0x619c84. Return token pair replaces the previous pair. Do not send a password or rename u/t to descriptive keys. Do not replay a failed uncertain identity mutation endlessly; bound retries and return a reconnect state.

### Deep link and QR

The supplied iOS plist registers scheme `fryderyk`. TokenService.loginByDeepLink checks host `app`, path `/login` and nonnull query `c`, then performs:

```
c -> Base64 decode -> UTF-8 decode -> split(":")
username = split[0]
password = split[1]
login(username,password)
```

`/login` is **not** an HTTP endpoint. There is no JSON decoding in this path. Additional colon-separated segments are ignored by these two element reads; malformed input can hit decode/range failures in the original. A future parser should reject missing fields and unsupported schemes before calling the network, with no tokens in logs. Exact QR scanner outer URI-validation behavior is separate from TokenService; use the same strict parser as a design choice and verify against a generated mobile-access QR. The synthetic link in vectors contains only dummy credentials.

### Logout and profile/children

Logout0x6142f4 removes local username/access-token/refresh-token/url and CacheManager.clearAll. No network revoke endpoint is recovered. The packaged confirmation warns that fresh mobile login data must be generated to re-enter; preserve this warning without asserting server revocation.

GET users/getCurrent → User.fromJson: id integer,role string,first_name string,last_name string,students optional collection. **students recursively decodes User.fromJson**, demonstrated by Android closure0x6183b4→0x6183ec. It is not a separate guessed Student schema. Role string is resolved with EnumByName.byName; observed names student and guardian. Teacher/admin writes are not supported by the recovered mobile workflow. Child selection is represented by active child in local app context; whether the server separately persists selection is not established. Every child-specific API takes studentId explicitly, so pass the selected child's ID rather than account ID.

## Academic data and absence requests

All resource paths below are relative to `apiBase`; all send the authenticated JSON headers.

|Operation|Method and resource|Input rules|Envelope.data decoder|Caller|
|---|---|---|---|---|
|Current profile|GET users/getCurrent|No ID path arg|User|0x618f1c/0x618f94|
|Grade overview|GET grades/getOverview/{studentId}|Decimal selected-child ID|GradesOverview|0x6223dc|
|Recent grades|GET grades/list/{studentId}/10|Fixed literal10 in this caller|List<Grade>|0x628278|
|Attendance overview|GET attendances/getOverview/{studentId}|Decimal child ID|AttendancesOverview|0x62169c|
|Absence requests|GET attendances/listAbsenceTypeChangeRequests/{studentId}|Decimal child ID|List<AbsenceTypeChangeRequest>|0x61d878|
|Day timetable|GET lessons/listAtDay/{studentId}/{date}|DateFormat y-MM-dd; no time|List<Lesson>|0x625b58|
|Lessons with absence|GET lessons/listWithAbsence/{studentId}/{limit}|Null limit serializes0|List<LessonWithAbsence>|0x620408|
|Homework|GET homeworks/list/{studentId}/{limit}|Null limit serializes0|List<Homework>|0x62422c|
|Request attendance-type change|POST attendances/requestAbsenceTypeChange|Body below|AbsenceTypeChangeRequest|0x65aaa8, HTTPpost0x65aeb8|

Path limit0 is the original client's representation of an omitted limit; its server meaning is not independently observed. Preserve0 for the same recipe and do not call it “all records forever.” The fixed recent-grade limit10 is decoded from a stored Dart Smi0x14. All integers in JSON/vectors are untagged wire integers.

Absence request body:

```
{
  "id": null,
  "student_id": 123,
  "start": "2026-10-25 10:00:00",
  "end": "2026-10-25 10:45:00",
  "absence_type": 3,
  "absence_reason": "Synthetic example"
}
```

id is an optional caller-supplied existing request ID, including null; do not infer an update/delete route. start/end use DateFormat yyyy-MM-dd HH:mm:ss, without an offset suffix in this body. absence_type is integer3 explainedAbsence, not raw tagged6. The original UI disallows gaps between selected lessons and says approval by supervising teacher/class guardian is needed. Keep the full selected lesson range, preview it before a user-triggered submission, and surface the returned request rather than modifying attendance locally. Eligibility rules, interval inclusivity, request status/rejection fields and server-side duplicate semantics need controlled fixtures. Do not invent approval-state keys not read by AbsenceTypeChangeRequest.fromJson.

### Model transforms and music-specific fidelity

Field-level source/type/default entries are in response-fields.json. Implement ordinary scalars with checked casts and preserve unknown raw fields. Important nonobvious cases:

- Android Grade.numeric_value is a **required string**, alongside required text_value string. The word “numeric” does not justify expecting a JSON number. Grade.weight is nullable string in Android; iOS adds value/factor branches. Preserve both builds' raw weight input until the newer branch is fully translated. Grade name/comment/subject_name/subject_short_name are nullable strings.
- created/start/end/publish_date/finish_date and attendance-period boundary strings go through DateTime.parse. Strings with offsets preserve their instant; strings without offsets use the Dart parser's local interpretation. The school's timezone is not encoded by these constructor names; keep the original string and an explicit school-zone assumption until fixtures resolve it. Do not convert unsuffixed school times to UTC blindly.
- Color strings go to int.parse(radix:16), then Flutter Color. This is full ARGB integer parsing, not a verified CSS `#rrggbb` parser. Preserve alpha. Grade.subject_color allows null and falls back to a constant color object whose numeric value is not recovered here; record “provider default color unknown” instead of inventing black/white.
- GradesOverview owns semesters; each semester has name/start/end/subjects; subjects have name/short_name/color/predicted_grade/final_grade/grades. Predicted/final grade objects are separate from normal grades. Do not assume predicted/final are numeric averages.
- Lesson fields include original_name/original_short_name, primary/secondary descriptions, room/color, attendance, substitution state, remote link, teacher list, **exams and accompaniments**, request object and precise start/end. Preserve hierarchy/overlaps; individual lessons and accompaniment must not be collapsed into one generic 45-minute timetable period.
- LessonAccompaniment has subject/accompanist/start/end. LessonExam has description/start/end. Teacher has id/full_name. Do not infer a separate practice-log/repertoire/lesson-edit API.
- AttendancesOverview owns year/months; period includes firstDayOfPeriod,lastDayOfPeriod,attendancePercentage and explained/excused/late counts. Percentage accepts num; exact denominator and whether count categories overlap are not proven. Use provider totals.
- Homework owns id,subject,publish_date,finish_date,teacher,content,attachments; content is parsed as HTML for rendering. HomeworkAttachment has name/url. Submission status display exists; a task-submission network API is not recovered. Do not repurpose the message attachment route for homework submission.

### Enum mappings

The snapshot object's custom code is distinct from Dart ordinal. Map provider codes to semantic labels, retaining unknown code/label pairs:

|AbsenceType provider code|Label|
|---|---|
|0|unknown|
|1|present|
|2|absence|
|3|explainedAbsence|
|4|notExcused|
|5|late|
|6|outEarlier|
|7|otherPresent|
|8|otherAbsence|

|SubstitutionType provider code|Dart ordinal|Label|
|---|---|---|
|1|0|canceled|
|2|1|replaced|
|3|2|ignored|
|4|3|inCommonRoom|
|5|4|lookAfter|

HomeworkSubmissionStatus objects have ordinal0 uncompleted,1 sent,2 accepted; no separate custom provider-code field was recovered. Their display strings correspond to awaiting/sent-to-teacher/accepted-by-teacher. Do not assert that the server wire values are these ordinals without following the actual caller/constructor branch. UserType observed names are student/guardian; role strings use names rather than ordinal integers. Snapshot object addresses and values are preserved in evidence/contracts.json.

## Messaging

These contracts come from iOS1.1.7. They use `apiBase` and authenticated headers.

|Operation|Method and path|Body/return|
|---|---|---|
|Folder page|GET messages/list/{folder}/{page}/8|No body; List<Message>|
|Search page|GET messages/list/search/{page}/8?query={phrase}|No body; List<Message>|
|Recipient directory|GET messages/getRecipients|No body; List<MessageRecipient>|
|Unread count|POST messages/countUnread|JSON null; integer result|
|Mark read|POST messages/markAsRead/{id}|JSON null; result ignored|
|Delete|POST messages/delete/{id}|JSON null; result ignored|
|Remove uploaded file|POST messages/removeAttachment/{id}|JSON null; result ignored|
|Send / contextual send|POST messages/create or messages/create/{originalMessageId}/{action.name}|JSON object below; Message result|
|Upload file|Multipart POST messages/uploadAttachment|One part file; integer upload-ID result|

The list/getRecipients GET chain is proven through sharedget0x302248→HTTPclosure0x3024a4→BaseClient0x3024e4, loading GET0x302504. POST chain is sharedpost0x2a1020→jsonEncode0x2a1204→HTTPpost0x2a121c. No detail endpoint is recovered; the list/created Message owns the content required by detail UI.

### Folders, pagination and search

Folder names are now caller-proven: inbox at0x301d50, sent0x303d4c, search0x304368, trash0x304980. Every list recipe carries a numeric page and fixed limit8, corroborated by MessageRepository.list's cache key fields type/page/limit/searchPhrase. The search UI enforces at least3characters (0x3ee5bc) before refreshing its paging controller.

The first-page origin and next-page/termination callback are still not fully bound to recovered UI code. Do not silently hardcode page0 or page1 as a fact. Vectors show page1 as an explicitly illustrative input. Implement a configurable paging strategy behind a small seam, and resolve one narrow fixture: observe the first request and an empty/end request in the original app. Page size8 and literal folder strings need no new reverse engineering. Cache per folder/page/query; refresh on folder/query change. Do not stop after a short page unless the server behavior is confirmed, and never retry an unchanging last page indefinitely.

### Sending, recipients and contextual action suffix

JSON keys are exactly:

```
{
  "recipients": ["recipient-key"],
  "cc_recipients": [],
  "bcc_recipients": [],
  "subject": "Synthetic subject",
  "content": "<p>Synthetic body</p>",
  "attachment_ids": [701]
}
```

The response decoders use recipients_v2,cc_recipients_v2,bcc_recipients_v2. They are not the outbound key spellings. MessageRecipient decodes key/name/role; MessageSender key/name. Preserve the string key; it is not established as an email address or student ID. The compose form maps selected recipient items into the supplied list; verify the key-to-list mapping in a controlled send before treating role values as recipient identifiers. At least one recipient, subject/body validations and waiting for uploads are separate UI requirements.

The send pipeline now links original context explicitly: MessageFormScreen callback0x290ad4 reads context.message.id from the Message object and context.action from the same context, passes both through MessageRepository.create0x290c40 to MessageService.create0x290cf4. Service appends `/{id}/{action.name}` only when both are nonnull, using the uncompressed enum name at tagged field15. Thus originalMessageId is no longer an anonymous context placeholder. MessageAction is enum class5730. Independently decoded canonical instance bytes establish ordinal0/name `reply`, ordinal1/name `replyAll`, ordinal2/name `forward`. The service reads the enum name, so the exact suffixes are `/messages/create/901/reply`, `/messages/create/901/replyAll` and `/messages/create/901/forward` for synthetic original ID901. Use these case-sensitive names, not translated UI labels or separate guessed endpoints. [Enum-instance evidence](evidence/enum-instance-values.json) gives original bytes, offsets, string references and exact range-consumption checks. Controlled-send fixtures are still needed for server acceptance and recipient/quotation semantics, not for the suffix spellings.

The original compose initialization distinguishes action ordinals and prefills Re:/Fwd:-style subject and quoted content, adding sender/recipients as appropriate. Sender/name/date/subject quote text is localized. The future provider should offer reply/reply-all/forward with distinct recipient sets, ensure BCC privacy and avoid copying raw quoted HTML into unsanitized WebViews. Preserve the original message ID even if the UI uses a thread model.

### Attachment workflow and recovered client limits

The original iOS compose state initializes 15 allowed filename extensions, passed into file picker as allowedExtensions and also displayed in UI:

`pdf, jpg, jpeg, png, txt, doc, docx, odt, ppt, pptx, mp3, mp4, xls, xlsx, xps`.

Evidence initializer0x441ff8–0x4420c8 constructs the list; addAttachment0x3de5a4 loads the same field for pickFiles. Client count check rejects adding when existing count>=2 (0x3de4ec). Client size check allows file size<=10,000,000 bytes and rejects larger (0x3de604–0x3de610). This is decimal10MB, not10MiB. These are constraints of this build, not independent server policy; do not claim larger/newer files are server-rejected without evidence.

Upload one file at a time as multipart field `file`, filename last slash-separated local path component and application/octet-stream part type. Let the HTTP library create Content-Type with boundary and Content-Length. The wrapper returns integer attachment ID; retain it with local filename/progress/error state. Send only completed upload IDs, and do not send while an upload remains pending. RemoveAttachment uses the returned attachment ID with POST/json null. The eventual message attachment decoder contains id/name/url; this does not mean upload returns that object.

If canceled after upload, cleanup semantics are not fully known; do not automatically delete attachments already referenced by a sent message. If send times out, do not retry blindly; an uncertain send can create duplicates. Delete route's soft/hard trash semantics and restoration remain a runtime gap, so do not implement permanent delete/restore from the trash screen name alone.

### Message decoder details

Message.fromJson reads id,subject,content,sent_date,sender,recipients_v2,cc_recipients_v2,bcc_recipients_v2,is_read,is_replied,is_deleted,tags,attachments. Strings are checked as Strings; sent_date→DateTime.parse, content→HTML parse. Sender is a nested MessageSender; recipient v2 collections map MessageRecipient; tags map MessageTag{id,name,color}; attachments map MessageAttachment{id,name,url}. Reviewed primitive checks are recorded in response-fields.json. Missing-vs-null/wrong-type distinctions on complex collections still need bounded branch fixtures; do not treat a decoder observation as a promise that arbitrary malformed JSON becomes [].

## Cross-cutting client features

The provider must connect to Siberia's account store, sync coordinator, cached domain models and UI through capabilities rather than transplanting the original GetX application. Its local display behavior includes homepage summaries, current/next/first lessons and before/during/after/no-lessons states, recent grades/homework/absences, semester selection, monthly/yearly attendance, stale/offline/error states, theme/language preferences, minimum-version checks and profile/child switching.

Cache dimensions: provider+validated school origin+account+student+school-year/semester+resource+date/range/folder/page/query. Clear all personal data and secure credentials on logout. Cancel/ignore requests started under a previous child/account. Notifications based on read diffs must preserve provider-qualified IDs and avoid marking messages read as a side effect of background preview. In-app unread count is established. Remote push registration/delivery remains unproven despite plist background/push declarations; do not reuse original Firebase configuration.

Render teacher HTML and attachment links using safe existing Siberia components; remote lessons should show their link only where supported. Keep availability/capability distinct from an empty server list. Unknown enum codes remain presentable and do not become default present/canceled statuses. Preserve local preferences outside provider credential cleanup if Siberia's settings policy says so (design choice).

## Ready-to-author boundary and targeted verification

|Area|Ready from static evidence|Remaining exact probe|
|---|---|---|
|Auth|identify/refresh/version verbs,paths,JSON,headers;storage;JWT expiry;single-flight;local logout|One enrollment response for actual school URL/current support; expiry/revocation errors; declared compatibility App-Version policy|
|Profile|User scalar types and recursive students;role by name|Real guardian with2children, absent students/wrong-type branch validation; child visibility/account scope|
|Timetable|day/path/date,lesson hierarchy,exams/accompaniments/remote/substitution|School timezone and varied missing optional fields; actual substitution code examples|
|Grades|overview/list routes,required numeric_value STRING,constructor ownership,nullable metadata|iOS weight value/factor branch; real numeric/text marks and missing colors; average policy if calculating|
|Attendance|read routes,counts,enumcodes;requestPOSTbody/dateformat/type3|Eligibility/range inclusivity; controlled request duplicate/rejection states; no invented status field|
|Homework|read route,HTML/date/nested attachments|Submission wire status mapping and whether a real submit action exists; no write API currently established|
|Messages read|folderstrings,GETpath,limit8,minsearch3,decoderkeys|First page origin,next-page/termination; special query characters; all complex nullable list branches|
|Messages write|POSTsend/read/delete/files;bodykeys;context.message.id+action.name pipeline;filelimits/list|Controlled recipient key send; uncertain-send/delete/cleanup semantics|
|Push|In-app unread polling count|Actual push registration endpoint/token lifecycle; remain capability unavailable until proved|

A future agent should implement static request/decoder behavior with synthetic tests first. Then perform only the listed narrow authorized probes. Do not turn unresolved parts into fictitious working APIs. Every result must keep build-specific confidence; older Android and newer iOS differences are intentional here.

## Full 33-feature traceability

The following checklist preserves all original rows. “Contract ready” means request recipe/known model exists; it does not claim deployed support. See feature-traceability.json for evidence references and original feature wording.

|ID|Feature|Static readiness / next step|
|---|---|---|
|FRY-001|Intro and login options|Manual mobile credentials, QR/deeplink Base64 UTF8 colon grammar; identify/refresh bodies and local logout.|
|FRY-002|Current user/profile|GET users/getCurrent; recursive User.students and name-decoded role; child selection is local context, no select-child route proved.|
|FRY-003|Homepage summary|Compose homepage from recovered lessons/grades/homework/attendance reads; no standalone dashboard endpoint.|
|FRY-004|School-day progression|Derive before/during/after/no-lessons state from dated Lesson list, retaining school-local time assumption.|
|FRY-005|Timetable by day|GET lessons/listAtDay/{studentId}/{y-MM-dd}; retain date and student in cache key.|
|FRY-006|Lesson details|Lesson model covers room, teacher list, times, descriptions, attendance, remote link and request object.|
|FRY-007|Music-school lesson structure|Lesson.exams/accompaniments have independent timing and content; preserve nested/overlapping music lesson structure.|
|FRY-008|Substitutions|is_substitution plus provider SubstitutionType codes1..5 and original names.|
|FRY-009|Grades list and recent grades|GET grades/list/{studentId}/10; numeric_value is String in Android; preserve text/metadata and raw weight.|
|FRY-010|Grade overview by semester/subject|GET grades/getOverview/{studentId}; semesters/subjects/normal/predicted/final Grade objects.|
|FRY-011|Attendance totals|GET attendances/getOverview/{studentId}; year/month periods and num percentage/count fields.|
|FRY-012|Attendance per lesson|GET lessons/listWithAbsence/{studentId}/{limit??0}; LessonWithAbsence plus nested request.|
|FRY-013|Attendance status fidelity|AbsenceType custom codes0..8 documented; preserve unknown raw codes instead of converting to present.|
|FRY-014|Absence change requests|GET listAbsenceTypeChangeRequests; POST requestAbsenceTypeChange with id/student_id/start/end/absence_type3/absence_reason.|
|FRY-015|Absence request constraints|Original UI contiguous-lessons constraint and teacher approval text; no status keys invented.|
|FRY-016|Homework list and recent homework|GET homeworks/list/{studentId}/{limit??0}; preserve dates, subject/teacher and ordering.|
|FRY-017|Homework rich content and files|Homework content HTML and name/url attachments are reads; use safe rendering/download components.|
|FRY-018|Homework submission status|HomeworkSubmissionStatus enum display labels/ordinals recovered; wire field binding remains unknown.|
|FRY-019|Homework submission/upload|No homework submission/upload request recovered; keep capability unavailable.|
|FRY-020|Messages inbox/sent/trash|GET messages/list/{inbox/sent/trash}/{page}/8; Message decoder and POST countUnread body JSON null.|
|FRY-021|Message search|GET messages/list/search/{page}/8?query=...; literal search folder and UI min3characters.|
|FRY-022|Message detail and mark read|List supplies full Message data; POST messages/markAsRead/{id} JSON null. No separate detail GET proved.|
|FRY-023|Compose message|GET messages/getRecipients; POST messages/create with six exact arrays/string keys and Message result.|
|FRY-024|CC/BCC|cc_recipients/bcc_recipients keys in send; response cc_recipients_v2/bcc_recipients_v2.|
|FRY-025|Reply/reply all/forward|Context originalMessage.id plus MessageAction.name; exact reply/replyAll/forward suffixes and ordinals proved.|
|FRY-026|Message attachment add/upload|Multipart POST uploadAttachment field file; basename; application/octet-stream; client max2,10000000bytes,15extensions.|
|FRY-027|Message attachment removal|POST messages/removeAttachment/{attachmentId} with JSON null.|
|FRY-028|Message deletion|POST messages/delete/{messageId} with JSON null; never substitute HTTP DELETE.|
|FRY-029|Message restore/permanent delete|No separate restore/permanent-delete request proved; keep capabilities unavailable.|
|FRY-030|Theme/language/preferences|Theme/language/local preferences are client behavior; map to Siberia preferences, not a guessed server endpoint.|
|FRY-031|Offline/cache/connectivity|Cache/logout clear and offline/error states observed; use account+school+student-qualified caches.|
|FRY-032|Minimum version/update required|POST versionBase/validate without body; App-Version header;426 maps UnsupportedException.|
|FRY-033|Notification delivery|Unread count in-app is proved; remote push registration/lifecycle remains unproved.|
