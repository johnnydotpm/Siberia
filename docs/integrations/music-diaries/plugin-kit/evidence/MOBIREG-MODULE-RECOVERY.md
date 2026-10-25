# Modern MobiReg: recovered mailbox and homework request contracts

This is **new local research**, not committed or pushed. It supersedes the earlier string-only uncertainty for the specific request builders below. Target: Android 3.1.7/build116/revision `6f4e7b8`, ARM64 `libapp.so` SHA-256 `22dd67993cd25ccb0a56fca7eef87ffc1d40cc1bffd9057b671c7268afc4d97a`.

Method, URL concatenation, map writes and underlying HTTP helper calls were traced in named ARM64 output from Blutter PR213 (`c1caafecd233ea17c3f4b6b5ff8847d59478b979`) linked to Dart3.13.2. r2flutter independently recovered matching method entrypoints from all843 parsed snapshot clusters. No service was contacted. **Static client behavior is now substantially recovered; server acceptance, role permissions and real response examples remain untested.**

The original binary remains authoritative. Raw per-library assembly/object dumps stay in `blutter-android/`. The authored machine-readable ledger is `modern-module-contracts.json`; every operation records the request-builder entrypoint and assembly file hash. Named anonymous closure inference has limitations in the experimental Blutter branch, so confirm branch targets/actual instructions rather than trusting a closure's displayed owner alone.

## Mailbox uses its own module cookie

`MailApi._authHeaders` at `0x480fa0` creates JSON `Content-Type`/`Accept`, adds source `User-Agent: MobiReg/3.1.7 (6f4e7b8)`, then calls `MailSession.ensureAuthenticated`/`getAuthHeaders`. `MailSession.getAuthHeaders` at `0x481070` supplies **Cookie**. It does not simply attach the main gateway's bearer token.

`MailSession._performSso` at `0x47fe74` obtains `AppConfig.getMessagingUrl`, `getSchoolCode`, `getMessagesToken`, then constructs:

```text
GET {messaging_url}/{school_code}/{Uri.encodeComponent(messages_token)}
Accept: text/html
User-Agent: MobiReg/3.1.7 (6f4e7b8)
```

Construction is at `0x47ff78–0x47ffdc`; request dispatch `HttpClient.getUrl` at `0x480050`. The source sets the request's `followRedirects` field false at `0x480078–0x48007c`, then gathers response cookies. Cookie extraction at `0x480670` / callback `0x480710` selects `set-cookie` case-insensitively, strips attributes after the first semicolon per cookie and joins cookie pairs with `; `. Success depends on a nonempty gathered cookie; do not require HTTP200 before collecting a302 SSO response's cookie. Cookies are persisted via AccountsStore, cleared on forced reauthentication and switched with account context.

Mailbox SSO uses the selected account's `messaging_url` field (`AppConfig.getMessagingUrl` at `0x45ad28`, reads account field0x33). **API origin normalization is separate:** `MailRepository._server0x45ac98` removes one exact trailing `/sso` from that configured URL (`0x45acdc–0x45ad10`), otherwise retains it. In the matrix `{M}` means this normalized API base, while the SSO formula above uses the original configured messaging_url. Do not append `/api/messages` to a raw URL ending `/sso`. Retain other legitimate base paths and do not replace the value with the diary host or a universal hardcoded mailbox domain.

Mailbox helper `_request` at `0x47fd30` invokes the operation, and if it returnsnull forces SSO and retries the closure once. `_decodeOrThrow` at `0x480dec` returnsnull on **401/403**, accepts other **2xx**, returns true for an empty successful body, otherwise JSON-decodes the body; non-2xx becomes a classified error. JSON HTTP helpers use a15-second timeout: PP`0x2020` is Duration with15,000,000 microseconds and is passed to `_Future.timeout` (e.g.`0x480db8–0x480dc4`). Multipart send follows a separate path, so that timeout must not be assumed for uploads. This retry wrapper also surrounds writes in the source. Siberia must distinguish safe confirmed-auth failures from uncertain mutation outcomes before replaying a send.

## Mailbox operation matrix

All ordinary JSON operations use the mailbox cookie headers above unless noted.

