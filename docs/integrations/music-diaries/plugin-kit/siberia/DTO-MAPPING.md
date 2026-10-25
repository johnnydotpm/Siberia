# Provider DTO → Siberia mapping and additive fields

This is a mapping **specification** for future independent code. Provider fields below are decoder-owned observations from the deep reports, not sample student data. Optionality/coercions remain those of the corresponding decoder; this table does not declare all fields mandatory. Wire IDs stay opaque unless a request contract explicitly requires a numeric JSON value. Never map by array position or by neighboring strings.

## Identity, scope and dates

The proposed parent `DESIGN.md` vocabulary is `AuthOwner(provider, authority, tenant, account)` and `DataScope(owner, pupil, period)`. These identify credentials/refresh coordination and selected school data respectively. The descriptive aliases server/accountId/tenantId/pupilId/academicPeriodId elsewhere in this source mapping denote those same concepts, not a second required public interface. New data context must retain provider, legitimate normalized server, tenant/school, login owner, selected pupil and academic period separately.

| Source | Current host destination | Additive representation / rule | Loss if using current shape alone |
|---|---|---|---|
| Fry User `id,role,first_name,last_name,students` | `StudentProfile.id/name/school/provider` | Store User identity+role under auth owner; selected child's ID belongs to DataScope. Decode `students` recursively through `User.fromJson` (closure0x6183b4 →0x6183ec); preserve nested roles/identity and validate optionality against provider response-field ledger; school label is separate from discovery URL. | A parent would become its child; role/child list lost; no secure scope isolation. |
| Modern MobiReg account page/school/login, selected `Pupil` | Same | `server` authority/path normalization is validated; `tenantId` school code; account ID and pupil distinct. Password/QR auth type+token family owner-scoped. | Identical pupil/login IDs at different schools collide. |
| Legacy MobiReg parent login/digest, ParentStudents IDs/local DB row IDs | Same | Keep remote pupil ID separately from local database row ID; parent digest is secure password-equivalent material, never a displayed profile field. | A local row ID could be sent to server; digest could leak into snapshot. |
| Fry lesson dates + absence `yyyy-MM-dd HH:mm:ss`; modern gateway `dateFrom/dateTo`; legacy lmt grammar | `DateTime` fields | Parse date-only values as school dates, local timestamp strings with an explicit school zone policy, instants as instants. Preserve raw format/provenance when unresolved. Modern `DateHelper.toIso` produces Y-MM-DD; legacy response T grammar differs from cursor space grammar. | Device timezone and DST shift lessons/due dates; invalid delta cursor. |

Do not derive every term from integer semester 1/2. Add `AcademicPeriod{id,parentId,label,isYear,startDate,endDate,sourceType}`. Modern terms read `id,parentId,label,isYear,dateFrom,dateTo`; Fry overview semesters read `name,start,end`. A period selected locally is not necessarily a credential boundary.

## Timetable and lesson details

Current `Lesson` can hold one subject/teacher/room, start/end, cancellation/substitution, original strings, movedTo and optional lesson number. Reuse its projection for Today/widget timing while retaining a typed lesson-detail module.

| Source DTO fields | Current mapping | Required additions and invariant |
|---|---|---|
| Fry Lesson `name,short_name,original_name,original_short_name,start,end,room,color` | subject/name; room/start/end; subjectShortName via display metadata | Stable source ID if supplied; otherwise a documented deterministic composite including scope/time/type, not mutable display text alone. Keep full/short/original/color separately. |
| Fry `primary_description,secondary_description,is_remote,remote_link` | No faithful current field | `LessonDetails` descriptions, remote URI+kind and safe open policy. Descriptions aren't school events by themselves. |
| Fry `teachers[{id,full_name}]` | joined teacher string for current card | `List<TeacherRef>` with opaque IDs and names; joined projection is display-only. |
| Fry `exams[{description,start,end}]`, `accompaniments[{subject,accompanist,start,end}]` | No faithful current field | Typed nested `LessonExam`/`Accompaniment`, with its own interval and teacher/subject. Do not flatten into duplicate class periods or inflate attendance denominator. |
| Fry `absence_type,is_substitution,substitution_type,absence_type_change_request` | broad AttendanceKind and cancelled/substitution bool where evidenced | Preserve raw code and linked request. Substitution **custom code**1 canceled,2 replaced,3 ignored,4 inCommonRoom,5 lookAfter; enum ordinal is different. Undefined code keeps raw label and unknown normalized state. |
| Modern MobiReg `id,dateTimeFrom/startTime,dateTimeTo/endTime,subjectName,room/roomName,title/content/topic` | Lesson id/start/end/subject/room | `topic`, raw type, source event ID, actual duration. Do not invent 45-minute periods or require lessonNumber. |
| Modern `teachers,tests,isLocked,isCanceled,substitution,oldSubjectName,oldTeachers` | teacher display; cancelled/substitution/originalSubject/originalTeacher | Teacher collections, embedded test refs, lock/status metadata, original teacher IDs. Differentiate cancellation vs locked/unchecked. |
| Modern `attendanceLabel,attendanceSymbol,attendanceName,attendanceUnchecked,bgColor/attendanceColor` | no lossless current destination | Per-event attendance display/status/color with provider code. Keep unknown/unrecorded distinct from absent. |
| Legacy Events/Teachers/Subjects/Rooms/groups and event relation tables | projection after joining import mappings | Keep imported IDs, group/event relationship and original/substitution join in scoped module store. Use documented field-mapping JSON rather than SQLite column guesses. |

