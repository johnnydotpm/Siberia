# Fryderyk: evidence-backed integration handoff

> Historical first-pass handoff. Prefer the [detailed specification and agent runbook](../plugin-kit/providers/fryderyk/SPEC.md) for recovered endpoint/auth contracts, field schemas, examples and remaining gates. In a conflict, the newer version-scoped caller evidence takes precedence.


## Scope and evidence boundary

Analyzed supplied Android 1.0.12 and iOS 1.1.7 (build 35), package/bundle `com.netro42.fryderyk.app`. Both ship a Flutter application whose app-owned Dart package is `fryderyk_mobile_v3`. These are different releases: do not assume platform parity. The iOS release contains messaging modules and API candidates absent from the bounded search of the older Android app.

This is static evidence, not a working client or an authenticated API specification. No original app was launched and no provider service was contacted. No account credentials were supplied. Route literals, class names, UI text, and config are observed; feature semantics below are inferred from multiple such observations unless explicitly identified as a visually inspected bundled guide image. HTTP methods, request/response shapes, enum numeric codes, and auth exchange order remain unresolved. An implementer must complete the contract probes below before enabling live requests. “All features” here means all feature families recoverable within these two supplied client packages; it does not include an unobserved teacher/admin web application.

The root investigation used the REA skill and archive inventory. Its JADX provider was initially missing, and Ghidra was not configured. Flutter Dart logic lives in native AOT rather than Android Java wrappers, so JADX alone would not recover its API behavior. The iOS App Mach-O reports LC_ENCRYPTION_INFO_64 cryptid=0, but only four native symbols, so it has accessible bytes without useful conventional function symbols. Native call graph/decompilation is still needed for complete contracts.

Evidence files:

- `curated-evidence.json`: original library identities, 34 platform-specific route occurrences (21 iOS, 13 Android), 110 iOS and 95 Android app-owned source-path occurrences. Every route includes literal and file offset. No verb or schema is invented.
- `feature-evidence.json`: 236 selected iOS literal/source-path records with stable `FSTR-<hex-file-offset>` analyst IDs. These are not REA-issued Evidence IDs. `features.json` operation labels distinguish read candidates, mutation candidates, mixed workflows and unknowns; none establishes an HTTP verb.
- `extract_evidence.py`: reproducible offline route/source-path extraction, requiring the already extracted inputs.
- Local working material `ios-dart-strings.json`, `ios-dart-strings.txt`, `android-ascii-strings.json`, `ios-symbols.json`: useful for follow-up analysis, but not automatically safe to publish wholesale. They mix app, framework, and configuration strings.

Library SHA-256:

| Input | SHA-256 |
|---|---|
| Android split `config.arm64_v8a.apk` member `lib/arm64-v8a/libapp.so` | `8fdabb00afead92a3f36b71621ddf5976441191255b504c49de01c9681aeb738` |
| iOS `Payload/Runner.app/Frameworks/App.framework/App` | `2c11d5a1be3f1f21d85c2b9c4deb8c59d2c3c33dfd9eebf0235657bcc6f7cca1` |

The iOS extractor scans 16-byte aligned object candidates from file offset 0x840000, class ID `(tag >> 12) & 0xfffff` 94/95, Smi length at header+8, payload at +16. 94 is Latin-1 and 95 UTF-16LE in this build. This is a string-layout heuristic corroborated against representative payload lengths and known application strings in this exact library hash, not a complete Dart snapshot parser. The hardcoded range/class IDs are build-specific; they must not be applied to a different binary as though coverage were complete. It recovered 38,488 candidate string objects. Android uses serialized snapshot strings and is scanned as complete printable ASCII runs; long strings may have adjacent printable metadata bytes. The script trims app source paths at `.dart`. Android UTF-16/non-ASCII snapshot text was not comprehensively decoded, so localized labels and related strings can be missing. Negative Android searches do not prove server-side absence.

## Authentication, enrollment and account context

Observed packaged production configuration, in Android `.env` and iOS `.env.production`:

- `TOKEN_API_URL=https://swiadectwa.fryderyk.edu.pl/api/tokens`
- `VERSION_API_URL=https://swiadectwa.fryderyk.edu.pl/api/version`

iOS also includes development and preproduction env files. Their existence does not establish which environment is selected at runtime; use production by deliberate configuration and never probe staging automatically. These two URLs are service-discovery/auth/update candidates, not evidence that every diary data request goes to the same host.