| Operation | Recovered verb/path | Body and source |
|---|---|---|
| Inbox | `POST {M}/api/messages/inbox` | `limit:20`, `skip:<offset>`, optional nonempty `query`; closure`0x481844` |
| Sent | `POST {M}/api/messages/sent` | Same;`0x481650` |
| Important | `POST {M}/api/messages/important` | Same;`0x48145c` |
| Trash | `POST {M}/api/messages/trash` | Same;`0x480bd8` |
| Read/detail | `GET {M}/api/messages/read/{id}` | No body;`0x481e78`, `_get`→HTTPget`0x481fa8` |
| Send/reply | `PUT {M}/api/messages` | `title`, `content`, `odbiorcy:[string IDs]`, optional non-null `previousMessageId`;`0x773aa4`→`_put`→HTTPput`0x773cac` |
| File on sent message | `POST {M}/api/messages/{id}/files` | Multipart binary part **`files`**, caller-provided filename;`0x774034` |
| Recipient directory | `POST {M}/api/messages/receivers` | `{}`;`0x7bc014` |
| Recipient type | Same `POST` path | `{type:<category>}`;`0x7782d8` |
| Search recipients | `POST {M}/api/messages/receivers/search` | `{query:<text>,ids:<caller list>}`;`0x776998` |
| Delete/trash | `DELETE {M}/api/messages/{id}` | No body;`0x77a8b8`→`_delete`→HTTPdelete`0x77a9e8` |
| Star/important toggle | `POST {M}/api/messages/{id}/stared` | `{}`;`0x77ae98` (the spelling is **stared**) |
| Restore | `POST {M}/api/messages/{id}/restore` | `{}`;`0x7fa078` |
| Unread count | `POST {M}/api/unreadMessages` | Separate direct call, JSON `{school:<schoolCode>,messagesToken:<moduleToken>}`;`0x45ae84` |

The unread call uses JSON headers and User-Agent directly, not `_authHeaders`. It requires HTTP200, trims body and tries integer parsing; source falls back to0 for unparseable text. Treat malformed count responses explicitly rather than silently asserting the user has no unread messages.

**Tagged integer trap:** in folder builders `mov x3,#0x28` is a Dart tagged Smi40 representing **integer20**, not wire limit40. This was verified at the map insertion `0x480c74–0x480c78`; all four folder builders use the same tagged literal. Keep raw instruction/immediate versus language value distinct.

Sending returns Map `id` typed int-or-null (`sendMessage0x773938`). The body is sent **before** attachments. Each attachment uploads against the returned messageID. `uploadFile0x774034` accepts exactly HTTP200 and returnsfalse on exceptions. A body can therefore be sent successfully while one or more attachments fail; do not retry the whole message as if nothing was delivered.

`MailRecipient.fromJson0x776704` reads `id`, `name`, `role`, with `_type` fallback. The normalizer at `0x7768f0` tests `^\d+$`; numeric IDs gain the `user_` prefix while nonnumeric IDs are retained. Trace category-specific receiver data before mapping every identifier to an integer. This is a concrete incompatibility with Siberia's current numeric-only recipient model.

`MailProvider` folder decoder`0x47dc80` explicitly reads **items** and **total**; load-more`0x7f7f28` reads the same keys. These are real folder response envelope fields, not a main-API `ApiEnvelope` wrapper.

Mailbox model decoder ownership is now established: `MailMessage.fromJson0x47df60` reads `id`, `subject`, `content`, `author`, `recipients`, `files`, `date`, `read_at`, `stared`, `trashed`, `previous`. The send key is **title** while the response model reads **subject**. `MailAttachment.fromJson0x47f16c` reads `id`, `name`, `size`, `url`, `extension`; author/recipient models read their own nested keys. These are constructor-key observations, not a claim that all fields are mandatory or all JSON scalar coercions have been recovered.

## Homework module session

Homework uses a separate `ModuleSession`, named `ZADANIA` with persistence key `homeworkCookie`, instantiated at`0x496b98`. Its URL builder closure`0x496bf4` obtains module origin/school/token and constructs:

```text
GET {homework_module_base}/{school_code}/account/ssov2/{Uri.encodeComponent(messages_token)}
```

This builder calls `Uri.encodeComponent` at`0x496d3c`, and obtains the same AppConfig messages token at`0x496c78`. It uses selected account field0x3f, identified as persisted `homeworksUrl` (`Account` encoder`0x45a960–0x45a968`), rather than the mailbox URL. `ModuleSession._performSso0x496204` similarly opens an HTML GET and extracts cookies; `getAuthHeaders0x497700` supplies **Cookie**. Keep cookies scoped independently from mailbox and main API authentication.