Test individual and group sessions of arbitrary length, overlap, accompaniment inside a lesson, teacher collections, missing period numbers, weekend music classes, remote lesson links, moved/cancelled events and school date boundaries. `home_widget.dart` only receives actual projected periods; it must not include one cancelled event or double count nested exam/accompaniment children.

## Grades, averages and exam/period assessment

Current `Grade` mandates string value, double weight, int semester, date, category, description and history. Its calculator assumes numeric school marks. Add optional grading metadata without turning nonnumeric marks into zero.

| Source DTO fields | Existing projection | Additive fields / preservation |
|---|---|---|
| Fry Grade `text_value,numeric_value,weight,name,comment,created,subject_*` | value chooses verified display text; subject/date/description; weight only when meaningful | Raw text and numeric value separately; optional weight, grading scheme, subjectRef/color/shortName, teacher if supplied, periodRef. `text_value` precedence must follow decoder branch, not blanket `toString()`. |
| Fry overview subject `predicted_grade,final_grade,grades` under semesters | grades list lacks classification slot | Typed `PeriodAssessment{periodId,subjectId,kind:predicted/final/current,rawValue,...}` separate from ordinary grade. Do not insert final grade into weighted-average input. |
| Modern Mark `id,subjectId,value,weight,date,description,kindLabel,comments/comment,bgColor/color` | existing basics | Native grade scheme, optional numeric interpretation, raw color/category, source teacher/subject IDs. |
| Modern `count_to_avg/countToAvg,markGroupId` and markGroups parent/subject IDs | previousGrades/history only partly fits | Explicit `countsTowardAverage` tri-state and group/correction graph. A group parent is not automatically a replaced grade. Preserve raw graph until verified semantic mapping. |
| Modern TermMark `isFinal/is_final,isProposal/is_proposal,value/val,mtTeacherId/teacherId` | no faithful current Grade.kind/period | Typed period assessments, marker/teacherRef and raw flags. Preserve proposal and final independently. |
| Modern subject `avg1,avg2`, `suggestView` | current locally computed average | `ServerAverage{kind,displayValue,numericValue?,precision?,periodId}`; don't overwrite with locally rounded average. Label source/server average vs local estimate. |
| Legacy four grading types + numeric scales/categories/visibility/corrections | Grade basics | `gradingKind` scale/points/percentage/description, scale bounds, published visibility, average exclusion and correction refs from mapping classes. No teacher-write API from export-class presence. |

Migration default for existing Librus numeric weight/semester behavior stays unchanged. For new providers, prefer optional weight/period rather than inventing weight1 or semester1 to appease current constructors. An interim projection may use a compatibility value only with explicit `unknown` metadata and disabled incorrect calculations. Current `GradeAverageSettings` and `grade_calculator.dart` must gate numeric interpretation by grading scheme; all changes need existing average/calculator regressions.

Exams are typed `Exam{id,source,subjectRef,teacherRefs,title,description,typeLabel,date,start,end,createdAt}`. Modern `tests` response has `teachers` and `items`, while embedded timetable tests have `testId,testType,testLabel/content`. Link them when stable IDs match; retain standalone exams even if there is no matching lesson. A `SchoolEvent(kind:exam)` projection enables Today/reminders but cannot replace detailed test/source metadata.

## Attendance and justification workflow

Current `AttendanceRecord` is an individual record with one date/period/subject/kind/semester; current aggregate `absences` counts raw normalized records. That is insufficient for provider percentages or pending requests.

