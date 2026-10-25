# Fryderyk: recovered request and decoder contracts

This local-only deep pass supersedes the earlier string-only route assumptions. Android 1.0.12 was decoded by Blutter into named Dart AOT ARM64 assembly; iOS 1.1.7 was parsed with a corrected execution-free snapshot parser and traced through native callers. No original app/backend was executed or contacted, and no commit or push was made in this pass. These are **shipped-client contracts**, not claims of current server acceptance.

## Critical corrections to the earlier handoff

- `/login` is a deep-link path checked under host `app`, not a recovered HTTP endpoint. Info.plist registers scheme `fryderyk`. Query `c` is Base64-decoded, decoded as UTF-8, split on `:`, then elements 0 and 1 are passed to login as username/password. It is not JSON. Extra split elements are not read here; do not invent password-with-colon support. Scheme enforcement at the outer caller still needs review. Evidence: Android TokenService.loginByDeepLink 0x615484; Base64 call 0x6155d8, UTF8 call 0x6155e8, colon split 0x615600, login call 0x615658.
- `/validate` belongs to **VersionService**, not token validation: POST `VERSION_API_URL + /validate`, with no body argument at the caller. Evidence 0x5f34b0 and HTTP post call 0x5f35a4.
- Logout in the recovered TokenService method is local: delete `username`, `access-token`, `refresh-token`, `url`, then CacheManager.clearAll. No revocation request is present in that method. The bundled guide's warning about fresh login data remains product documentation, not proof of server revocation. Evidence Android 0x6142f4–0x6143a0.
- Newer messaging `countUnread` uses **POST**, despite its read-like name. `markAsRead`, `delete` and `removeAttachment` also use POST. Omitted body becomes `jsonEncode(null)` through the shared wrapper, not an assumed absent body.

## Authentication and data-origin construction

Packaged production configuration gives `TOKEN_API_URL=https://swiadectwa.fryderyk.edu.pl/api/tokens` and `VERSION_API_URL=https://swiadectwa.fryderyk.edu.pl/api/version`. Android main reads TOKEN_API_URL at 0x8f41b4 and stores it in TokenService.field13 at 0x8f4208. Identify/re-identify load this field; these origins are therefore caller-linked configuration, not isolated URL strings.

| Operation | Method and URL | Body / result | Caller evidence |
|---|---|---|---|
| Enroll/login | POST `TOKEN_API_URL/identify` | JSON `{username,password,device}`; device is awaited Device.getName() | Android _identify 0x615ab4; keys 0x615bc8/0x615bd8/0x615bec; http.post 0x615c24. iOS corroborates at 0x28e7b0 and HTTP post 0x28e91c |
| Refresh identity | POST `TOKEN_API_URL/reIdentify` | JSON `{u:storedUsername,t:storedRefreshToken}` | Android _reIdentify 0x619b34; keys 0x619c34/0x619c48; http.post 0x619c84 |
| Minimum-version check | POST `VERSION_API_URL/validate` | No body supplied | Android VersionService.validate 0x5f34b0; HTTP post 0x5f35a4 |

All three send `Content-Type: application/json`, `Accept: application/json`, `App-Version: await AppHelper.getVersion()`. Identify returns envelope `data` containing `access_token`, `refresh_token`, and `url`; login stores them under `access-token`, `refresh-token`, `url`, and stores username. Refresh reads the saved username/refresh-token, calls reIdentify and rotates the token pair. `getAccessToken` checks expiry and may refresh. Verify the expiration margin/retry policy in a follow-up; do not assume synchronization is provided by the original code.

Academic data and messaging requests construct:

```
<stored response.data.url> + "/api/" + <resource path>
```

Headers are Content-Type/Accept JSON, Authorization `Bearer <getAccessToken()>`, and App-Version. The actual school/data origin cannot be known without an enrollment response, so do not hardcode the bootstrap hostname as the academic data host. Constrain discovered origins in Siberia and prevent credentials from crossing an unverified origin.

The shared response handlers decode `Response.body` to a JSON map, read boolean `success`, return `data` on success, and otherwise read `error.code`/`error.message`. On the error path status 426 raises UnsupportedException, 401 UnauthorizedException, otherwise CustomException, each with localized fallback if no server message. JSON decoding occurs first; do not equate every 200 response with success or discard structured errors. Evidence Android TokenService.handleResponse 0x615c88 and repeated service handlers; iOS shared handler 0x2a1258.

## Core request contracts recovered from Android

Each route below is relative to returned data origin + `/api/`. GET wrappers are traced to package:http.get; the absence write wrapper calls package:http.post after jsonEncode. Parameters named studentId are corroborated by repository/UI child context; preserve their provider type/identity.