Auth route suffixes in both packages: `/identify`, `/reIdentify`, `/login`, `/validate`. iOS literals `TOKEN_API_URL` (0x85ac80), `access_token` (0x860ae0), `refresh_token` (0x9d3aa0), `Bearer ` (0x8bc7b0), `Authorization` (0x9a7050), storage names `access-token` (0x9b4ad0), `refresh-token` (0x9b3320), private methods `_identify`, `_reIdentify`, `_refreshAccessToken`, `get:isAuthenticated`, and TokenService failure strings corroborate an identity/access/refresh lifecycle. They do not prove OAuth compliance or exact refresh exchange.

The app has manual, QR, and deep-link login screens and a login guide. Info.plist registers the `fryderyk` custom URL scheme. The exact deep-link host/path/query and QR payload grammar are unknown. The manual screen warns about an identifier without the `m.` prefix (`FSTR-8a7020`) and has `identifier`/`password` literals. Treat mobile credentials as a separate credential kind from ordinary website login.

Three bundled guide images were visually inspected as static product documentation:

1. `assets/images/login-guide-1.png`: sign into the Fryderyk website. It also shows parent/guardian web registration and account recovery; those web actions are not evidence of equivalent mobile APIs.
2. `login-guide-2.png`: open the top-right account menu and choose **Dostęp mobilny**.
3. `login-guide-3.png`: choose **Wygeneruj dane logowania** under mobile access management.

Logout confirmation says fresh login data must be generated on the diary website to log in again (`FSTR-852ae0`). Preserve this warning; do not present reconnect as an ordinary saved-password retry until revocation semantics are known.

`users/getCurrent`, `User.fromJson`, `students`, `get:activeStudentId`, `setActiveStudentId`, `get:activeStudent`, `get:activeSemester`, `UserType`, `parent`, and `student` support a user profile plus linked student selection and semester context. A `teacher` literal also exists, but no teacher grade-editing/lesson-administration workflow was established. Do not advertise teacher-write support from that enum label.

Siberia requirements: provider-qualified account/student IDs; secure mobile credential/token storage; atomic token refresh; child switching that cancels stale in-flight fetches; token invalidation/logout and reconnect states; provider-specific onboarding; URL/QR parser isolated from routing. Validate the returned school/data origin and keep credentials scoped to their intended host; a route-discovery response must not become arbitrary authenticated URL execution.

## Full recoverable feature inventory

“Both” means corroborating app module and/or route evidence appears in both packages; it does not mean runtime-tested parity.