| Source | Shared projection | Required module model |
|---|---|---|
| Fry overview `year/months`, period `firstDayOfPeriod,lastDayOfPeriod,attendancePercentage,lessonsWithExplainedCount,lessonsWithExcusedCount,lessonsWithLateCount` | display alongside chart | `AttendanceSummary` with provider numerator/denominator counts, range, raw statuses and server percentage. Explained/excused overlap semantics remain fixture gate; do not sum them blindly. |
| Fry AbsenceType custom code | broad kind only if meaning verified | Raw code0unknown,1present,2absence,3explainedAbsence,4notExcused,5late,6outEarlier,7otherPresent,8otherAbsence. `explained` is not proof of approved excuse. |
| Fry lessonsWithAbsence, change request attached to lesson | record/context link | Provider lesson ID/range/type/reason/request/status; keep raw type label. |
| Modern `records` short keys `ca,d,sid,ab,tn`, subjects/terms dictionaries | date/subject/raw symbol + cautiously normalized kind | Preserve all short-key DTO values; do not guess `tn` or `ca` semantics beyond recovered decoder. Period dictionary remains source-owned. |
| Modern JustificationRecord `id,created_at,message,period_from,period_to,event_count,status,events` | no existing lossless model | `JustificationRecord` typed module, numeric raw status (unknown meanings retained), count and included events. |
| Modern event refs `event_id,day,subject,time_from,time_to,attendance_type,absence_code,applied_status` | lesson link, optional attendance display | Distinguish requested status from applied official status; no local direct attendance edit. |
| Modern eligible event `ab,st,end,sub,js,attendance_type` nested date→eventId maps | no existing form model | `JustificationCandidate` with stable eventID/date/interval/eligibility/raw status. Key string is parsed into numeric event ID for this API. |

Request model proposal: `JustificationDraft{scope,recordId?,eventIds,reason,start?,end?,providerRequestedType?}`; adapter creates provider-specific body. Fry POST includes optional `id` even null, integer student_id, start/end formatted `yyyy-MM-dd HH:mm:ss`, absence_type **3** and reason. Modern create POST JSON `{pupil_id,message,event_ids}`, update PUT `{message,event_ids}`, delete DELETE path. These are distinct contracts; do not use one shared JSON encoder. Keep eligible lesson selection, contiguous Fry constraints and server approval/denial/status visible. Lack of numeric status meaning is an explicit remaining test gate.

## Homework, files, completion and submission

Current `SchoolEvent(kind:homework)` holds only title/subject/date/description. Retain it as a calendar projection backed by typed `HomeworkTask`, `HomeworkDetail`, `HomeworkSolution`, `HomeworkFile` and `SubmissionResult`.

| Source DTO | Projection | Additional model |
|---|---|---|
| Fry `id,subject,publish_date,finish_date,teacher,content,attachments`; attachment `name,url` | title/subject/deadline/description | Origin-qualified task identity, publication date, rich HTML/content format, teacherRef, file refs. Submission-status display exists but **no Fry task-write path is established**. |
| Modern diary `dateTime,addedTime,id,subjectId,subjectName,title,description,teacherId` | current SchoolEvent fields | `HomeworkSource.diary`, subject/teacher dictionary refs, actual publish/due times. |
| Modern module `deadline_at,studentIds,teacher_comments,statuses,id,subject,title,created_at,student,status,archived` | common display fields | `HomeworkSource.module`, per-pupil status, archive flag, raw deadline, teacher feedback. Same numeric ID from diary/module must not collide. |
| Modern detail `teacher_comments,teacher,content,groups,files,status,solution` | no faithful current detail | Rich detail + audience groups + typed solution. |
| Modern solution `content,sent_at,files`; file `id,name,extension,url,size,sender` | none | Separate draft, uploaded files, server acknowledged submission, feedback and archive state. Keep short-lived URL out of persisted long-term identity. |

Modern MobiReg solution PATCH `{content,files,student}` and multipart `files` with text `student` are recovered. The exact **files JSON structure** and file policy remain open; do not pass arbitrary picked-file paths as the wire structure. Archive is PATCH with `{}` and is a toggle; repeated retries may reverse state. The UI should show requested/confirmed archive state and refresh on uncertain outcome.

Local `HomeworkDoneStore` is a personal checkbox and stays separate from `submissionStatus`, `accepted`, `sent_at`, archive and server task read status. A local done mark may suppress local reminders; it must never pretend an answer was uploaded. Fry unknown submission write remains disabled while its status/detail still works.

## Mailbox and attachments

