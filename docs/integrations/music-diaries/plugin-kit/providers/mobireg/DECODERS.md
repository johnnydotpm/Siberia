# MobiReg decoder field contracts

Readable view of [decoder-shapes.json](decoder-shapes.json). Android3.1.7 static constructor evidence only. `unresolved` is an open fact. Alias-only rows refer to the primary field. `DateTime.now()` is an original-client fallback; preserving unknown original time is a recommended Siberia presentation policy. Fields are consumed wire keys, not necessarily retained object members.

## Account.fromJson

Source `rodzic/models/account.dart`, entry `0x4a52b8`.

| Wire key | Type / nullable | Missing default | Conversion / aliases | First key PC |
|---|---|---|---|---|
| `id` | String / false | unresolved | String identity; local persisted account record, not remote numeric user id | `0x4a52e4` |
| `address` | String / false | "" | null => empty String; non-null must satisfy String assertion | `0x4a533c` |
| `school` | String / false | "" | null => empty String; non-null must satisfy String assertion | `0x4a53ac` |
| `login` | String / false | "" | null => empty String; non-null must satisfy String assertion | `0x4a541c` |
| `userId` | int / false | 0 | null=>0; strict int assertion; unlike users context no String int coercion | `0x4a548c` |
| `role` | int / false | 0 | null=>0; strict int assertion; unlike users context no String int coercion | `0x4a54f8` |
| `firstName` | String / false | "" | null => empty String; non-null must satisfy String assertion | `0x4a5564` |
| `lastName` | String / false | "" | null => empty String; non-null must satisfy String assertion | `0x4a55d4` |
| `pupils` | unresolved / unresolved | unresolved | unresolved; preserve raw value until field-specific decoder is verified | `0x4a5644` |
| `messagingUrl` | String / false | "" | null => empty String; non-null must satisfy String assertion | `0x4a5734` |
| `oldHomeworkModule` | int / false | 0 | null=>0; strict int assertion; unlike users context no String int coercion | `0x4a57a4` |
| `homeworksUrl` | String / false | "" | null => empty String; non-null must satisfy String assertion | `0x4a5810` |
| `authType` | String / false | "password" | null => password; String assertion | `0x4a5880` |
| `contextVersion` | int / false | 0 | null=>0; strict int assertion; unlike users context no String int coercion | `0x4a58ec` |

## Announcement.fromJson

Source `rodzic/models/announcement.dart`, entry `0x49b1ec`.

| Wire key | Type / nullable | Missing default | Conversion / aliases | First key PC |
|---|---|---|---|---|
| `read` | unresolved / unresolved | unresolved | unresolved; preserve raw value until field-specific decoder is verified | `0x49b218` |
| `xread` | unresolved / unresolved | unresolved | unresolved; preserve raw value until field-specific decoder is verified | `0x49b240` |
| `answers` | unresolved / unresolved | unresolved | unresolved; preserve raw value until field-specific decoder is verified | `0x49b308` |
| `userAnswer` | unresolved / unresolved | unresolved | unresolved; preserve raw value until field-specific decoder is verified | `0x49b570` |
| `valid` | unresolved / unresolved | unresolved | unresolved; preserve raw value until field-specific decoder is verified | `0x49b5ec` |
| `id` | int / false | unresolved | integer accepted or String int.parse; required identity, malformed can throw | `0x49b694` |
| `type` | unresolved / unresolved | unresolved | unresolved; preserve raw value until field-specific decoder is verified | `0x49b7b0` |
| `kind` | unresolved / unresolved | unresolved | unresolved; preserve raw value until field-specific decoder is verified | `0x49b840` |
| `title` | String / false | "" | null=>empty String; String assertion | `0x49b8f0` |
| `dateTime` | DateTime / false | unresolved | DateTime.parse of selected String; invalid required timestamp can throw | `0x49b960` |
| `author` | String / false | "" | null=>empty String; String assertion | `0x49b9bc` |
| `login` | String / false | "" | null=>empty String; String assertion | `0x49ba2c` |
| `content` | String / false | "" | null=>empty String; String assertion | `0x49ba9c` |
| `declined` | bool / false | false | _flag recognizes true, numeric1, String1/Stringtrue | `0x49bb0c` |
| `pollOpen` | bool / false | true | missing/null=>true; otherwise _flag | `0x49bb3c` |
| `pending` | bool / false | false | _flag recognizes true, numeric1, String1/Stringtrue | `0x49bbc8` |

