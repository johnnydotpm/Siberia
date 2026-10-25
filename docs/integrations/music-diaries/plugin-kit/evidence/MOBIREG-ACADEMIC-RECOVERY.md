# Modern MobiReg academic modules: recovered request builders

These are **static client contracts**, recovered from supplied Android MobiReg 3.1.7 (`libapp.so` SHA-256 `22dd67993cd25ccb0a56fca7eef87ffc1d40cc1bffd9057b671c7268afc4d97a`, Dart 3.13.2, snapshot `0451907c2eaa8467e848c0067bfe8ed4`). No backend or original application was executed. Named ARM64 Blutter output under `blutter-android/asm/rodzic/` supplies the PC evidence below. Independent r2flutter parsed all 843 snapshot clusters and recovered 25,593 functions. These PCs are ELF virtual addresses in this carrier, not iOS offsets.

`academic-contracts.json` contains **18 operations** plus model-reader key/PC locators. `academic-source-index.json` fingerprints the local generated ASM files for rechecking. This report replaces the earlier string-only uncertainty for these particular caller contracts; it does not prove current server acceptance or permissions.

## Gateway read and poll operations

Every row below calls `AppApi.requestView` at `0x48ead4`, supplies the selected `pupilId`, and uses the exact selector listed. The shared gateway uses **POST form data** (`http.post` at `0x48ee4c`), including `view`, `format=json`, `token`, and `JWTToken`; compose the exact shared origin/auth/envelope from the separately recovered auth-gateway report. Do not turn selector names into guessed REST routes, and do not assume the word `requestView` means read-only: the poll actions use this same gateway.

| ID | Selector | Extra parameters sent by caller | Call PC | Response consumer |
|---|---|---|---|---|
| MRA-01 | `marks` | `termId: selectedTerm.toString()` | `0x48eabc` | Map with `subjects`, `teachers`, `markGroups`, `grades`; per-subject averages `avg1`, `avg2` |
| MRA-02 | `terms` | None | `0x4918ec` | List of `Term.fromJson` |
| MRA-03 | `tests` | None | `0x493274` | `teachers` dictionary and `items` list, mapped with `Exam.fromJson` |
| MRA-04 | `attendance-stats` | None | `0x4a1f78` | `records`, `subjects`, `terms` |
| MRA-05 | `reprimands` | `limit: "100"` | `0x49d3ac` | `items` list and compatibility rewrites before `Reprimand.fromJson` |
| MRA-06 | `timetable-events` | `dateFrom`, `dateTo`, from `DateHelper.toIso` | `0x499aec` | List or map's `data`, then `TimetableEvent.fromJson` |
| MRA-07 | `dashboard` | `weeks: weeks.toString()`, `attMode: attendanceMode.toString()` | `0x75d558` | List of `DashboardElement`, with `type`, `date`, `label`, `data` |
| MRA-08 | `announcements` | None | `0x49be00` | Raw list or map `data`; optional `pendingCount` |
| MRA-09 | `announcement` | `id: announcement.id.toString()` | `0x6b4b54` | Detail map → `Announcement.fromJson` |
| MRA-10 | `announcements-pending` | None | `0x4a60c8` | List or map `data`, pending item IDs and `pendingCount` |
| MRA-11 | `announcement-answer` | `id: announcementId.toString()`, `answer: selectedAnswerString` | `0x79d0bc` | `AnswerResult`, requires payload map `success == true` |
| MRA-12 | `announcement-answer` | `id: announcementId.toString()`, `decline: "1"` | `0x79d0bc` | Same result as answer |
| MRA-13 | `justification-events` | `dateFrom`, `dateTo`, from `DateHelper.toIso` | `0x7bacc4` | Map `data` grouped by date then numeric event ID → `JustifyEvent.fromJson` |

The extra parameter maps are typed `Map<String,String>` at their construction sites. In particular, `limit` is a literal string, not an unboxed numeric immediate. `dateFrom`/`dateTo` are wire keys while the cache uses `from`/`to`; marks cache uses `t` while the wire uses `termId`; dashboard cache uses `w`/`a` while the wire uses `weeks`/`attMode`. Keeping those separate prevents an implementation from sending cache-key abbreviations to the server.

`DateHelper.toIso`, `helpers/date_helper.dart:0x49805c`, extracts date parts and builds `year + "-" + zero-padded month + "-" + zero-padded day` at `0x4981c0–0x4981f0`. The helper does not convert to UTC. Date-range inclusivity and school timezone behavior still require an authorized response fixture.