Current `SchoolMessage` is a list item; `SchoolMessageContent` has body, attachment ID/name and recipients with optional receipts; `MessageRecipient.id` is int. Add a mailbox module with provider folder IDs, paging/search state, draft/action context and explicit partial mutation results.

| Source | Shared projection | Additions and fidelity constraints |
|---|---|---|
| Fry Message `id,subject,content,sent_date,sender,is_read,is_replied,is_deleted,tags,attachments` | subject/body/date/unread/hasAttachments | Body contentFormat, replied/deleted/tag state and raw folder/source; do not infer restore/permanent-delete from deleted flag. |
| Fry recipient responses `recipients_v2,cc_recipients_v2,bcc_recipients_v2` objects `{key,name,role}` | names for display | Opaque recipient `remoteId`, role, to/cc/bcc category. **Send keys lack `_v2`**: recipients/cc_recipients/bcc_recipients. Keep BCC private in reply/forward. |
| Modern MailMessage `id,subject,content,author,recipients,files,date,read_at,stared,trashed,previous` | basic list/content | Folder/important/trash, previous/thread context, remote read timestamp and author/recipient details. Send uses **title**, response reads **subject**. |
| Modern MailRecipient `id,name,role,_type` | opaque recipient required | Numeric normalized identifier gains `user_`; retain nonnumeric values. Never parse all IDs as int. |
| Modern folder `items,total` | messages list | `PageResult{items,total?,nextOffset?,completeRange}` and per-query folder state. Folder body limit20,skip offset,optional query; empty results don't erase another folder/query. |
| Fry attachment `{id,name,url}`, modern `{id,name,size,url,extension}` | old ID/name only | MIME/extension/size if supplied, URL auth policy, expiration/renewal and download-state identity. Do not persist auth-bearing URL as a public link. |

Three transport models must remain distinct: Fry upload-before-send yields attachment IDs used in create; modern MobiReg send returns messageID before multipart post-send files; modern MobiReg homework upload/save is a separate cookie module. Proposed mutation result captures `notSent`, `confirmedSent`, `bodySentWithFailedAttachments`, `uncertain`, with serverID and per-file outcomes. Do not throw away serverID when a file fails.

Current `openAttachment` external URL launcher is insufficient for cookie-protected mail. App download service owns cookies/redirect rules and temp files, then hands a safe local file to open/share. MobiReg homework attachment getter supplies no explicit cookie map and may renew detail after401/403; don't add every available token. A unified attachment abstraction must explicitly select authorization mode per operation.

## Announcements, polls and remarks

Current `SchoolAnnouncement` holds title/content/author/date/validUntil/read. Add typed provider detail/poll state rather than embedding JSON in content. Modern announcement reader consumes `read/xread,answers,userAnswer,valid,id,type,kind,title,dateTime,author,login,content,declined,pollOpen,pending`. Preserve unknown types and missing values. Its `_flag` decoder accepts multiple scalar representations; the poll mutation success path instead compares literal true, so response normalization must be operation-specific.

Proposed `AnnouncementPoll{options,answer?,declined,pending,pollOpen,canAnswer?,rawType}` links to detail. Do not use inferred `canAnswer=true` when source lacks it. `announcement-answer` is a **gateway POST form operation**, with id string and either answer string or decline string1. It requires decoded data.success true and reads userAnswer/declined/pendingCount. Detail fetch may acknowledge read; no standalone endpoint is invented. Required pending gate should offer the server-supported user choices, not automatically skip or answer.

Modern reprimands/praise map to `StudentNotice` only with raw kind/status/teacher preserved. Existing positive/neutral/negative tone is a display normalization, not permission or official status. Legacy teacher-oriented export classes remain library evidence only; do not surface grade/attendance editing merely because a shared library declared export mappings.

## New model acceptance tests

- Round-trip every additive optional field while decoding old cache JSON unchanged.
- Same id in two provider/tenant/child/source/period contexts never aliases; one shared auth owner refreshes once across child scopes.
- Text mark and unknown weight do not enter numeric average; proposed/final results stay separate; server average preserved.
- Nested accompaniment/exams don't duplicate lesson count; actual session durations reach widgets.
- Pending justification remains pending until server state; optimistic local message read retains unconfirmed acknowledgement status.
- Local done, solution sent, teacher accepted and archived are independent states.
- To/CC/BCC and opaque IDs survive draft/reply round trips; partial send retains confirmed messageID.
- Missing module/cookie failure preserves other modules and server origin credentials remain compartmentalized.

These checks require independently authored synthetic fixtures first and then authorized role/server fixtures. They are acceptance instructions, not tests executed by this documentation kit.