## AttendanceTerm.fromJson

Source `rodzic/models/attendance_data.dart`, entry `0x4a1950`.

| Wire key | Type / nullable | Missing default | Conversion / aliases | First key PC |
|---|---|---|---|---|
| `id` | int / false | unresolved | required int assertion; no numeric String coercion | `0x4a197c` |
| `isYear` | int / false | unresolved | required int assertion; no numeric String coercion | `0x4a19d0` |
| `label` | String / false | unresolved | required String assertion | `0x4a1a3c` |
| `dateFrom` | String / false | unresolved | required String assertion | `0x4a1a94` |
| `dateTo` | String / false | unresolved | required String assertion | `0x4a1ae8` |

## AttendanceRecord.fromJson

Source `rodzic/models/attendance_data.dart`, entry `0x4a1cac`.

| Wire key | Type / nullable | Missing default | Conversion / aliases | First key PC |
|---|---|---|---|---|
| `ca` | String? / true | null | non-null toString; empty string then normalized to null | `0x4a1cd8` |
| `d` | String / false | unresolved | required String assertion | `0x4a1d3c` |
| `sid` | int / false | unresolved | required int assertion | `0x4a1d94` |
| `ab` | String / false | unresolved | required String assertion | `0x4a1de8` |
| `tn` | String / false | "" | non-null toString, missing/null=>empty String | `0x4a1e60` |

## DashboardAttendance.fromJson

Source `rodzic/models/dashboard_attendance.dart`, entry `0x75cc10`.

| Wire key | Type / nullable | Missing default | Conversion / aliases | First key PC |
|---|---|---|---|---|
| `date` | unresolved / unresolved | unresolved | unresolved; preserve raw value until field-specific decoder is verified | `0x75cc34` |
| `id` | unresolved / unresolved | unresolved | unresolved; preserve raw value until field-specific decoder is verified | `0x75cc90` |
| `name` | unresolved / unresolved | unresolved | unresolved; preserve raw value until field-specific decoder is verified | `0x75cd24` |
| `subjectName` | unresolved / unresolved | unresolved | unresolved; preserve raw value until field-specific decoder is verified | `0x75cd80` |
| `subject_name` | unresolved / unresolved | unresolved | unresolved; preserve raw value until field-specific decoder is verified | `0x75cdb4` |
| `startTime` | unresolved / unresolved | unresolved | unresolved; preserve raw value until field-specific decoder is verified | `0x75ceac` |
| `start_time` | unresolved / unresolved | unresolved | unresolved; preserve raw value until field-specific decoder is verified | `0x75cf18` |
| `countAs` | unresolved / unresolved | unresolved | unresolved; preserve raw value until field-specific decoder is verified | `0x75cf8c` |
| `count_as` | unresolved / unresolved | unresolved | unresolved; preserve raw value until field-specific decoder is verified | `0x75cfc0` |
| `eventId` | unresolved / unresolved | unresolved | unresolved; preserve raw value until field-specific decoder is verified | `0x75d02c` |
| `event_id` | unresolved / unresolved | unresolved | unresolved; preserve raw value until field-specific decoder is verified | `0x75d060` |

## DashboardElement.fromJson

Source `rodzic/models/dashboard_element.dart`, entry `0x75c844`.

| Wire key | Type / nullable | Missing default | Conversion / aliases | First key PC |
|---|---|---|---|---|
| `type` | unresolved / unresolved | unresolved | unresolved; preserve raw value until field-specific decoder is verified | `0x75c870` |
| `date` | unresolved / unresolved | unresolved | unresolved; preserve raw value until field-specific decoder is verified | `0x75c8f4` |
| `label` | unresolved / unresolved | unresolved | unresolved; preserve raw value until field-specific decoder is verified | `0x75c9ac` |
| `data` | unresolved / unresolved | unresolved | unresolved; preserve raw value until field-specific decoder is verified | `0x75ca14` |

## Exam.fromJson

Source `rodzic/models/exam.dart`, entry `0x492758`.