| Feature family | Version evidence | What Siberia must cover | Specific evidence |
|---|---|---|---|
| Intro and login options | Both | Manual mobile ID/password, camera QR, deep-link, guide and invalid-credential feedback | `manual_login_screen`, `qr_login_screen`, `deep_link_login_screen`, `login_options_screen`, TokenService |
| Current user/profile | Both | Profile identity, linked children, active child and logout | `users/getCurrent`, `User.fromJson`, `profile_screen` |
| Homepage summary | Both | Current/next/first lesson and school-day state, recent grades, homeworks and absences | `homepage_partial_screen`, `current_lesson_card`, `_getSchoolDayState`, recent partials |
| School-day progression | Both | Before lessons/during/after/no-lessons states with empty-day and completed-day messages | `SchoolDayState`, `beforeLessons`, `duringLesson`, `noLessons`, day-completed text |
| Timetable by day | Both | Date navigation and day-specific lessons; preserve actual start/end times and room | `lessons/listAtDay/`, `date_selector`, `lesson_details_screen` |
| Lesson details | Both | Subject, teacher, classroom, description/comment, remote link and status | `Lesson.fromJson`, `remote_link`, `substitution_type`, lesson-detail strings |
| Music-school lesson structure | Both | Individual lessons/teaching, accompaniment, exam and substitution details | `LessonAccompaniment.fromJson`, `LessonExam.fromJson`, `is_individual`, `isAccompaniment`, `isExam`, `LessonsTree` |
| Substitutions | Both | Replaced/cancelled/common-room/teacher-care and substitute/original teacher labels; preserve unknown provider code | `SubstitutionType.fromTypeCode`, `substitution_teacher_full_name`, `substituted_teacher_full_name`, status labels |
| Grades list and recent grades | Both | Grade details; do not coerce text-only marks to zero | `grades/list/`, `Grade.fromJson`, `numeric_value`, `text_value`, `recent_grades_partial_screen` |
| Grade overview by semester/subject | Both | Subject grouping, semester switch, predicted and final grades, empty semester and unavailable overview | `grades/getOverview/`, `GradesOverviewSemester`, `GradesOverviewSubject`, `predicted_grade`, `final_grade` |
| Attendance totals | Both | Whole-school-year and monthly overview, provider denominator/counts and percentages | `attendances/getOverview/`, `AttendancesOverviewPeriod`, `_buildYearlyAttendanceOverview`, `_buildMonthlyAttendanceOverview` |
| Attendance per lesson | Both | Recent absences and lesson list, absence type and reason, detail links | `lessons/listWithAbsence/`, `LessonWithAbsence.fromJson`, `absence_type`, `absence_reason` |
| Attendance status fidelity | Both | Present, late, explained absence, not-excused, other absence/present; retain code and label | `AbsenceType.fromTypeCode`, `present`, `late`, `explainedAbsence`, `notExcused`, `otherAbsence`, `otherPresent` |
| Absence change requests | Both | Pending request list, date range, eligible lesson selection, reason, submit and acknowledgement | `listAbsenceTypeChangeRequests`, `requestAbsenceTypeChange`, corresponding screens, `absence_type_change_request` |
| Absence request constraints | Both | Contiguous selected lessons; approval by supervising teacher/class guardian | `FSTR-9cca50`, `FSTR-877330`; exact server validation still unknown |
| Homework list and recent homework | Both | Active tasks, subject/teacher, deadline and task detail | `homeworks/list/`, `Homework.fromJson`, `finish_date`, `publish_date`, recent-homework partials |
| Homework rich content and files | Both | Instruction HTML, teacher/subject info, attachment opening and failure state | `HomeworkTeacher`, `HomeworkSubject`, `HomeworkAttachment`, `_openAttachment`, `homework-instruction` |
| Homework submission status | Both | Awaiting solution, sent to teacher, accepted by teacher | `HomeworkSubmissionStatus`, `submission_status`, status labels |
| Homework submission/upload | Unresolved | Do not claim a write API: recovered status display does not establish task submission | No submission route recovered; message file-upload route is unrelated |
| Messages inbox/sent/trash | iOS 1.1.7 | Folder selection, unread badges, pagination/empty/error states, read/unread presentation | Inbox/Sent/Trash partials, `messages/list/`, `messages/countUnread`, `is_read`, `is_deleted` |
| Message search | iOS 1.1.7 | Search with configured minimum character count and empty search result | SearchMessages partial, `message-search-phrase-rule`; exact count unknown |
| Message detail and mark read | iOS 1.1.7 | Sender/date/subject/content, recipient lists, attachments and unread counter update | `Message.fromJson`, `MessageSender`, `MessageAttachment`, `messages/markAsRead/` |
| Compose message | iOS 1.1.7 | Recipient suggestions, at least one recipient, subject/body validation, rich editor | `message_form_screen`, `messages/getRecipients`, `messages/create`, validation texts |
| CC/BCC | iOS 1.1.7 | Separate recipient fields; preserve provider v2 identifiers rather than assuming e-mail addresses | `recipients_v2`, `cc_recipients_v2`, `bcc_recipients_v2`, legacy cc/bcc fields |
| Reply/reply all/forward | iOS 1.1.7 | Recipient derivation and localized quoted body/header content | `MessageAction`, `reply`, `replyAll`, `forward`, initial-message and quoted-content strings |
| Message attachment add/upload | iOS 1.1.7 | File picker, upload progress, allowed extension/size/count validation, wait until uploads finish | `messages/uploadAttachment`, `attachment_ids`, `maxAttachments`, limit and wait strings |
| Message attachment removal | iOS 1.1.7 | Remove draft/uploaded attachment and reconcile local draft only on result | `messages/removeAttachment/`, `removeAttachment` |
| Message deletion | iOS 1.1.7 | Delete/trash action and refresh affected folders/unread counts | `messages/delete/` and trash partial; soft/hard delete semantics unknown |
| Message restore/permanent delete | Unresolved | Do not invent restore or permanent-delete contracts from trash folder alone | No distinct route/verified action recovered |
| Theme/language/preferences | Both | Preserve Siberia visual settings and local language; original has FrydThemeData and translations | App-owned `fryd_theme_data.dart`, `fryd_translations.dart`, color helper |
| Offline/cache/connectivity | Both | Cache reads, stale-data indicator, refresh/error recovery, account-scoped invalidation | CacheManager/InMemoryCache/SharedPreferencesCache, ConnectionStatusController, process states |
| Minimum version/update required | Both | Map provider incompatibility to actionable error; distinguish server policy from app store version | VERSION_API_URL, VersionService, `update_required_screen` |
| Notification delivery | Partial/unresolved | In-app unread count established. Actual remote push registration/delivery not established | Info.plist declares remote-notification/fetch, but declaration alone does not prove an app workflow |

