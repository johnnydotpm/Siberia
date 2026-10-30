# Raw responses, local viewmodels and lossless integration

All observations are static from the supplied iOS8.4.1 build6487 source maps. Original modules are identified by `src/...` below. Exact hash, source-map index and function line are in [builder-consumer-index.json](builder-consumer-index.json); local declaration defaults and relationships are in [model-fields.json](model-fields.json). The proposed Siberia representations are design recommendations, not existing classes.

## Identity and value preservation

Most Synergia viewmodels have composite primary key `(SynergiaAccountId, Id)`. Timetables additionally include `start`. LibrusGO viewmodels use `(LibrusGoAccountId, Id)`. These are separate account families even when display names or numeric IDs match. A Portal identity can own several Synergia/LibrusGO connections. Namespace local storage, attachment caches and notification identity by provider+authority+account family+connected account+period where relevant; never flatten them into one global integer ID.

`attr` means an untyped client attribute. `string`, `number` and `boolean` describe Vuex-ORM declaration/coercion choices. They are not proof of a strict JSON cast at the network boundary. Null defaults are local initial values. `IsNew`, `Deleted`, `IsPinned` and dirty state may derive from local changes or server data depending on the module; maintain a separate raw DTO and an explicit provenance flag.

Several source classes reuse the name `Grades` for different entities. Use `model_key` (source path) plus entity, never class name alone, to identify a schema in the reference JSON. Role helper `src/helpers/user-utils.js` identifies student as numeric8 or string`student`; kindergarten family includes13/14/15 or the corresponding `kindergartener_parent`/`kindergartener`/`kindergartener_guardian` strings. The display-name helper also labels some roles differently from the student-permission helper. Treat these as per-helper observed logic, not a universal authorization matrix.

The following table covers primary wire-to-view rules. “Required by builder” means the observed code dereferences it without a guard, not that a formal server schema guarantees it. Do not make every such branch a crashing requirement in Siberia.

## Standard grades

Evidence: `src/api/view-builders/grades-builder.js`, `getGradesViewModel`, `getCommentsForGrade`, `getSubjectGradeContainer`; declarations `src/viewmodels/grades.js`, `averages.js`, `subjects.js`, `grade-comments.js`.

| Raw field / joined entity | Original local field | Observed transform / absent behavior | Proposed preservation |
|---|---|---|---|
| grade `Id` | `Id` | Direct | Opaque provider ID scoped by account and grade family |
| `Subject.Id` + subject lookup | `SubjectId`, `SubjectName` | Name gets `[OO]` suffix when subject has `DescriptiveGradeCategory` | Keep raw subject name and category separately; suffix is presentation only |
| `AddedBy.Id` + user lookup | `Teacher` | Uses username helper | Preserve teacher ID and optional name; missing lookup must not erase grade |
| `Category.Id` + category lookup | `Category` | Missing category uses `Nieznana` | Preserve category ID and unknown label state |
| category `Weight`, `CountToTheAverage` | same | Missing category yields undefined for each | Optional weight and inclusion flag, rather than defaulting to1 or false |
| category final/semestral flags | `IsFinal`, `IsFinalProposition`, `IsSemestral`, `IsSemestralProposition` | Optional chained reads | Distinct assessment type enum plus raw flags |
| `Grade` | `Grade` | Direct, no universal numeric conversion | Preserve display value and separately optional parsed numeric value |
| `Text` | `Description` | Direct | Preserve comment/description independently from grade label |
| `Date`, `AddDate`, `Semester` | same | Direct | Date meaning/unit remains response-specific; do not infer one universal epoch/timezone |
| `Comments[].Id` + comment endpoints | `Comments` relationship | Comment stores `Id`, `GradeId`, `GradeType='Grade'`, `Text`, user display and account | Namespace comment by grade type+account; preserve author ID |
| `Resit.Id` | `ImproveId`, `Improvements` | Follow linked grades recursively | Keep graph links and original records; detect cycles/missing nodes |
| averages `Semester1`, `Semester2`, `FullYear` | average `Value`, `Period`, `IsFullYear` | Standard builder uses periods1,2,and string`'0'`; creates zero averages when missing subject entry | Preserve unknown/unavailable averages instead of presenting invented numeric zero |