| Wire key | Type / nullable | Missing default | Conversion / aliases | First key PC |
|---|---|---|---|---|
| `dateTime` | date/time value / true | unresolved | first non-null primary/alias; date parsing uses dedicated branches; invalid-date fallback still gated; aliases: date | `0x492784` |
| `date` | unresolved / unresolved | unresolved | alias of dateTime | `0x4927ac` |
| `addedTime` | date/time value / true | unresolved | first non-null primary/alias; date parsing uses dedicated branches; invalid-date fallback still gated; aliases: added_date | `0x492810` |
| `added_date` | unresolved / unresolved | unresolved | alias of addedTime | `0x492838` |
| `id` | int / false | 0 | int.tryParse((value ?? "0").toString()) ?? 0 | `0x49289c` |
| `pupil_id` | int / false | 0 | int.tryParse((value ?? "0").toString()) ?? 0 | `0x492924` |
| `teacherId` | int / false | 0 | first non-null teacherId/teacher_id then int.tryParse textual value; aliases: teacher_id | `0x4929ac` |
| `teacher_id` | unresolved / unresolved | unresolved | alias of teacherId | `0x4929d4` |
| `title` | String / false | "" | first non-null primary/alias then stringify; aliases: name | `0x492a5c` |
| `name` | unresolved / unresolved | unresolved | alias of title | `0x492a84` |
| `description` | String / false | "" | first non-null primary/alias then stringify; aliases: content | `0x492ae8` |
| `content` | unresolved / unresolved | unresolved | alias of description | `0x492b10` |
| `test_type` | String / false | "Sprawdzian" | null => literal Sprawdzian; stringify | `0x492b74` |
| `subjectName` | String / false | "" | first non-null primary/alias then stringify; aliases: subject_name | `0x492c70` |
| `subject_name` | unresolved / unresolved | unresolved | alias of subjectName | `0x492c98` |
| `teacher_name` | String / false | "" | null => empty String; stringify | `0x492cfc` |
| `teacher_surname` | String / false | "" | null => empty String; stringify | `0x492d60` |
| `startTime` | date/time value / true | unresolved | first non-null primary/alias; date parsing uses dedicated branches; invalid-date fallback still gated; aliases: start_time | `0x492dc4` |
| `start_time` | unresolved / unresolved | unresolved | alias of startTime | `0x492e28` |
| `endTime` | date/time value / true | unresolved | first non-null primary/alias; date parsing uses dedicated branches; invalid-date fallback still gated; aliases: end_time | `0x492e94` |
| `end_time` | unresolved / unresolved | unresolved | alias of endTime | `0x492ef4` |

## HomeworkDetail.fromJson

Source `rodzic/models/homework.dart`, entry `0x763744`.

| Wire key | Type / nullable | Missing default | Conversion / aliases | First key PC |
|---|---|---|---|---|
| `teacher_comments` | unresolved / unresolved | unresolved | unresolved; preserve raw value until field-specific decoder is verified | `0x763770` |
| `teacher` | String / false | "" | stringify(value ?? "") | `0x763798` |
| `content` | String / false | "" | stringify(value ?? "") | `0x7637dc` |
| `groups` | unresolved / unresolved | unresolved | unresolved; preserve raw value until field-specific decoder is verified | `0x76381c` |
| `files` | unresolved / unresolved | unresolved | unresolved; preserve raw value until field-specific decoder is verified | `0x7639d0` |
| `status` | unresolved / unresolved | unresolved | unresolved; preserve raw value until field-specific decoder is verified | `0x763b94` |
| `solution` | unresolved / unresolved | unresolved | unresolved; preserve raw value until field-specific decoder is verified | `0x763c28` |

## HomeworkSolution.fromJson

Source `rodzic/models/homework.dart`, entry `0x763d68`.

| Wire key | Type / nullable | Missing default | Conversion / aliases | First key PC |
|---|---|---|---|---|
| `content` | String / false | "" | stringify(value ?? "") | `0x763d94` |
| `sent_at` | String / false | "" | stringify(value ?? "") | `0x763dd4` |
| `files` | unresolved / unresolved | unresolved | unresolved; preserve raw value until field-specific decoder is verified | `0x763e18` |

## HomeworkFile.fromJson

Source `rodzic/models/homework.dart`, entry `0x76403c`.

| Wire key | Type / nullable | Missing default | Conversion / aliases | First key PC |
|---|---|---|---|---|
| `id` | int / false | 0 | int.tryParse((value ?? 0).toString()) ?? 0 | `0x764068` |
| `name` | String / false | "plik" | stringify(value ?? "plik") | `0x7640cc` |
| `extension` | String / false | "" | stringify(value ?? "") | `0x764110` |
| `url` | String / false | "" | stringify(value ?? "") | `0x764150` |
| `size` | int / false | 0 | int.tryParse((value ?? 0).toString()) ?? 0 | `0x764190` |
| `sender` | int / false | 0 | int.tryParse((value??0).toString())??0 | `0x7641f0` |

