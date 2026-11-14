# Prymus source fields → Siberia representations

The [JSON](model-fields.json), [CSV](model-fields.csv) and [readable declarations](MODEL-FIELDS.md) contain75 class/nested-class declarations with615 fields. They are Gson/Java declaration observations, not a formal server schema. `@SerializedName` determines the annotated key; otherwise Gson uses the Java field name by default. Several unannotated fields are local Room IDs or state and must not be mistaken for remote keys. Primitive fields lose the distinction between absent/null and Java default0/false; object/list fields can be null. Actual initialization and service requiredness need per-consumer validation.

Do not derive unique source IDs from local `id` or `_id` columns. Preserve server ExternalId, student identity, SchoolYear and TermShortcut alongside a namespaced local ID. The importer sets StudentId on several module records from ApiResponse.ExternalId; an absent/raw source StudentId can therefore be assigned by context rather than present on the wire.

| Source family | Important fields / transformations | Integration mapping and loss risks |
|---|---|---|
| ApiResponse account | ExternalId,UserId,FirstName,LastName,SchoolName,SchoolClass,ActualSchoolYear,ActualTermShortcut,License,Login,Sex,DiaryNumber | Auth owner token is separate from pupil/chat IDs and period. School/term identifiers are opaque strings, not assumed semester1/2. Do not publish PIN or broker password in profile JSON. |
| Mark | ExternalId,Mark,SchoolSubject,SchoolYear,TermShortcut,Weight,Category,Comment,teacher/date metadata | Preserve original grade string, category and assessment family. Parse display value separately; descriptive/nonstandard grades must not become0. Mark IDs can collide across pupils. |
| MarkAverage | Mark:String,Type,ClassMark:byte,SchoolSubject,SchoolYear,TermShortcut | School-supplied average string and class/pupil scope. Do not replace with an app-calculated arithmetic mean or infer Type/ClassMark enum meanings without UI/repository mapping. |
| MarkFinal | Source final/period assessment fields | Keep final/proposed/behavior distinctions. A final grade is not an ordinary point in a trend unless the caller explicitly includes it. |
| MarkResults | MarkExternalId:int,MarkAreaId:String,AllStudentMarks:[{Mark:String,Count:int}] | Add a typed class-comparison histogram per selected mark/category. The values are aggregate counts, not peer identities or a ranking. Join by pupil+MarkExternalId; preserve MarkAreaId separately. |
| AttendanceStatistic | PercentageMonthPresence,PercentageTermPresence,PercentageSchoolYearPresence:String;ExternalId:Integer;SchoolYear,TermShortcut | Preserve server-reported percentage as string plus optional parsed numeric value. Explicit null is unavailable, not a genuine0. Format using decimal half-up1place only at display. Scope by pupil/year/term; no local denominator can be inferred from the supplied absence list alone. |
| Attendances | ExternalId:int,AbsenceDate,ExcusedAbsenceStatus:byte,LatenessStatus:byte,LessonNumber:int,SchoolSubject,TimeFrom,TimeTo,ExcusedDate,Comment | Raw flags must survive normalization. LessonNumber is display/time-slot relation; justification submission uses attendance ExternalId instead. Keep late/excused states separate; do not treat unknown flags as presence. |
| JustifiedAttendances | Locally queued IDs/send date/content/student/date | This is a local submission record, inserted before the HTTP operation. It is not proof of school acceptance. Add pending/confirmed/uncertain state rather than changing official absence categories. |
| Timetable,Lessons,Replacement | Schedule date/subject/teacher/time/room,lesson details and replacement relations | Use actual time ranges and source IDs, not fixed45minute periods. Preserve substitutions and original/new details. An absent teacher/ref lookup should not drop a lesson. |
| Tasks,TaskAnswer | Assignment source ID,title/message,teacher,due date,attachments,reply/answer history | Separate remote answer history from local seen/done. Confirmed upload with failed refresh is partial success. Preserve URLs/filename metadata and account ownership for downloads. |
| Topic,ChatMessage,MessageJson | UUID topic,external message ID,user,parent context,title/body,date,read markers,attachments | Opaque string recipient/thread IDs. Separate old/topic chat from new communication-module response family. Deduplicate MQTT deliveries before notifications and keep parents/student contexts separate. |
| ChatSettings | BrokerLogin,BrokerPassword;assigned StudentId | Credentials belong in secure session scope, not general view/cache DTO. A broker login is not the student token or chat user ID. |
| ParentMode,Parent | IsOn,PIN,ParentId and parent names/references | Activation state and parent identity are separate from pupil enrollment. Do not persist PIN in a normal snapshot; do not infer role permission only from a UI flag. |
| Remark,ScoringRemark | Remarks text/date/category/author and point fields | Preserve qualitative and point-based behavior separately. Snapshot starting/current point totals are distinct from recalculating all historical remarks. |
| Announcement,News | Date,content/title,links,category,source IDs | Safe rich-content presentation; local new/read state is distinct from sent server acknowledgement. Keep attachment/link URLs out of logs. |
| Teacher,SchoolInformation,Books,Faq | Contact/reference/library/help data | Typed optional modules; do not turn missing/denied modules into empty authoritative data. SDK/vendor help/analytics should not be confused with school records. |
| ApplicationSettings,Notes,Favourites,ReadNotSendedObject | Local application preference/notes/queue state | Reuse Siberia's local storage/preferences and explicit migration policy. These declarations are not evidence of corresponding server write endpoints. |

## Essential decoder behavior

Use the field tables to construct provider DTOs first. Validate JSON root and account identity before replacing scoped caches. Preserve optional raw keys and unknown enums; source Gson's leniency is not permission to accept an HTML login/error page as valid data.

Lists can be null or empty. `ApiResponse.Marks` missing during a failed/partial response must not erase valid grades. A successful complete snapshot with an explicit empty authoritative list can replace that covered module. The exact server omission semantics remain a release gate, so expose module coverage/freshness rather than guessing globally.

The source may return `system_message` instead of school arrays. Its lowercase code/title/message/data fields belong to a business message; classify it before invoking module decoders. Version code1 and user-facing device-limit paths were observed, but a complete server error-code enumeration was not recovered.

## Date and numeric policies

The hourly signing formatter is fixedGMT+01:00. That is distinct from diary display, local composer timestamps and server dates. `getDateAndTimeNow` formats local `dd.MM.yyyy HH:mm`; justification's absence date string is constructed as `dd-MM-yyyy (weekday label)`; other source APIs contain ISO-like date strings. Preserve each operation's serializer rather than using one universal DateTime.toIso8601String.

Raw average and attendance percentages are Strings. Preserve them before decimal parsing; display fallback0 in the old UI is not a factual server value. Class histogram counts are integer counts; validating nonnegative counts and guarding a zero sum is a future design requirement. Percentages should not be reconstructed from the absence-only records unless the school denominator is independently known.

## SDK and source-version bridge

The new host SDK is described in the shared current-source plan. Metadata beyond its built-in lesson/grade/attendance model needs an agreed additive representation. Keep provider-specific DTO state outside flattened UI strings. Pure-Dart signing/decoding must run within `dart_eval`; package:crypto, MQTT, Android image conversion and arbitrary filesystem access are not automatically available. Snapshot modules should not each download the same large response in separate fresh VMs without considering request/body limits.

Future-agent acceptance should include all615 field locators as a navigation inventory, but meaningful tests should target actual decoder branches: missing/null primitives, average strings, aggregate counts, nested attachments, identity/year collisions, raw flags, unknown values and source-versus-local IDs. A test that merely mirrors every declaration is not enough to establish integration correctness.