The announcements detail method is named `fetchAndConfirmDetail`; it can use an existing detail, otherwise fetches and invalidates announcement/dashboard cache. Treat opening detail as potentially changing remote read state until checked. There is no separate acknowledgement request established here.

### Poll writes and confirmation

`AnnouncementsRepository.postAnswer` (`0x79d6a4`) constructs exactly `{ "answer": selectedString }` at `0x79d6dc–0x79d6fc`. `decline` (`0x79c9bc`) constructs `{ "decline": "1" }` at `0x79c9f0–0x79ca10`. Both call `_mutateAnswer`. Its request closure (`0x79cfe0`) builds a new string map, stores `id` as the record ID converted to a string (`0x79d048–0x79d088`), merges the action map (`0x79d09c`), and passes it as `extraParams` to selector `announcement-answer` (`0x79d0b0–0x79d0bc`). These are proven map writes and argument relationships, not string adjacency.

`_mutateAnswer` consumes envelope data (`0x79cc04`) only as a map. It tests the `success` value against the literal boolean `true` (`0x79ccd0–0x79cd0c`); then reads optional `userAnswer`, `declined`, and `pendingCount` (`0x79cd20`, `0x79cd84`, `0x79cddc`). `pendingCount` is parsed with `int.tryParse(value.toString())`; `userAnswer` is converted to text when present. `declined` is compared with literal `true` in this result path. Failure logs the `error` field where available (`0x79cf68`) and returns the failed `AnswerResult`. Do not treat mere HTTP success as an accepted answer.

Poll mutation cache invalidation covers selected pupil's `announcements`, `announcement` (with `id=...` signature), and `dashboard` (`0x79caec–0x79cb78`). The model preserves `pending`, `pollOpen`, `userAnswer`, `declined`, and `answers`. `Announcement.isPendingPoll` (`0x49ad34`) checks type values 2 or 3, pending, no answer, and not declined. `availableOptions` (`0x79e510`) supplies `TAK`/`NIE` when type is 2 and the answer option list is empty. These comparison constants are unboxed int fields, not tagged Map values. Do not infer every numeric enum meaning or auto-answer the poll.

## Justification REST operations

These operations use a distinct REST boundary. `AppApi._apiBase` (`services/api/app_api.dart:0x76c418`) obtains configured `pageAddress` and `schoolCode`, strips an HTTP(S) prefix and trailing slash from the former, then constructs:

```text
https://{normalizedPageAddress}/{schoolCode}/api
```

The final path below is appended to that base. Both `restGet` and `restMutate` construct `Authorization: Bearer {token}`, `Content-Type: application/json`, and this build's `User-Agent: MobiReg/3.1.7 (6f4e7b8)`. Preserve legitimate origin/tenant scoping when implementing; recovered string concatenation is not a reason to send credentials to arbitrary input URLs.

| ID | Method and appended path | Body | Call PC | Client result |
|---|---|---|---|---|
| MRA-14 | `GET /justifications?pupil_id={pupilId}` | None | `0x76da2c` | Envelope data list → records |
| MRA-15 | `GET /justifications/{recordId}` | None | `0x7bb5a0` | Envelope data map → record; other shapes return null |
| MRA-16 | `POST /justifications` | JSON `{pupil_id, message, event_ids}` | `0x76e588` | Raw decoded JSON map's numeric `id` converted to int, else null |
| MRA-17 | `PUT /justifications/{recordId}` | JSON `{message, event_ids}` | `0x76e184` | Wrapper returns true if mutation completed; caught exception returns false |
| MRA-18 | `DELETE /justifications/{recordId}` | None | `0x76bcac` | Same wrapper completion semantics as update |

Body construction is explicit: create keys at `0x76e518`, `0x76e530`, `0x76e544`, stored values at `0x76e52c`, `0x76e540`, `0x76e558`; update keys at `0x76e128`, `0x76e140`, stored values at `0x76e13c`, `0x76e154`. Update does **not** include `pupil_id`. Record IDs are interpolated into the path. `event_ids` receives the selected event-ID list; `message` receives reason text. This submits/edits a request rather than directly changing official attendance.