## Homework.fromDiaryJson

Source `rodzic/models/homework.dart`, entry `0x4943f4`.

| Wire key | Type / nullable | Missing default | Conversion / aliases | First key PC |
|---|---|---|---|---|
| `dateTime` | unresolved / unresolved | unresolved | unresolved; preserve raw value until field-specific decoder is verified | `0x494420` |
| `addedTime` | unresolved / unresolved | unresolved | unresolved; preserve raw value until field-specific decoder is verified | `0x49447c` |
| `id` | int / false | 0 | int.tryParse((value ?? 0).toString()) ?? 0 | `0x4944c4` |
| `subjectId` | int / false | 0 | int.tryParse((value ?? 0).toString()) ?? 0 | `0x494528` |
| `subjectName` | String / false | "" | stringify(value ?? "") | `0x49458c` |
| `title` | String / false | "" | stringify(value ?? "") | `0x4945cc` |
| `description` | String / false | "" | stringify(value ?? "") | `0x49460c` |
| `teacherId` | int / false | 0 | int.tryParse((value ?? 0).toString()) ?? 0 | `0x494690` |

## Homework.fromModuleJson

Source `rodzic/models/homework.dart`, entry `0x49527c`.

| Wire key | Type / nullable | Missing default | Conversion / aliases | First key PC |
|---|---|---|---|---|
| `deadline_at` | unresolved / unresolved | unresolved | unresolved; preserve raw value until field-specific decoder is verified | `0x4952a8` |
| `studentIds` | unresolved / unresolved | unresolved | unresolved; preserve raw value until field-specific decoder is verified | `0x495304` |
| `teacher_comments` | unresolved / unresolved | unresolved | unresolved; preserve raw value until field-specific decoder is verified | `0x49532c` |
| `statuses` | unresolved / unresolved | unresolved | unresolved; preserve raw value until field-specific decoder is verified | `0x495354` |
| `id` | int / false | 0 | int.tryParse((value ?? 0).toString()) ?? 0 | `0x49537c` |
| `subject` | String / false | "" | stringify(value ?? "") | `0x4953e0` |
| `title` | String / false | "" | stringify(value ?? "") | `0x495420` |
| `created_at` | unresolved / unresolved | unresolved | unresolved; preserve raw value until field-specific decoder is verified | `0x495460` |
| `student` | String / false | "" | stringify(value ?? "") | `0x4955f4` |
| `status` | unresolved / unresolved | unresolved | unresolved; preserve raw value until field-specific decoder is verified | `0x495634` |
| `archived` | unresolved / unresolved | unresolved | unresolved; preserve raw value until field-specific decoder is verified | `0x495a14` |

## JustificationRecord.fromJson

Source `rodzic/models/justification_record.dart`, entry `0x76cf38`.

| Wire key | Type / nullable | Missing default | Conversion / aliases | First key PC |
|---|---|---|---|---|
| `events` | unresolved / unresolved | unresolved | unresolved; preserve raw value until field-specific decoder is verified | `0x76cf64` |
| `id` | int / false | 0 | num? assertion; numeric toInt, null=>0; numeric strings are not accepted by this path | `0x76d11c` |
| `created_at` | DateTime / false | "DateTime.now()" | DateTime.tryParse textual source; fallback current local DateTime | `0x76d1d0` |
| `message` | String / false | "" | stringify null as empty String | `0x76d288` |
| `period_from` | String / false | "" | stringify null as empty String | `0x76d2fc` |
| `period_to` | String / false | "" | stringify null as empty String | `0x76d374` |
| `event_count` | int / false | 0 | num? assertion; numeric toInt, null=>0; numeric strings are not accepted by this path | `0x76d3ec` |
| `status` | int / false | 0 | num? assertion; numeric toInt, null=>0; numeric strings are not accepted by this path | `0x76d4a0` |

## JustifyEventRef.fromJson

Source `rodzic/models/justification_record.dart`, entry `0x76d5f4`.

