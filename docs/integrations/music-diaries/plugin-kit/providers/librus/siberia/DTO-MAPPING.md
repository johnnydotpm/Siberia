# DTO and UI mapping for extending Librus

Source baseline is current main `fdd022da1759caf254873fbb6d8ffdea7e360b68`. Tables below distinguish **existing Siberia parser fields** from future additive representations. They are not claims that the official packages use the same transport/field spelling. Read their version-scoped contracts first; a field with a similar name is not an automatic alias.

## Identity and provenance

| Existing source | Current destination | Keep / extend |
|---|---|---|
| Portal email/password/access/refresh | `LibrusLogin`, secure map `syberia_portal_accounts_v2` | Owner-level material, shared by sibling profiles. Never put cookies/API child tokens in this record without service and scope labels. |
| Portal linked account login/studentName/group | `LinkedSynergiaAccount` → `SchoolProfile.account/synergiaLogin/name/parent` | Keep actual remote login distinct from local account hash, local immutable profile ID and API Me IDs. Group/role should feed capability policy, not merely labels. |
| API Me Account/User IDs | `StudentProfile.id` string `librus-{id}` | This is display/data identity inside a profile; it is not the durable `SchoolProfile.id`. Preserve both through migration and cache lookups. |
| Aggregate source | `source` and `profileId|localId` in `domain/together.dart` | New DTOs require `withSource`, copy, serialization and `localId` routing. Only local ID goes on wire. Include per-source errors/permissions in an aggregate screen. |
| School year/semester | Grade/Attendance int semester; no explicit snapshot period object | Add typed academic year/term identity where recovered. Do not overload Portal owner or rename every profile for a semester switch. Preserve old snapshot format with defaults. |

The official app may keep account entitlement/feature metadata. Add a capability DTO scoped to owner + Synergia account and return enabled/denied/unavailable/unverified reasons; a button should not be enabled because its route string exists. Current `SchoolProfile` assumes Librus and has no provider enum/server field. For further diary work evolve this additively rather than deleting established multi-profile behavior.

## Existing core projections

| Source/parser | Existing mapping | Lost or transformed; proposed addition |
|---|---|---|
| Timetable day key, HourFrom/HourTo | Lesson.start/end | Original school date/time zone grammar lost after parse. Preserve source date + original timestamps for round-trip/DST diagnostics; no fake45minute duration. |
| Subject/Teacher/Classroom reference IDs | Display `subject/teacher/room` strings | Keep raw IDs in provider DTO; string names are unsuitable join keys. Multiple teacher/group/lesson IDs need collections if official data supports them. |
| IsCanceled/IsSubstitutionClass, OrgSubject/OrgTeacher/OrgClassroom, NewDate/NewHourFrom | Lesson.cancelled/substitution/original*/movedTo | Preserve full source substitution metadata and reason; `movedTo` is derived only for a substitution that is cancelled and has new date. Do not turn a moved original lesson into a duplicate present event. |
| Day + LessonNo or start epoch | Synthesized Lesson.id | Two events in one slot may collide. Prefer proven stable server ID, otherwise scoped composite of source identity fields; document fallback. |
| Grade/Category/Subject/Semester/AddDate/Comments | Grade.value, category, subject, semester, date, description; category weight | Existing weight is category weight, missing defaults0; absent semester defaults1. Add source grade type, color/importance/count-to-average/period-assessment attributes if observed. Display numeric and descriptive values without zero coercion. |
| Improvement reference | Grade.previousGrades chain | Retain cycle/dangling handling and source IDs; official change history may differ from an improvement chain. Do not equate every historical version with replacement. |
| HomeWorks Content/Date/Category/LessonNo | SchoolEvent(kind:exam) | Existing source maps every item as exam; future adapter should preserve actual category/type and decide normalized EventKind explicitly. |
| HomeWorkAssignments Topic/Text/DueDate/Subject/Lesson | SchoolEvent(kind:homework) | No attachments, teacher, assignment start, submission state, solution or upload metadata. Add typed `HomeworkDetails` with source data rather than stuffing JSON into description. Local HomeworkDoneStore remains a private completion mark, not server submission. |
| Attendances Date/LessonNo/Lesson/Type/Semester | AttendanceRecord; type joined via reference IDs, fallback embedded | Keep raw status/type IDs and source standard ID. Existing `_attendanceKind` uses standard IDs plus name heuristics; unknown must remain other. Parent justification/request record needs a separate model, not rewriting official attendance locally. |
| SchoolNotices Subject/Content/AddedBy/CreationDate/StartDate/EndDate/WasRead | SchoolAnnouncement title/plain content/author/date/range/read | Rich text and source-author ID discarded; no explicit read acknowledgement call. Add HTML/text dual form and confirmed read state if supported. |
| Notes Text/Category/Teacher/Date/Positive | StudentNotice tone;0negative/1positive/other neutral | Preserve raw positivity/category and author IDs; don't infer behavior grade from notice tone. |
| SchoolFreeDays/ClassFreeDays/TeacherFreeDays + types | FreeDay kind/from/to, optional lesson/time bounds | Current rendering useful; retain inclusive range semantics and profile source. Calendar-day helpers already exist on main—avoid fixed24hour day arithmetic at DST. |

## Mail source differences and additive schema

Current `SchoolMessage` is a summary: id,sender,subject,preview,receivedAt,unread,hasAttachments,sent,recipient display list,optional aggregate recipientRead,source. `SchoolMessageContent` holds plain body, attachments(id,name) and recipient name/read/readAt. MessageRecipient ID is int and group String.