`restMutate` JSON-encodes the body only when non-null (`0x76bf34–0x76bf48`). Its method dispatch is explicit POST/PUT/DELETE (`0x76bf54`, `0x76bf98`, `0x76bfe0`); HTTP calls are `0x76bf74`, `0x76bfbc`, `0x76c000`. It accepts 200–299 (`0x76c078–0x76c084`); an empty trimmed body returns null (`0x76c090–0x76c0a4`), otherwise the result is `jsonDecode(response.body)` (`0x76c0ac–0x76c0b8`). Other statuses throw an `ApiBadResponseException` carrying HTTP status. Crucially this mutation helper returns raw decoded JSON, whereas `restGet` supplies the read envelope. Do not apply the read-envelope shape to create/update responses.

The original update/delete wrappers do not inspect a `success` field; they equate completion without exception with true. For Siberia's reliable status presentation, refresh the request record/list after writes, particularly for an ambiguous timeout, and preserve unverified/denied states. Do not auto-repeat writes after an uncertain response.

All justification mutations invalidate `justifications`, `justification`, `justification-events`, `attendance-stats`, and `dashboard` (`_mutationInvalidations`, `0x76bb14`). Eligible lesson/event data and request status therefore need refreshing together.

## Response fields consumed by named models

The JSON companion records exact constructor/method PC key accesses. These are **client-consumed fields**, not a complete server JSON Schema or real response capture. Optional/null/default branches are independently visible in ASM; do not convert a field-name list into a claim every key is required.

| Model / consumer | Keys and useful distinctions |
|---|---|
| `JustificationRecord.fromJson`, `0x76cf38` | `events`, `id`, `created_at`, `message`, `period_from`, `period_to`, `event_count`, `status`; numeric count/status pass through `num?` conversion with default zero. Numeric status meanings remain unresolved. |
| `JustifyEventRef.fromJson`, `0x76d5f4` | `event_id`, `day`, `subject`, `time_from`, `time_to`, `attendance_type`, `absence_code`, `applied_status` |
| `JustifyEvent.fromJson`, `0x7ba880` | `ab`, `st`, `end`, `sub`, `js`, `attendance_type`; event ID comes from enclosing map key. `attendance_type` fallback string is `absent`. |
| `Announcement.fromJson`, `0x49b1ec` | `read` / `xread`, `answers`, `userAnswer`, `valid`, `id`, `type`, `kind`, `title`, `dateTime`, `author`, `login`, `content`, `declined`, `pollOpen`, `pending`. `_flag` accepts actual true, numeric 1, and strings `1`/`true`; missing `pollOpen` defaults true. Preserve server policy and unknown types. |
| `Term.fromJson`, `0x4913bc` | `id`, `parentId`, `label`, `isYear`, `dateFrom`, `dateTo`; school-year range consumer prefers isYear then a valid range fallback. |
| `Mark.fromApiJson`, `0x48d574` | `id`, `subjectId`, `value`, `weight`, `date`, `bgColor` / `color`, `description`, `kindLabel`, `comments` / `comment`, `count_to_avg` / `countToAvg`, `teacher_id` / `teacherId`, `subject_name`, `teacher_name`, `teacher_surname`, `markGroupId` |
| `TermMark.fromApiJson`, `0x48d14c` | `isFinal` / `is_final`, `isProposal` / `is_proposal`, `value` / `val`, `mtTeacherId` / `teacherId` |
| `Exam.fromJson`, `0x492758` | `dateTime` / `date`, `addedTime` / `added_date`, `id`, `pupil_id`, `teacherId` / `teacher_id`, `title` / `name`, `description` / `content`, `test_type`, `subjectName` / `subject_name`, teacher names, `startTime` / `start_time`, `endTime` / `end_time` |
| `TimetableEvent.fromJson`, `0x498740` | `tests`, `teachers`, color/attendance fields; `dateTimeFrom` / `startTime`, `dateTimeTo` / `endTime`, `subjectName`, `title` / `content` / `topic`, `room` / `roomName`, `type`, `isLocked`, `isCanceled`, `substitution`, `oldSubjectName`, `oldTeachers`. Preserve exam and teacher collections. |
| `AttendanceRecord.fromJson`, `0x4a1cac` | Short keys `ca`, `d`, `sid`, `ab`, `tn`; preserve raw codes instead of assuming ordinary school-period numbering. |

## Implementation checks still required

Use these recovered builders to create independently authored client code and synthetic structural fixtures. Verify legitimate auth/origin, envelope compatibility, date inclusivity, permissions, pending-poll eligibility, all status code meanings, empty/malformed responses and write confirmation with an explicitly authorized test account. A server rejection must preserve cached data. Keep cache and selected-child/year boundaries intact. None of these static records is a live integration test.