No dedicated fees/payments, practice timer/log, repertoire tracker, certificate export, scheduling edits, attendance writes beyond requests, grade writes, registration API or password-change API was established in the bounded app-owned paths/route literals. Their absence here does not prove the server or web product lacks them. Do not treat generic rich-media/framework dependencies as app features.

## Route catalog and wire-contract gate

All below are **literal candidates**. A trailing slash suggests an appended parameter but does not establish its identity or type. `/api/` appears at iOS 0x8b5780; actual host construction, path concatenation and slash handling need call-site proof.

| Literal | iOS offset | Android offset | Candidate responsibility |
|---|---|---|---|
| `/identify` | 0x9b1a10 | 0xc9d20 | Initial mobile identity/discovery |
| `/reIdentify` | 0x8fcd10 | 0x7b848 | Re-identify or refresh lifecycle |
| `/login` | 0x8fb820 | 0x7ae90 | Mobile login |
| `/validate` | 0x9d1980 | 0xd6ec4 | Credential/session validity |
| `users/getCurrent` | 0x9cdf40 | 0xd56a4 | Current profile/children |
| `grades/list/` | 0x8c3b00 | 0x647b1 | Grade list |
| `grades/getOverview/` | 0x94f750 | 0x9f951 | Semester/subject overview |
| `attendances/getOverview/` | 0x858c00 | 0x3761d | Attendance aggregates |
| `attendances/listAbsenceTypeChangeRequests/` | 0x950410 | 0x9ff10 | Request list |
| `attendances/requestAbsenceTypeChange` | 0x888130 | 0x4b2d2 | Submit request |
| `lessons/listAtDay/` | 0x95dbd0 | 0xa5810 | Day plan |
| `lessons/listWithAbsence/` | 0x9409a0 | 0x9944a | Lessons with attendance |
| `homeworks/list/` | 0x8fa6f0 | 0x7a647 | Homework list |
| `messages/list/` | 0x918140 | — | Folder/search listing |
| `messages/countUnread` | 0x9dcb50 | — | Unread count |
| `messages/getRecipients` | 0x989e70 | — | Suggestions/directory |
| `messages/create` | 0x869b80 | — | Send message |
| `messages/markAsRead/` | 0x910120 | — | Read side effect |
| `messages/delete/` | 0x8e0c60 | — | Delete side effect |
| `messages/uploadAttachment` | 0x950de0 | — | File upload |
| `messages/removeAttachment/` | 0x988750 | — | Remove upload |

For EACH route the next agent must fill: constructed origin/base URL; HTTP verb; auth header/cookie rules; route parameter names; query/body keys and types; date format/timezone; multipart field names; success response structure; IDs and nullable fields; pagination cursor and termination; error codes; retry/idempotency policy; fixture provenance. Until filled, keep network adapter disabled behind capability flags. Do not let the apparent action name determine the HTTP verb.

## Candidate model vocabulary: preserve, then verify ownership

`*.fromJson` labels identify these model names; adjacent literal field names are not proven to belong to a given constructor. The groupings below are proposed fixture work queues, not established schema declarations.

- User/student: User, UserType; `students`, `first_name`, `last_name`, `full_name`, `student_id`, active student and semester getters. Exact nested student model and school context are unresolved.
- Grade: Grade, GradesOverview, GradesOverviewSemester, GradesOverviewSubject; candidate `numeric_value`, `text_value`, `predicted_grade`, `final_grade`, `subject_name`, `subject_short_name`, `subject_color`, `semesters`. Do not infer weight scales or calculate averages without provider rules.
- Lesson: Lesson, LessonTeacher, LessonExam, LessonAccompaniment, LessonWithAbsence; candidate `is_individual`, `is_remote`, `is_substitution`, `remote_link`, `substitution_type`, `substitution_teacher_full_name`, `substituted_teacher_full_name`, `room`, original/short names. Preserve accompaniment and exam structures separately; do not flatten nested lesson trees into duplicate timetable periods.
- Attendance: AttendancesOverview, AttendancesOverviewPeriod, AbsenceTypeChangeRequest; candidate `absence_type`, `absence_reason`, `absence_type_change_request`, `attendancePercentage`, `lessonsWithExplainedCount`, `lessonsWithExcusedCount`, `lessonsWithLateCount`. Denominators and whether excused/explained overlap must be verified before aggregating.
- Homework: Homework, HomeworkSubject, HomeworkTeacher, HomeworkAttachment, HomeworkSubmissionStatus; candidate `publish_date`, `finish_date`, `submission_status`, `attachments`. Status labels are display evidence; server numeric/string encodings unknown.
- Message: Message, MessageSender, MessageRecipient, MessageAttachment, MessageTag; candidate `sent_date`, `is_read`, `is_replied`, `is_deleted`, `recipients_v2`, `cc_recipients_v2`, `bcc_recipients_v2`, legacy `cc_recipients`/`bcc_recipients`, `attachment_ids`, `tags`. Do not collapse recipient IDs to sender IDs or emails without proof.

