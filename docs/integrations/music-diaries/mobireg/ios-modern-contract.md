# MobiReg iOS 3.1.7: modern candidate feature and protocol map

The carrier is `Payload/Runner.app/Frameworks/App.framework/App`, a Flutter AOT framework. Identity/hash is in `source-identities.json`. Evidence `MR-I01` is a structural Dart string scan with payload offsets. It establishes shipped model/screen/path/log literals; **it does not establish their function call graph or live HTTP contracts**. All modern request verbs, operation selector fields, full payloads, response envelopes and mutation semantics remain candidates unless independently recovered later.

## Auth, accounts and sessions

The package contains `AuthService`, `AccountsStore`, `Account`, `Pupil`, `Session`, `AppState`, `school_code.dart`, QR scanning and account-management screens. `auth_service.dart` is at payload offset `0x9cf940`; auth endpoint literals are `/modules/api/auth.php` (`0x97ecc0`), `/modules/api/refresh.php` (`0x86ae50`) and `/modules/api/qrlogin.php` (`0x9a06d0`). Shipped logs describe a saved JWT, a QR login with access+refresh tokens, password accounts, account-specific refresh, logout, migration and secure/cache cleanup. These support the candidate session model, not a guessed login JSON schema.

User flows include password sign-in, adding another account, editing account, scanning QR from the web app, choosing school, choosing account/child, silent session refresh and removing the local account. The removal text explicitly says that the diary account remains. A repair log describes adding self when a pupil account's child list omits the pupil. QR use can update an existing password account's token without changing the saved password; verify the exact account-match rule before recreating it.

`Session` tracks current pupil, selected term and current/periodic view. `MailSession` and `ModuleSession` are separate from the JWT session. The binary contains `homeworkSession`, `mail_session_cookie`, `mailCookie`, `moduleCookie`, `homeworkCookie`, `messages_token` and `setModuleCookie`/`setMailCookie`/clear methods. `/account/ssov2/` is at `0x84bb40`, and `/sso` at `0x899f20`. Logs report successful mail SSO and missing-cookie failure. Recover the exact token exchange, redirects, host selection and cookie scope. Never send all cookies or a JWT to every module origin.

The operation gateway literal `/modules/api/app.php` is at `0x976f40`. `ApiEnvelope`, `ApiExceptions`, `AppUpdateRequiredException`, `protocol_v`, `api_page_address`, `messaging_url`, `JWTToken`, `Authorization` and `pupil_id` occur in the binary. They are candidate keys, not a proven common request structure. Determine which keys are request fields, response fields or unrelated state before writing a client.

## Full candidate feature surface

`features.json` is the normative task checklist. The sections below explain why its newer-only capabilities must not disappear when a legacy adapter ships first.

Academic modules have distinct repositories/providers/screens and model constructors:

- Dashboard: combined grade/exam/homework/reprimand/announcement/absence feed; lookback weeks and attendance mode preferences. The help text says the lesson plan is in the Plan tab.
- Grades: `Mark`, `SubjectMarks`, `TermMark`, `Term`, grade detail, subject detail, current/periodic switcher. Shipped strings distinguish current grades, period grades, yearly grade, proposal/final flags and count-to-average metadata. Verify weighting and term hierarchy before applying Siberia's grade calculator.
- Attendance: dashboard attendance plus full records and stats; absent-only versus absent+late views. Gateway candidate `attendance-stats` appears at `0x8d1570`.
- Timetable: calendar/day picker, school-year bounds and fallback range, `TimetableEvent`, `TimetableExam`, event detail; navigation resets and school-wide plan-change notifications. `/timetable`/`/timetable/details` can be app routes; they are not established backend endpoints.
- Exams: list and details (`Exam.fromJson`, `ExamsRepository`, `exams_screen.dart`, `exam_detail_screen.dart`). Do not assume that every exam is stored as a homework item or a timetable lesson.
- Homework: `Homework`, `HomeworkDetail`, `HomeworkFile`, `HomeworkSolution`, `HomeworkSource`, diary/module repositories and `oldHomeworkModule`; list/detail, status/deadlines, teacher comments, solution text/files, archive and restore. Both `getDiaryHomeworks` and `getModuleHomeworks` are present. Source ID must include its homework origin/profile.
- Announcements: list/detail and deferred full-body fetch, attachments/HTML, votes/answers, `canAnswer`, `userAnswer`, pending-poll handling. Gateway candidates `announcement-answer` and `announcements-pending`; `PendingPollGate` and pending count indicate a required-answer workflow candidate. Do not bypass required polls or infer write permission from cached content.
- Reprimands/praise: list/detail with date, teacher and content; preserve their type rather than treating everything as negative behavior.
- Justifications: records, individual details, eligible events grouped by week, compose/edit/delete, reason text and event selection. `createRecord`, `updateRecord`, `deleteRecord` and `event_ids` are shipped. Exact verbs, write authorization and status transitions are unresolved.

## Mail path literals and operations

The binary has a native mail implementation (`mail_api.dart`, `mail_session.dart`, `MailRepository`, `MailProvider`, compose/detail/list screens) plus recipient and attachment models. Path literals are:

| Path or suffix | What the static evidence establishes |
|---|---|
| `/api/messages/inbox`, `/sent`, `/important`, `/trash` | Full path strings for folders; HTTP method/query/pagination unknown. |
| `/api/messages/` and `/api/messages` | Base/detail/send candidates; body, ID suffix and methods unknown. |
| `/api/messages/read/` | Read acknowledgement candidate; exact method/body unknown. |
| `/api/messages/receivers` and `/receivers/search` | Full recipient-directory/search path strings. |
| `/api/unreadMessages` | Unread count candidate. |
| `/stared` | Literal spelling is `stared`, not `starred`; association to star action requires call-flow/capture. |
| `/restore`, `/archive`, `/files` | Unbound suffix candidates; do not attach them to an invented parent path. |

Features include inbox/sent/important/trash, text search, detail/read state, compose, reply, recipient selection/search, starring, trash/restore and attachments. `MailSend`, `MailReply`, `starMessage`, `restoreMessage`, `uploadFile`, `sendMessage`, `fetchTrash` and related errors corroborate these candidates. No exact multipart field names, file restrictions, send/reply payload, recipient ID encoding or optimistic update behavior is recovered.

The app contains explicit strings for “message sent WITHOUT … attachments” and failed file uploads. The integration must preserve partial success: a successfully sent body with failed attachments is not a fully successful message. Reconcile the sent-message record before offering retry to avoid duplicate messages.

## Homework endpoints, media and uploads

`/api/homeworks/datatable` (`0x955340`) and `/api/homeworks/` (`0x8fe600`) are endpoint candidates. `homework-module`, `homeworks-module` and `homework-status` also occur, so a single hard-coded backend route is unlikely to cover all sources. Recover module discovery from the gateway/envelope and session setup before implementing the compatibility branches.

Homework flows include send answer (`sendAnswer`, `postAnswer`), upload solution file (`uploadSolutionFile`), teacher comments/solution status, archive/restore (`setArchived`, `toggleArchive`) and expired attachment URLs. A shipped diagnostic explicitly says the app refreshes homework details when an attachment address has expired. Store attachment identity separately from its short-lived URL.

The package has `AttachmentPicker`, `PickedFile`, `UploadRetry`, camera/gallery logs, file picker, share, HTML/media factories and an app-specific `YoutubeEmbed`. Combined renderer factory names include cached images, Chewie/video, JustAudio, SVG, URL launcher and webview. This supports a renderer capability inference; it does not prove every media format, an audio-recording workflow or arbitrary web content permissions. Validate HTML sanitization, file sizes/extensions/count, permission denial, cancellation, playback and safe external link handling with actual content.

## Notifications, offline behavior and settings

The app has `FcmService`, `FcmInvalidation`, notification preferences/center, cache invalidation, deep-link routing, per-account token refresh/registration and account-mismatch rejection. Gateway literals include `register-fcm`, `unregister-fcm`, `notif-settings`. Local channels include messages/marks/absences/reprimands/timetables. Logs describe re-registering all accounts on token refresh, skipping notifications for an account not present on the phone and refreshing the open view after a notification. Exact remote payload and registration/preference body are still unknown for this generation.

The binary contains a SQLite `cache_entries` declaration with `cache_key`, `kind`, `pupil_id`, `params`, date bounds, `payload`, `fetched_at`, `fresh_until`, `retain_until`, `protocol_v` plus kind/pupil and retention indexes. App-specific logs describe fresh cache hits, stale fallback, GC, in-flight deduplication, targeted invalidation, cache clearing per account or globally, and rejecting late homework responses after context changes. These provide specific failure/race scenarios for tests. Key data by account as well as pupil; the cache table's `pupil_id` column alone does not establish its complete logical key.

Settings candidates include color skins (standard/pastel/amethyst), font-size scaling, high-contrast/WCAG mode, dashboard history weeks and attendance mode, notification settings, clear cache, version stamp `3.1.7 (build116, d20dd8d)`, help link and store-update flow. Shipped developer-mode and TTL diagnostic strings should be recorded, but user reachability has not been proved. Siberia should expose its own appropriate diagnostics rather than cloning vendor internals.

`UpdateRequiredScreen` and Polish text say the app version can become incompatible with the diary server; protocol version mismatches must become an explicit “update required” state. Do not clear the prior valid cache or continue mapping an unknown schema as if it were current.

## Next native/runtime investigation

1. Trace `AuthService` and its endpoint literal xrefs. Recover method/body encoding and success/error envelopes for password, refresh and QR. Record source offset/address and decompiler/provider identity.
2. Trace `AppApi`/`ApiEnvelope` to recover operation selector, bearer scheme, pupil/term/range parameters, protocol negotiation and module URLs.
3. Trace SSO to mail and homework/module origins. Capture redirection and cookie names/flags without retaining credential values in public files.
4. Recover one read fixture for each repository and each homework source. Confirm pagination, date boundaries, empty lists, status/error envelopes and role constraints.
5. Recover mutations individually: mark read; send/reply/star/trash/restore; file upload; homework answer/archive; justification create/edit/delete; announcement answer; notification prefs/register/unregister. Document verb, URL, exact body, optimistic state, response, partial failure and safe retry condition.
6. Exercise student, parent, multiple-school and multiple-child contexts. Validate access and cache separation, expired JWT/refresh/cookie, offline starts, late async responses and required polls.
7. Reconcile the resulting contracts back into all feature records. A record remains `candidate` until its exact contract is evidenced; do not downgrade unresolved newer features to “not supported by MobiReg.”