| Wire key | Type / nullable | Missing default | Conversion / aliases | First key PC |
|---|---|---|---|---|
| `event_id` | int / false | 0 | num? -> toInt, null=>0 | `0x76d620` |
| `day` | String? / true | null | nullable stringified value; exact empty-string distinction requires fixture | `0x76d6d8` |
| `subject` | String / false | "" | null=>empty String; stringify | `0x76d730` |
| `time_from` | String? / true | null | nullable stringified value; exact empty-string distinction requires fixture | `0x76d7a4` |
| `time_to` | String? / true | null | nullable stringified value; exact empty-string distinction requires fixture | `0x76d7fc` |
| `attendance_type` | String? / true | null | nullable stringified value; exact empty-string distinction requires fixture | `0x76d854` |
| `absence_code` | String? / true | null | nullable stringified value; exact empty-string distinction requires fixture | `0x76d8ac` |
| `applied_status` | int? / true | null | num? assertion then nullable toInt | `0x76d900` |

## JustifyEvent.fromJson

Source `rodzic/models/justify_event.dart`, entry `0x7ba880`.

| Wire key | Type / nullable | Missing default | Conversion / aliases | First key PC |
|---|---|---|---|---|
| `ab` | String / false | "" | stringify(value ?? "") | `0x7ba8b4` |
| `st` | String / false | "" | stringify(value ?? "") | `0x7ba928` |
| `end` | String / false | "" | stringify(value ?? "") | `0x7ba9a0` |
| `sub` | String / false | "" | stringify(value ?? "") | `0x7baa14` |
| `js` | int / false | 0 | num? -> toInt, null=>0 | `0x7baa8c` |
| `attendance_type` | String / false | "absent" | stringify(value ?? "absent") | `0x7bab40` |

## MailMessage.fromJson

Source `rodzic/models/mail_message.dart`, entry `0x47df60`.

| Wire key | Type / nullable | Missing default | Conversion / aliases | First key PC |
|---|---|---|---|---|
| `id` | int / false | 0 | null => integer0; non-null int assertion, no String-ID coercion here | `0x47df8c` |
| `subject` | String / false | "" | null => empty String; String assertion | `0x47dff8` |
| `content` | String / false | "" | null => empty String; String assertion | `0x47e068` |
| `author` | unresolved / unresolved | unresolved | unresolved; preserve raw value until field-specific decoder is verified | `0x47e0d8` |
| `recipients` | List / false | unresolved | List guard before typed element mapping; malformed-list fallback requires fixture verification | `0x47e154` |
| `files` | List / false | unresolved | List guard before typed element mapping; malformed-list fallback requires fixture verification | `0x47e304` |
| `date` | DateTime / false | "DateTime.now()" | missing/null or DateTime.tryParse failure => source current local DateTime; Siberia recommendation preserve unknown original timestamp instead of fabricating history | `0x47e4b4` |
| `read_at` | DateTime? / true | null | non-null String then DateTime.tryParse; absent/null=>null | `0x47e5b0` |
| `stared` | bool / false | false | equality to literal boolean true; numeric1 and Stringtrue are not generalized to true | `0x47e648` |
| `trashed` | bool / false | false | equality to literal boolean true; numeric1 and Stringtrue are not generalized to true | `0x47e698` |
| `previous` | List / false | unresolved | List guard before typed element mapping; malformed-list fallback requires fixture verification | `0x47e6e8` |

## MailRecipientInfo.fromJson

Source `rodzic/models/mail_message.dart`, entry `0x47f48c`.

| Wire key | Type / nullable | Missing default | Conversion / aliases | First key PC |
|---|---|---|---|---|
| `name` | String / false | "" | null=>empty String; String assertion | `0x47f4b8` |
| `roleName` | String? / true | null | nullable String assertion | `0x47f528` |
| `read_at` | DateTime? / true | null | DateTime.tryParse of non-null String | `0x47f578` |

## MailFile.fromJson

Source `rodzic/models/mail_message.dart`, entry `0x47f16c`.

| Wire key | Type / nullable | Missing default | Conversion / aliases | First key PC |
|---|---|---|---|---|
| `id` | int / false | 0 | int.tryParse(value.toString()) ?? 0 | `0x47f198` |
| `name` | String / false | "" | null => empty String; String assertion | `0x47f214` |
| `size` | int / false | 0 | int.tryParse(value.toString()) ?? 0 | `0x47f284` |
| `url` | String / false | "" | null => empty String; String assertion | `0x47f300` |
| `extension` | String / false | "" | null => empty String; String assertion | `0x47f36c` |

## MailAuthor.fromJson

Source `rodzic/models/mail_message.dart`, entry `0x47ef04`.

| Wire key | Type / nullable | Missing default | Conversion / aliases | First key PC |
|---|---|---|---|---|
| `id` | int / false | 0 | null=>0; int assertion | `0x47ef30` |
| `name` | String / false | "" | null => empty String; String assertion | `0x47ef9c` |
| `role` | String / false | "" | null => empty String; String assertion | `0x47f008` |