| Needed dimension | Existing behavior | Future data/UI consequence |
|---|---|---|
| Folder, pagination and archive | UI only inbox/sent; XML archive0; API limit50page1 | Add folder identity + page/cursor outcome + hasMore/complete metadata per source. Keep loaded partial history labeled. Avoid treating archive IDs as current-folder IDs. |
| Sender/recipient identity | Mostly display names; compose IDs int | Preserve opaque provider recipient key, type and group/list identity in provider DTO. Normalize only at the exact transport boundary; don't silently parse string IDs to0. |
| Read receipts | Optional bool plus date per name | Add source-recipient ID and separate unknown/unread/read; a malformed date is not a reliable unread signal. Deduplicate repeated recipient entries using actual identity. |
| Body | Base64 decoded then `_plainText` | Keep sanitized HTML alongside derived text; disable active content, route links intentionally, preserve line breaks/Unicode. Plain previews can still drive search. |
| File metadata | Attachment ID/name only | Add MIME/size/download mode/expiry/source URI only if observed, and an upload model distinct from existing downloaded attachment. Never persist signed URL tokens in diagnostic snapshots. |
| Reply/forward | Compose only recipient IDs/subject/body; no context | Add explicit action/context model only where recovered. Prefilling Re: or copying text is a local UI convenience, not server-thread reply semantics. |
| Send outcome | New ID required, then local sent summary | Model confirmed/uncertain/failed and per-file statuses for future uploads. A timeout after request bytes may have created the message; do not automatically resend. |
| Delete/trash/restore/draft | No client method or current UI | Add per-operation capability and effect metadata. Do not map mail deletion to removing a local summary alone. Unknown remote mutation must stay gated. |

## Error and cache changes

`AppSnapshot.messagesError` is the only dedicated per-module failure slot; its `copyWith` cannot replace grades/attendance/announcements/notices or clear a non-null message error. A future modular snapshot needs typed module outcomes or explicit additive fields, a complete copy/merge method and source-level aggregate errors. Preserve old JSON decode defaults.

DTO construction should not silently turn absent identity/date into `hashCode`/now for newly recovered models. Distinguish malformed required field, optional unknown value and a deliberately synthesized local identity. Keep source enums and enum-unknown values even when the UI projects them to a simple kind. Test required-null, missing optional, explicit-null, numeric-string and collection alias branches independently.

Existing UI anchors: `ui/shell/grades.dart`, `attendance.dart`, `events_homework.dart`, `announcements_notices.dart`, `messages.dart`, `message_compose.dart`, `account.dart`, `onboarding_sign_in.dart`, `together.dart`; translations remain in `l10n/app_localizations.dart`. New protocol names should not appear directly in user-facing copy unless they help identify an account or resolve an error.

## Concrete differences recovered from the supplied official iOS package

The neighboring [official operation catalogue](../operations.json) records function IDs, exact request expressions and source hashes. These differences are now supported by shipped source-map evidence; acceptance and role entitlements remain untested.

| Official boundary | Existing Siberia surface | Required integration decision |
|---|---|---|
| Main diary base API3.0; Synergia gateway /gateway/ms | Current diary reads use API2.0 | Treat service version as explicit. Compare DTO/envelope/query differences per operation before migrating; a global string replacement of2.0to3.0 is unsafe. |
| API mail lists limit300,page1 and loop until short, afterId | API inbox limit50,page1 only; XML/HTML fallback | Add explicit complete/page/source metadata and recovery cursor. Preserve unread distinctions and existing fallbacks where compatible. |
| API message GET detail and PUT `{action:delete\|pin\|unpin}`, POST creation | XML detail/send; no pin/delete API/UI | Introduce typed action command and per-message pinned/folder fields, with operation-specific retry. GET detail side effects require trace before retry policy. |
| API attachment metadata and file flows | IDs/names and external download landing URI | Preserve metadata + source auth/download mode; do not attach mailbox cookies to arbitrary file host. |
| Homework `MarkAsRead` / `MarkAsDone` POST `{homework:id}` | Local done marks only | Distinguish server read, server done and private local checkmark. Show pending/confirmed/failed server state; migration must not upload historical local marks automatically. |
| Homework AnswerAttachment/{id}, multipart field `attachedFile` | No homework upload method or type | Add solution/answer attachment DTO and explicit send action; retain confirmed attachment ID and partial outcomes. |
| Justifications POST plus attachment and availability | Attendance reads only | Add eligibility/capability, justification request/status and attachment relationships; do not directly mutate attendance kind. |
| School ID/photo | No typed module | Add credential-independent photo/document retrieval policy and offline retention choice. Static route presence is not school activation proof. |
| Meals, GO documents/payments, absence/catch-up services | No typed modules/UI | Add bounded separate modules only under configured role/entitlement; keep money/documents/date state typed. Do not map payments into a generic event or trigger transactions while testing reads. |
| Personal schedule / mobile-addons owner | No dedicated external-service session | Keep Portal/personal-schedule origins and credentials separate from diary3.0 and mailbox. Add capability-specific schedule/goal DTOs instead of conflating school-set timetable and personal entries. |

Use the catalogue's **function name + source path + operation ID** when assigning future tasks. It contains generic imported helper calls and unresolved expression values as well as concrete operations; total record count is not a claim that every route is enabled for every user.