The builder joins subjects/users/categories/averages/comments. A flat grades endpoint wrapper without these lookups cannot reproduce labels, weights, inclusion rules or history. Standard grade resit recursion is not a safe generic graph traversal: add visited IDs and a depth bound. Subject containers may still exist when grade list is empty; do not lose subjects by only grouping nonempty grade records.

### Other grading families

The package has separate standard, point, text, descriptive, descriptive-text, partial descriptive and behaviour families. Preserve family in every ID and dispatch decision. Their declarations are included in MODEL-FIELDS; their consumers are separate builder modules:

| Family | Builder | Integration rule |
|---|---|---|
| Point | `point-grades-builder.js` | Uses point-specific averages, categories, comments and resit chains. Semester average null is displayed as0 by original builder; retain availability separately. Do not calculate on school mark scale1–6. |
| Text | `text-grades-builder.js` | Raw `Grade` retained as full `Description`; abbreviated `Grade` generated by helper. Preserve both, never reduce full text to the abbreviation. |
| Descriptive | `descriptive-grades-builder.js` | Subject/category/skill and comment relationships require their own model family; preserve nested content. |
| Descriptive text | `descriptive-grades-text-builder.js`, `descriptive-text-grades-builder.js` | These similarly named paths are not interchangeable. Keep original endpoint/model family and per-skill assessment content. |
| Partial descriptive | `partial-descriptive-grades-builder.js` | Joins lesson assignment/skill context; expose explanatory detail rather than numeric substitution. |
| Behaviour | `behaviour-grades-builder.js`, `behaviour-grades-point-builder.js`, `behaviour-grades-system-proposal-builder.js` | Separate behaviour types, point categories and system proposal; account-wide rather than ordinary subject average. Original point container uses synthetic `Id='ZZ'`, `Name='Zachowanie'`; do not send this presentation ID to server. |
| LibrusGO activity grades | `grades-librus-go-builder.js` | Groups by active activity group and raw `grade.activityGroup.id`; preserve group/activity identity. Do not merge into Synergia grade IDs. |

## Attendance

Evidence: `attendances-builder.js` functions `getViewModel`, `getAttendancesViewModelById`; declaration `src/viewmodels/attendances.js`.

| Raw / join | Local field | Rule |
|---|---|---|
| `Id` | `Id` | Local model declares string defaultnull |
| `LessonNo` | `Lesson` | Local field is lesson number/display, **not** remote `Lesson.Id` |
| `Lesson.Id` → lesson `Subject.Id` → subject | `Subject` | Preserve remote lesson+subject IDs in DTO even though presentation discards them |
| `Type.Id` → attendance type | `TypeId`, `Type`, `ShortType` | Type display and code are separate |
| custom type `StandardType.Id` → standard type | `StandardType`, `StandardShortType` | Normalize through standard mapping rather than hardcoding custom IDs |
| type100 | not shown | List filters numeric100; detail checks string`'100'` for standard type. Treat this inconsistency as fixture requirement, not authorization to conflate every string/number field |
| `Comment` | `Comment` | Falsy comment becomesnull in builder |
| `Date`, `AddDate`, `Semester` | same | Local semester defaults1; raw presence/type must be tracked independently |
| `AddedBy.Id` + users | `AddedBy` | Presentation name only; retain raw author ref |

Preserve unknown, not recorded and actual absence separately. A custom type mapped to standard100 is skipped by the original builder; a missing type lookup can otherwise cause dereference errors. A future adapter should keep an unresolved reference state and defer normalization instead of treating it as present.

## Timetable and calendar

Evidence: `timetables-builder.js` functions `getRawDependencies`, `getSubjectName`, `getTeacherName`, `getLessonNo`, `getDate`, `getViewModel`, `getTimetableEntryViewModel`; declaration `src/viewmodels/timetables.js`.

The dated response is an object keyed by date, whose value is flattened into entries. `HourFrom`/`HourTo` combine with that key into local `start`/`end`; without both, `allDay=true`. The dated entry ID comes from `TimetableEntry.Id`, not an arbitrary array index. The model primary key also includes `start`, so recurring entries must not overwrite distinct dates.