## MailRecipient.fromJson

Source `rodzic/models/mail_recipient.dart`, entry `0x776704`.

| Wire key | Type / nullable | Missing default | Conversion / aliases | First key PC |
|---|---|---|---|---|
| `id` | String / false | "" | normalize: stringify; regex ^\d+$ => prefix user_; nonnumeric ID retained | `0x776730` |
| `name` | String / false | "" | null=>empty String; String assertion | `0x7767b0` |
| `role` | String / false | "" | first non-null role/_type then String assertion; aliases: _type | `0x776824` |
| `_type` | unresolved / unresolved | unresolved | alias of role | `0x776848` |

## Mark.fromApiJson

Source `rodzic/models/mark.dart`, entry `0x48d574`.

| Wire key | Type / nullable | Missing default | Conversion / aliases | First key PC |
|---|---|---|---|---|
| `id` | int / false | unresolved | integer accepted or String parsed with int.parse; malformed required ID can throw | `0x48d5a0` |
| `subjectId` | int / false | unresolved | integer accepted or String parsed with int.parse; malformed required ID can throw | `0x48d6b0` |
| `value` | String / false | "" | null => empty String; other branch stringifies selected value | `0x48d7c0` |
| `weight` | unresolved / unresolved | unresolved | unresolved; preserve raw value until field-specific decoder is verified | `0x48d834` |
| `date` | String / false | "" | null => empty String; other branch stringifies selected value | `0x48d980` |
| `bgColor` | String / false | "" | first non-null bgColor/color, stringify; aliases: color | `0x48d9f4` |
| `color` | unresolved / unresolved | unresolved | alias of bgColor | `0x48da1c` |
| `description` | String / false | "" | null => empty String; other branch stringifies selected value | `0x48da80` |
| `kindLabel` | String / false | "" | null => empty String; other branch stringifies selected value | `0x48daf4` |
| `comments` | String / false | "" | first non-null comments/comment, stringify; aliases: comment | `0x48db68` |
| `comment` | unresolved / unresolved | unresolved | alias of comments | `0x48db90` |
| `count_to_avg` | int? / true | null | first non-null; nullable int assertion, no generic bool coercion; aliases: countToAvg | `0x48dbf4` |
| `countToAvg` | unresolved / unresolved | unresolved | alias of count_to_avg | `0x48dc1c` |
| `teacher_id` | int / false | 0 | first non-null teacher_id/teacherId; int assertion; aliases: teacherId | `0x48dc80` |
| `teacherId` | unresolved / unresolved | unresolved | alias of teacher_id | `0x48dca8` |
| `subject_name` | String / false | "" | null => empty String; String assertion | `0x48dd14` |
| `teacher_name` | String / false | "" | null => empty String; String assertion | `0x48dd84` |
| `teacher_surname` | String / false | "" | null => empty String; String assertion | `0x48ddf4` |
| `markGroupId` | int / false | 0 | int or int.tryParse textual representation, fallback0 | `0x48de64` |

## NotificationSettings.fromJson

Source `rodzic/models/notification_settings.dart`, entry `0x792e94`.

| Wire key | Type / nullable | Missing default | Conversion / aliases | First key PC |
|---|---|---|---|---|
| `marks` | bool / false | unresolved | helper b0x793304: bool unchanged; numeric nonzero true; String1 or case-insensitive true accepted; other input uses caller fallback | `0x792ee0` |
| `attendance` | int / false | 1 | integer unchanged; number toInt; int.tryParse String else1; clamp0..3 | `0x792f28` |
| `exams` | bool / false | unresolved | helper b0x793304: bool unchanged; numeric nonzero true; String1 or case-insensitive true accepted; other input uses caller fallback | `0x793018` |
| `homeworks` | bool / false | unresolved | helper b0x793304: bool unchanged; numeric nonzero true; String1 or case-insensitive true accepted; other input uses caller fallback | `0x793060` |
| `reprimands` | bool / false | unresolved | helper b0x793304: bool unchanged; numeric nonzero true; String1 or case-insensitive true accepted; other input uses caller fallback | `0x7930a8` |
| `messages` | bool / false | unresolved | helper b0x793304: bool unchanged; numeric nonzero true; String1 or case-insensitive true accepted; other input uses caller fallback | `0x7930f0` |
| `announcements` | bool / false | unresolved | helper b0x793304: bool unchanged; numeric nonzero true; String1 or case-insensitive true accepted; other input uses caller fallback | `0x793138` |
| `planChanges` | bool / false | unresolved | helper b0x793304: bool unchanged; numeric nonzero true; String1 or case-insensitive true accepted; other input uses caller fallback | `0x7931b4` |
| `substitutions` | bool / false | unresolved | helper b0x793304: bool unchanged; numeric nonzero true; String1 or case-insensitive true accepted; other input uses caller fallback | `0x793200` |
| `cancellations` | bool / false | unresolved | helper b0x793304: bool unchanged; numeric nonzero true; String1 or case-insensitive true accepted; other input uses caller fallback | `0x793250` |