`HomeworksApi._request0x495f4c` ensures that session, invokes a request, forces reauthentication and retries once on null, then rejects a second null. `_send0x496ecc` adds JSON headers/User-Agent and module Cookie. It explicitly dispatches **POST**, **PATCH**, otherwise GET, with 401/**419** returningnull. Unlike mail's generic2xx acceptance, homework `_send` requires **HTTP200**; empty successful body yields `{}`, nonempty body JSON-decodes, malformed JSON returnsnull in the source. A new client should not misclassify malformed-success JSON as an ordinary expired-session signal.

| Operation | Recovered contract | Evidence |
|---|---|---|
| Table/list | `POST {H}/api/homeworks/datatable` JSON `{listFilter:"active"|"archive", sortInfo:{prop:"deadline_at",order:"ascending"}}` | Closure`0x496d80`; `_send` call`0x496eb4` |
| Detail | `GET {H}/api/homeworks/{id}?student={pupilId}` | `show0x7643c0` builds query; closure`0x764544` joins base/id/suffix |
| Submit solution | `PATCH {H}/api/homeworks/{id}` JSON `{content:<text>,files:<caller structure>,student:<pupilId>}` | Closure`0x7656e0`, keyed map writes`0x76578c–0x7657c0` |
| Upload solution file | `POST {H}/api/homeworks/{id}/files` multipart **files** binary part plus text **student** field | Closure`0x765eac`; pupil stringify`0x766114`, field write`0x766120`; HTTP200→true,401/419→null |
| Toggle archive/restore | `PATCH {H}/api/homeworks/{id}/archive` JSON `{}` | Closure`0x768ddc`; passesnull, `_send` substitutes empty map before JSON encoding |

Multipart method/part names are proven through the specialized dependency constructors: `MultipartRequest0x766c10` sets POST at`0x766ca0`; `MultipartFile0x766894` sets field **files** at`0x7668a4`. This avoids guessing the part name from the higher-level caller where it is optimized away. Client upload success does not establish upload IDs, server limits or whether another confirmation step is required beyond the recovered solution save action.

`HomeworkDetail.fromJson0x763744` reads teacher comments, teacher, content, groups, files, status and solution. `HomeworkSolution.fromJson0x763d68` reads content, sent_at and files. `HomeworkFile.fromJson0x76403c` reads id,name,extension,url,size,sender. `Homework.fromModuleJson0x49527c` reads deadline_at,studentIds,teacher_comments,statuses,id,subject,title,created_at,student,status,archived; `fromDiaryJson0x4943f4` reads dateTime,addedTime,id,subjectId,subjectName,title,description,teacherId. Keep module/diary source types distinct. Detailed key ownership is retained in `homework-decoder-key-ownership.json` and `module-model-key-ownership.json`. `HomeworksRepository` module list decoder`0x494d94` reads the **data** field; diary list decoder`0x493918` reads **teachers** and **items**. This reinforces the need for distinct source decoders.

## Attachment downloads are distinct transport paths

Two additional dynamicURL operations are in the21-operation ledger. Mail `_AttachmentTileState._pobierzDoTemp0x781144` ensures mailbox authentication, reads `MailAttachment.url`, and performs GET with Cookie headers (`0x7811a4–0x7811bc`); HTTP200 bytes are written to a temporary file. Homework `_FileTileState._open0x79acf0` reads `HomeworkFile.url` and calls GET **without an explicit header map** (`0x79ad78–0x79ad84`). On401/403 it invokes the parent detail-refresh callback and asks the user to retry; on200 it writes a temporary file and opens it. Do not forward cookies/JWT to a homework attachmentURL simply because mail downloads need cookies. The authorization embedded in an attachmentURL remains sensitive and must not be logged.

## What still needs evidence

- Server-side policy and per-school role permissions, concrete envelopes/pagination responses, accepted recipient categories and complete field coercions.
- Exact file constraints and solution files JSON schema; dynamic attachment URL renewal is separate from upload paths.
- Whether delete is reversible soft delete for every role/server, and archive toggle idempotency.
- Main API discovery/envelope/token contract: see the independently traced auth/gateway report. A recovered endpoint suffix does not authorize constructing arbitrary authenticated origins.
- Original-app runtime comparison with authorized test accounts. No messages, files, justifications, votes or homework answers were sent during this research.

## Instruction integrity check

`validate_native_contract_evidence.py` independently read the original ELF load segments and checked **3,086** direct BL targets and direct64-bit LDR/PP offsets across module/session/auth/gateway/justification/poll sources and multipart dependencies. All21 request-builder entrypoints also match the separate r2flutter instruction-table inventory. This verifies code locations and annotations used here; it is not a validation of every high-level decompiler inference or backend behavior.