| Method | Resource path | Return decoder | Evidence |
|---|---|---|---|
| GET | `users/getCurrent` | User.fromJson | UserService.getCurrent 0x618f1c / get 0x618f94 |
| GET | `grades/getOverview/{studentId}` | GradesOverview.fromJson | 0x6223dc |
| GET | `grades/list/{studentId}/10` | list of Grade.fromJson | 0x628278; fixed stored Smi 0x14 means integer 10 |
| GET | `attendances/getOverview/{studentId}` | AttendancesOverview.fromJson | 0x62169c |
| GET | `attendances/listAbsenceTypeChangeRequests/{studentId}` | list of AbsenceTypeChangeRequest.fromJson | 0x61d878 |
| GET | `lessons/listAtDay/{studentId}/{date}` | list of Lesson.fromJson | 0x625b58; date is DateFormat `y-MM-dd` |
| GET | `lessons/listWithAbsence/{studentId}/{limit}` | list of LessonWithAbsence.fromJson | 0x620408; null limit serializes 0 |
| GET | `homeworks/list/{studentId}/{limit}` | list of Homework.fromJson | 0x62422c; null limit serializes 0 |
| POST | `attendances/requestAbsenceTypeChange` | AbsenceTypeChangeRequest.fromJson | builder 0x65aaa8; HTTP post 0x65aeb8 |

Absence request body keys and construction:

```
{
  "id": <optional id passed by caller>,
  "student_id": <integer student id>,
  "start": <DateFormat("yyyy-MM-dd HH:mm:ss").format(start)>,
  "end": <DateFormat("yyyy-MM-dd HH:mm:ss").format(end)>,
  "absence_type": 3,
  "absence_reason": <reason>
}
```

The constant is raw tagged Smi 6 stored into the Dart map, therefore JSON integer 3. It maps to explainedAbsence in recovered enum objects. Do not send 6. The optional id is serialized as supplied, including null; do not silently omit it unless live server evidence permits that. The route supports the client's request workflow; it does not authorize direct attendance editing. Date formatting does not establish timezone/interval inclusivity; verify these using a controlled request and school context.

## Newer iOS messaging request contracts

All paths use returned origin + `/api/`. Native PCs below are original Mach-O addresses (also original file offsets); filename suffixes are instruction-image-relative and must not be substituted for PCs.

| Method | Resource path | Body / decoder | Caller evidence |
|---|---|---|---|
| GET | `messages/list/{folder}/{page}/8` with optional `?query={query}` | List of Message.fromJson | list 0x302094; path literal 0x3020e0; raw Smi0x10→8; suffix 0x30214c |
| GET | `messages/getRecipients` | List of MessageRecipient.fromJson | 0x327f54 |
| POST | `messages/countUnread` | shared wrapper encodes null; result integer | 0x3267dc; post wrapper call 0x326814 |
| POST | `messages/markAsRead/{messageId}` | shared wrapper encodes null; result ignored | 0x326b70; call 0x326be4 |
| POST | `messages/delete/{messageId}` | shared wrapper encodes null; result ignored | 0x3dc1d8; call 0x3dc24c |
| POST | `messages/removeAttachment/{attachmentId}` | shared wrapper encodes null; result ignored | 0x3de36c; call 0x3de3e0 |
| POST | `messages/create` plus optional `/{contextId}/{action.name}` | JSON body below; result Message.fromJson | 0x290cf4; post call 0x290e8c; decoder 0x290ed4 |
| multipart POST | `messages/uploadAttachment` | One part named `file`, filename basename of local path, content-type application/octet-stream; result integer attachment ID | uploadFile 0x3de870; MultipartRequest constructor 0x3df3a4 loads POST at 0x3df430; MultipartFile constructor loads file at 0x3df044 |

GET proof: list/getRecipients call wrapper 0x302248, then HTTP closure 0x3024a4, then BaseClient 0x3024e4 loads `GET` at 0x302504 before _sendUnstreamed. This removes the earlier GET_candidate uncertainty. POST proof: shared wrapper 0x2a1020 constructs URL/headers, jsonEncodes body at 0x2a1204 and calls package HTTP post at 0x2a121c. Thus read-like names do not determine verb.

Create body contains exactly these keys at the recovered map construction:

```
{
  "recipients": <recipient list>,
  "cc_recipients": <CC list>,
  "bcc_recipients": <BCC list>,
  "subject": <subject>,
  "content": <rich content>,
  "attachment_ids": <uploaded attachment IDs>
}
```

Evidence keys 0x290df8, 0x290e0c, 0x290e20, 0x290e34, 0x290e48, 0x290e5c. The optional suffix is appended only when both context arguments are nonnull. One is a context ID; the other reads uncompressed Enum.name at tagged field offset15. Reply/replyAll/forward labels exist, but the exact mapping of each compose UI action into that suffix still requires caller argument provenance. Do not invent a separate reply endpoint.