## Reprimand.fromJson

Source `rodzic/models/reprimand.dart`, entry `0x49cbb8`.

| Wire key | Type / nullable | Missing default | Conversion / aliases | First key PC |
|---|---|---|---|---|
| `id` | unresolved / unresolved | unresolved | unresolved; preserve raw value until field-specific decoder is verified | `0x49cbdc` |
| `pupilId` | unresolved / unresolved | unresolved | unresolved; preserve raw value until field-specific decoder is verified | `0x49cd14` |
| `teacherId` | unresolved / unresolved | unresolved | unresolved; preserve raw value until field-specific decoder is verified | `0x49ce20` |
| `teacherName` | unresolved / unresolved | unresolved | unresolved; preserve raw value until field-specific decoder is verified | `0x49cf2c` |
| `kind` | unresolved / unresolved | unresolved | unresolved; preserve raw value until field-specific decoder is verified | `0x49d01c` |
| `getDate` | unresolved / unresolved | unresolved | unresolved; preserve raw value until field-specific decoder is verified | `0x49d0b0` |
| `content` | unresolved / unresolved | unresolved | unresolved; preserve raw value until field-specific decoder is verified | `0x49d108` |
| `status` | unresolved / unresolved | unresolved | unresolved; preserve raw value until field-specific decoder is verified | `0x49d188` |

## Subject.fromJson

Source `rodzic/models/subject.dart`, entry `0x48e094`.

| Wire key | Type / nullable | Missing default | Conversion / aliases | First key PC |
|---|---|---|---|---|
| `teachersIds` | unresolved / unresolved | unresolved | unresolved; preserve raw value until field-specific decoder is verified | `0x48e0c0` |
| `teacher_ids` | unresolved / unresolved | unresolved | unresolved; preserve raw value until field-specific decoder is verified | `0x48e0e8` |
| `id` | unresolved / unresolved | unresolved | unresolved; preserve raw value until field-specific decoder is verified | `0x48e23c` |
| `label` | unresolved / unresolved | unresolved | unresolved; preserve raw value until field-specific decoder is verified | `0x48e388` |
| `name` | unresolved / unresolved | unresolved | unresolved; preserve raw value until field-specific decoder is verified | `0x48e3e8` |

## Term.fromJson

Source `rodzic/models/term.dart`, entry `0x4913bc`.

| Wire key | Type / nullable | Missing default | Conversion / aliases | First key PC |
|---|---|---|---|---|
| `id` | int / false | 0 | int unchanged; otherwise int.tryParse(value.toString()) ?? 0 | `0x4913e8` |
| `parentId` | int / false | 0 | int unchanged; otherwise int.tryParse(value.toString()) ?? 0 | `0x491514` |
| `label` | String / false | "" | null => empty String | `0x491650` |
| `isYear` | bool / false | false | true for integer 1 or string "1"; preserve source check rather than generic truthiness | `0x4916c4` |
| `dateFrom` | String / false | "" | null => empty String | `0x491768` |
| `dateTo` | String / false | "" | null => empty String | `0x4917d4` |

## TermMark.fromApiJson

Source `rodzic/models/term_mark.dart`, entry `0x48d14c`.

| Wire key | Type / nullable | Missing default | Conversion / aliases | First key PC |
|---|---|---|---|---|
| `isFinal` | bool / false | false | first non-null alias; recognizes true, numeric1 and string1 branches; aliases: is_final | `0x48d178` |
| `is_final` | unresolved / unresolved | unresolved | alias of isFinal | `0x48d1a0` |
| `isProposal` | bool / false | false | first non-null alias; recognizes true, numeric1 and string1 branches; aliases: is_proposal | `0x48d1d0` |
| `is_proposal` | unresolved / unresolved | unresolved | alias of isProposal | `0x48d1f8` |
| `value` | String / false | "" | first non-null value/val then stringifies; aliases: val | `0x48d228` |
| `val` | unresolved / unresolved | unresolved | alias of value | `0x48d28c` |
| `mtTeacherId` | int / false | unresolved | first non-null; int assertion; aliases: teacherId | `0x48d490` |
| `teacherId` | unresolved / unresolved | unresolved | alias of mtTeacherId | `0x48d4b4` |