Subject refs `Subject`, `OrgSubject`, `NewSubject`; teacher refs `Teacher`, `OrgTeacher`, `NewTeacher`; classroom refs; and lesson-number/date movement fields all affect display. Original builder embeds icon/arrow characters in title/teacher/lesson number. Preserve original and replacement values structurally, then generate Siberia display text. `IsCanceled` maps to `canceled`; `IsSubstitutionClass` maps to `isSubstitutionClass`. They are independent flags.

Entry-by-ID uses lesson→subject/teacher plus school `LessonsRange`, and constructs an occurrence in the current week using `DayOfTheWeek` unless supplied `lessonData` provides date/start/end. That fallback is not evidence the entry belongs to today's week in every caller. A future implementation must carry the requested date or occurrence key, especially for reminders and changed lessons.

Calendar combines different source families: `calendar-builder.js`, kindergarten timetable/day plan, individual learning paths, one-to-one plans, other activity registers and custom events. Keep a source type and source ID. Do not infer that every calendar item is a standard numbered lesson or include every event in attendance denominators.

## Homework and answers

Evidence: `homework-assignments-builder.js` `getViewModel`, `getHomeworkAssignmentsViewModelById`; declaration `src/viewmodels/homeworkAssignments.js`; store `src/store/modules/view-store/homework-assignments-store.js`.

| Raw field | Local field | Important detail |
|---|---|---|
| `Topic` | `Title` | Do not look for raw Title |
| `Date` | `AddDate` | Creation/add date |
| `DueDate` | `Date` | Due date; local `Date` is not creation time |
| `Text` | `Description` | Keep rich/raw content separately from safe rendering |
| `Teacher.Id` | `Teacher` via users | Keep author ref |
| `Lesson.Id` or `VirtualClass.Id` | `Subject` via subject joins | Original list fallback `Nieznany`; preserve relation discriminator and IDs |
| `AddedFiles` | `HasAttachment` | Not the attachment array itself |
| `HomeworkAssigmentFiles` | same | The misspelling is part of recovered field spelling; do not silently rename at wire boundary |
| `MustSendAttachFile` | same | Requirement indicator, distinct from whether upload is currently allowed |
| `SendFilePossible` | same | Availability indicator |
| `StudentsWhoRead.length>0` | `MarkedAsRead` | Builder assumes array and uses any-entry test; do not invent per-pupil membership behavior without verified context |
| `StudentsWhoMarkedAsDone.length>0` | `MarkedAsDone` | Server done state, not local new badge |
| `StudentAnswerSend` | same | Preserve raw object; rendering inspects `count` for answer presence |

`IsNew`, `MarkedAsRead`, `MarkedAsDone` and answer submission state are four different concepts. Original `markAsSeen` only changes local `IsNew`. Server read/done mutations are separate operations; after success, homework and event-feed copies are updated. A local Siberia done check must not be presented as acknowledged server completion.

## Synergia messages

Evidence: `messages-builder.js` `getMessagesViewModel`, `getMessagesViewModelById`; declaration `src/viewmodels/messages.js`.

| Raw | Local | Rule / hazard |
|---|---|---|
| `Id`, `Sender.Id`, `SendDate` | `Id`, `SenderId`, `SendDate` | Preserve IDs and raw time; sender display requires lookup |
| list `Receiver[]`; detail `Receivers[]` | `Receiver`, `ReceiverMap` | **Different raw key by operation**. List display joins names withcomma; detail result uses array. Normalize into typed recipient refs |
| recipient/user `availabilityStatus` | `ReceiverMap[].availabilityStatus` | Preserve out-of-work availability; not merely name/email |
| `Subject` | `Title` | `JSON.parse` of a JSON-encoded string |
| `Body` | `Description` | `JSON.parse` of a JSON-encoded string; decode once, then safe-render |
| `isNote`, `inSended`, `inTrash`, `isPinned` | `IsNote`, `InSent`, `InTrash`, `IsPinned` | Case/spelling differ; `inSended` is not `inSent` |
| `AddedFiles`, `MessageFiles` | `HasAttachment`, `MessageFiles` | Flag and metadata separate; list may supply full content |
| `ReadDates` | `ReadDates`, `IsNew` | List requires non-null ReadDates and first ReadDate0 plus not sent. Detail directly indexes `[0]`; empty/null needs explicit protocol fixture |
| `inTrash` | `Deleted` | Source local deletion flag also tracks trash; don't equate to proven permanent server deletion |