Keep unknown/raw fields alongside normalized domain models. Never infer that `date` strings are UTC or that `finish_date` is inclusive. For music schools, timetable wall time should be interpreted in verified school timezone, normally a Polish school zone, rather than the device timezone by assumption.

## Implementation work packages for the next agents

The main handoff maps concrete Siberia source paths. Use this sequence within that architecture:

1. **Contract recovery agent:** obtain a user-authorized test account/session for one parent with multiple children and, if possible, a student account. Passively capture the original app for each feature above; no production writes merely to enumerate screens. For writes, use a controlled test recipient/record and explicit task authorization. Redact tokens and student data, preserve structural fixtures and timestamps. Correlate each capture with exact app version, route and static offset. Alternatively use Dart-aware ARM64 decompilation to recover call sites and constructors; compare with runtime before declaring the client production-ready.
2. **Provider foundation agent:** create Fryderyk account type and provider capabilities; separate auth/bootstrap from data-origin transport; persist credential type and schema version. Implement invalid identifier/password, one-time enrollment/reconnect, unauthorized/expired token, revoked device access, concurrent refresh and logout. Test QR/deep-link inputs with malformed and foreign schemes before navigation.
3. **Read models agent:** implement profile/children first, then day plan/lesson detail, grades/overview, attendance/requests, homework. Use verified fixtures for every response. Retain raw IDs and provider enum labels. Cache keys include provider, server/school, account, student, school year/semester, resource and query range.
4. **Music-school UI agent:** add accompaniment/exam/individual/remote/substitution rendering; first/current/next lesson summary; subject grade tabs; monthly/yearly attendance and request status; homework HTML and safe attachments. Unknown enum codes remain visible as unknown, never silently mapped to present/cancelled.
5. **Messaging agent:** base scope on iOS 1.1.7 evidence. Implement read folders/search/count/detail and mark-read first; then compose/recipient suggestions/CC/BCC/reply-all/forward/files; finally delete/trash once semantics are verified. File limits and search minimum must come from verified policy, not guessed constants. Sending uses explicit user action and de-duplication; do not retry an uncertain send automatically.
6. **Absence request agent:** verify eligible statuses, date/lesson selection, contiguous-selection validation, reason, approval status and rejection handling. Do not write attendance directly. Preview exact selected lessons before submission.
7. **Cross-cutting agent:** account switch isolation, offline/stale presentation, token revocation, cache migration, background refresh, error taxonomy and notification diffing. Confirm remote push support separately before advertising it. Do not use original application's Firebase project/configuration for Siberia delivery.

Proposed completion tests: bootstrap discovery cannot leak credentials to another host; refresh races produce one new token pair; one child’s late response cannot replace another child's data; empty school day and overlapping individual/accompaniment lessons are distinct; text grades and predicted/final values survive; annual/monthly attendance preserves provider totals; absence requests reject gaps and show pending/approved/rejected states; task HTML/media remains readable; message paging terminates, read counts reconcile, BCC privacy is preserved, files respect verified limits, and uncertain writes are not replayed; full logout clears all provider-scoped secrets and cached personal data.

## Remaining questions and explicit completion status

| Question | Status | Required next evidence |
|---|---|---|
| Identify both supplied releases and technology | Answered statically | Package inventory and original hashes |
| Recover feature families and version differences | Partially answered with broad static coverage | Authenticated screen traversal and role coverage |
| Bootstrap credentials, school discovery, refresh and revocation | Partial | TokenService call graph plus controlled auth capture |
| Exact data routes, HTTP verbs and schemas | Partial | Caller/constructor decompilation or redacted real captures |
| Numeric enum values and semester/attendance semantics | Unresolved | Fixtures across statuses and academic periods |
| Messaging update/delete/trash semantics and file policy | Partial | iOS feature capture and permitted test writes |
| Homework submission write API | Unresolved | Actual submission UI/traffic or authoritative constructor/call graph |
| Remote push setup and notifications | Unresolved | Registration and delivery evidence |
| Teacher/admin write workflows | Unresolved/outside recovered mobile UI | Appropriate authorized role and shipped client evidence |
| Integration implementation | Not started in this research deliverable | Provider implementation after contract gate |

Do not mark Fryderyk “fully supported” merely because all recovered screens have counterparts. Gate each capability on a verified contract and a passing fixture/integration test. Keep this table updated when new evidence resolves a gap.