## TimetableEvent.fromJson

Source `rodzic/models/timetable_event.dart`, entry `0x498740`.

| Wire key | Type / nullable | Missing default | Conversion / aliases | First key PC |
|---|---|---|---|---|
| `tests` | List / true | unresolved | List? assertion before element mapping; do not flatten or infer element schema | `0x49876c` |
| `teachers` | List / true | unresolved | List? assertion before element mapping; do not flatten or infer element schema | `0x4987ec` |
| `bgColor` | String? / true | null | first non-null aliases then nullable String assertion; aliases: attendanceColor | `0x49886c` |
| `attendanceColor` | unresolved / unresolved | unresolved | alias of bgColor | `0x498894` |
| `id` | unresolved / unresolved | unresolved | unresolved; preserve raw value until field-specific decoder is verified | `0x4988fc` |
| `dateTimeFrom` | DateTime / false | unresolved | first non-null then String assertion and DateTime.parse; aliases: startTime | `0x498a18` |
| `startTime` | unresolved / unresolved | unresolved | alias of dateTimeFrom | `0x498a40` |
| `dateTimeTo` | DateTime / false | unresolved | first non-null then String assertion and DateTime.parse; aliases: endTime | `0x498ab8` |
| `endTime` | unresolved / unresolved | unresolved | alias of dateTimeTo | `0x498ae0` |
| `subjectName` | String / false | "Brak nazwy" | null => literal Brak nazwy; String assertion | `0x498b58` |
| `title` | String? / true | null | first non-null aliases then nullable String assertion; aliases: content | `0x498bc8` |
| `content` | unresolved / unresolved | unresolved | alias of title | `0x498bf0` |
| `topic` | unresolved / unresolved | unresolved | unresolved; preserve raw value until field-specific decoder is verified | `0x498c18` |
| `room` | String? / true | null | first non-null aliases then nullable String assertion; aliases: roomName | `0x498c80` |
| `roomName` | unresolved / unresolved | unresolved | alias of room | `0x498ca8` |
| `attendanceLabel` | String? / true | null | first non-null aliases then nullable String assertion; aliases: attendanceSymbol | `0x498d88` |
| `attendanceSymbol` | unresolved / unresolved | unresolved | alias of attendanceLabel | `0x498db0` |
| `attendanceName` | String? / true | null | nullable String assertion | `0x498e18` |
| `attendanceUnchecked` | unresolved / unresolved | unresolved | unresolved; preserve raw value until field-specific decoder is verified | `0x498e80` |
| `type` | String / false | "lekcja" | null => literal lekcja; String assertion | `0x498f70` |
| `isLocked` | unresolved / unresolved | unresolved | unresolved; preserve raw value until field-specific decoder is verified | `0x498fe0` |
| `isCanceled` | unresolved / unresolved | unresolved | unresolved; preserve raw value until field-specific decoder is verified | `0x4990b0` |
| `substitution` | unresolved / unresolved | unresolved | unresolved; preserve raw value until field-specific decoder is verified | `0x4991a0` |
| `oldSubjectName` | String? / true | null | nullable String assertion | `0x499284` |
| `oldTeachers` | List / true | unresolved | List? assertion before element mapping; do not flatten or infer element schema | `0x4992d8` |

## TimetableExam.fromJson

Source `rodzic/models/timetable_event.dart`, entry `0x499718`.

| Wire key | Type / nullable | Missing default | Conversion / aliases | First key PC |
|---|---|---|---|---|
| `testId` | unresolved / unresolved | unresolved | unresolved; preserve raw value until field-specific decoder is verified | `0x499744` |
| `testType` | unresolved / unresolved | unresolved | unresolved; preserve raw value until field-specific decoder is verified | `0x4997cc` |
| `testLabel` | unresolved / unresolved | unresolved | unresolved; preserve raw value until field-specific decoder is verified | `0x49983c` |
| `content` | unresolved / unresolved | unresolved | unresolved; preserve raw value until field-specific decoder is verified | `0x499860` |