User lookup IDs are deduplicated; list filters sentinel string`'0'`; user requests are chunked into10 IDs. Display names may remain unknown when lookups fail. The builder parses content after lookup; a malformed JSON string must surface as a protocol error rather than an empty message. Retain raw content for a narrow diagnostic without logging it.

The local `SearchFieldsCombined` is a presentation index over stripped description, sender/receiver/title and filenames. It does not prove a server-side search endpoint. `StrippedDescription` uses a regex; this is not an HTML sanitizer.

## Justifications and announcements

Justification raw fields are lower camelcase: `id`, `lessons`, `attachment`, `messageFromParent`, `postDate`, `justificationStatus`, `justifiedAbsences`, `dateFrom`, `dateTo`, `notifiedTeachers`. They map to capitalized local fields with the same meanings. Falsy parent message becomesnull. Keep original status without inventing an enum meaning from numeric proximity. A local string default does not establish server status type. Evidence: `justifications-builder.js`.

Announcements map `Id`→Id, `AddedBy.Id`→author name, `StartDate`→Start, `EndDate`→End, `Subject`→Title, `CreationDate`→Date, `Content`→Description. `SynergiaAccountId` is added locally. Local `schoolnotices` also has meal-news compatibility fields `isMealNews` and `Attachments`; preserve source family when combining search. Evidence: `announcements-builder.js`, `viewmodels/announcements.js`.

## LibrusGO extras and meal integration

LibrusGO messages use lower-case `id`, `subject`, `content`, `sentAt`, `readAt`, `attachmentsCount`. They are not Synergia JSON-string-encoded Subject/Body. `sentAt` passes through moment→Unix seconds. Sent list uses `firstRecipient` if supplied, otherwise group recipient count; detail loads full recipient refs with IDs and types. Received unread is `readAt===null`. A shared decoder that JSON-parses both APIs will fail.

LibrusGO timetable maps `startDate`/`endDate` to local formatted minute strings; `activityGroup.activity`, `cycleName`, `isCanceled`, `isCatchingUp`, online meetings, tutors, places and note are preserved by builder. It displays only the first online meeting as `onlineLessonUrl` while retaining all meetings. Keep all meeting links in the DTO. Attendance/catch-up is a separately fetched capability model: eligibility depends on reported absence, official attendance already `present`/`absent`, and configured type `enabled` or `catch_up_not_allowed`; do not enable a report action merely because a lesson exists.

Payments retain `remainingAmount` as displayed amount and original `amount` as full amount; preserve numeric representation and currency code, not only translated symbol. Known display statuses:pending,paid,paid_online,paid_partially,overdue,archived; currenciespln/eur. Unknown code remains raw. Invoice availability requires `invoiceDownloadAvailability.isAvailable===true`. Payment display is not authorization to initiate a payment.

Meal balance has `balance` and `hasBalance`; meal updates map `identifier/title/content/date/author/wasRead/attachments` into announcement-like models with `IsNew=!wasRead`. Original fallback may invent balance`'0,00'` and `hasBalance:true` on error; **do not reproduce that as a confirmed zero balance**. Orders, cancellations and integration capability remain distinct operations with role/server gates.

## Decoder acceptance criteria

1. Keep raw operation/family and account scope through every join.
2. Test IDs as observed strings/numbers per operation; normalize identity only after retaining raw form. Do not rely on JS coercion across all fields.
3. Distinguish missing, null, empty and false; local defaults are not wire defaults.
4. Preserve rich content and structured substitutions/history while providing safe normalized projections.
5. A failed dependent lookup produces partial display metadata, not fabricated grades/absence/payment states.
6. Mark every synthetic fixture as synthetic; validate a redacted real response per family before claiming backend compatibility.