List uses an interpolated query string, not a verified URI queryParameters builder; encode user search text deliberately when implementing Siberia and test special characters. Folder values, initial page/index interpretation, empty-page termination and search threshold still need UI caller review/live fixtures. The raw fixed final path value is eight; do not assume it is a cursor or universal server maximum. Attachment size/count/extension policies remain unresolved; never substitute guessed limits. Delete soft/hard semantics and restore/permanent-delete support also remain unresolved.

## Decoder-owned schemas and provider enum codes

`android-model-constructors.json` contains 17 constructor-specific key sequences and parse calls, with native addresses. `ios-model-constructors.json` adds newer message constructors and precise load PCs/pool indices. These are now owned by real decoders, rather than guessed by neighboring strings. Full nullability/default branches are not yet exhaustively transcribed.

Representative constructor keys:

- Grade: text_value, numeric_value, weight, name, comment, created, subject_color, subject_name, subject_short_name. iOS adds weight-adjacent `value`/`factor` lookup branches; preserve both builds and inspect branch logic before assuming one schema.
- GradesOverview → semesters → semester{name,start,end,subjects} → subject{name,short_name,color,predicted_grade,final_grade,grades}.
- Attendance overview: year/months; period{firstDayOfPeriod,lastDayOfPeriod,attendancePercentage,lessonsWithExplainedCount,lessonsWithExcusedCount,lessonsWithLateCount}.
- Lesson: name,short_name,original_name,original_short_name,primary_description,secondary_description,room,color,absence_type,is_substitution,substitution_type,is_remote,remote_link,teachers,exams,accompaniments,absence_type_change_request,start,end. Accompaniment{subject,accompanist,start,end}; exam{description,start,end}; teacher{id,full_name}.
- Homework: id,subject,publish_date,finish_date,teacher,content,attachments; attachment{name,url}; subject{name,short_name,color}; teacher{id,full_name}. Status display enum exists, but a task submission API is still not recovered.
- User: id,role,first_name,last_name,students. Nested student map structure remains a follow-up; do not make a fictitious Student.fromJson from these five keys.
- Message: id,subject,content,sent_date,sender,recipients_v2,cc_recipients_v2,bcc_recipients_v2,is_read,is_replied,is_deleted,tags,attachments. Sender{key,name}; recipient{key,name,role}; attachment{id,name,url}; tag{id,name,color}. Sending uses recipients/cc_recipients/bcc_recipients keys, while decoding reads the corresponding v2 response lists.

Recovered enum objects and custom provider-code fields are in contracts.json. AbsenceType codes are 0 unknown,1 present,2 absence,3 explainedAbsence,4 notExcused,5 late,6 outEarlier,7 otherPresent,8 otherAbsence. SubstitutionType **custom codes differ from enum indices**: 1 canceled,2 replaced,3 ignored,4 inCommonRoom,5 lookAfter. fromTypeCode matches the custom field, not the ordinal. HomeworkSubmissionStatus enum objects are ordinal 0 `uncompleted` (awaiting solution),1 `sent` (sent to teacher),2 `accepted` (accepted by teacher); caller wire-code mapping still requires constructor branch review if provider_code is absent. Always preserve unknown codes.

## Validation and artifact boundaries

- Android `android-native-validation.json` supplied by root checks service BL/direct PP loads against original ELF bytes.
- iOS `ios-native-validation.json`: 38 selected auth/message/model/wrapper functions; 3,613 raw native instructions checked; 408 direct BL targets decoded; 48 direct PP indices checked; 134 string-reference occurrences matched original object payload bytes; zero mismatches. Canonical string parsing processed 38,482 of 38,483 objects, with one oversized framework string skipped by the defensive 10,000-character bound. It is not used by recovered contracts.
- The parser initially needed build-specific ROData corrections: class ID shift12,16-byte delta units applied before each object relative to image base. More importantly, its annotations ignored the 16-byte ObjectPool header, producing pool indices **two too high**. Do not cite `meta`/`meta-named` PP comments. Only `corrected-asm` and independently verified payload mappings are used here.
- The ELF carrier is an analysis envelope, not a rebuilt app: original iOS Mach-O bytes are copied untouched at carrier file offset+0x1000; virtual addresses remain original. `carrier-provenance.json` records hashes and boundaries. It is never executed. Prefix-based Android assumptions are not used to change the underlying iOS snapshot features.
- Static caller evidence supports an implementation and synthetic fixtures, but does not establish today's server acceptance, account permissions, academic data origin, real error payload variants or all date/nullability behavior. Keep live capability verification explicit. No application binary/raw third-party assembly should be published from this research tree.

The remaining work is now bounded: collect one authorized enrollment response for dynamic origin and redacted fixtures; verify nested child schema and nullability; trace messaging folder/page/action UI arguments and attachment limits; validate controlled absence/message writes and delete semantics; determine real push registration. No additional tool installation is needed to start implementing these static contracts.
