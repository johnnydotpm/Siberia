# Prymus protocol and feature workflows

These are bounded static contracts from the supplied1.2.68 APK. [operations.json](operations.json) is the exact Retrofit declaration ledger. [AUTH-AND-TRANSPORT](AUTH-AND-TRANSPORT.md) supplies token/signing/origin rules. A method declared in SchoolService is a request recipe, not proof every account can use it. No live server responses were captured.

## Full snapshot and identity

`GET pobierzDaneUcznia` returns `network.ApiResponse`, not a generic `data` envelope. `ExternalId` identifies the pupil; `UserId` is chat/user identity; `ActualSchoolYear` and `ActualTermShortcut` scope the current academic period. It additionally carries first/last name, school/class, sex, diary number, login, license, expiration/reset/payment information and account flags. Keep the full source DTO separate from Siberia's normalized profile. Do not send a local Room auto-increment ID to the server.

Returned module keys consumed by the app include:

| Key | Role |
|---|---|
|`Marks`,`MarkAverage`,`MarkFinal`,`MarksResults`|Individual marks, school-supplied averages/final assessments and class histogram counts |
|`Attendance`,`AttendanceStatistics`|Individual absence/late records and server-supplied percentage strings |
|`Timetable`,`Lessons`,`Replacements`|Schedule, lesson details and substitution/replacement information |
|`Tasks`,`TaskAnswers`|Homework/task assignments, attachments and response history |
|`Remarks`,`ScoringRemarks`|Teacher remarks and point-based behavior records |
|`News`,`Announcements`|Events/notices and linked content |
|`Messages`,`ParentsMessages`,`Chats`,`ParentsChats`|Message JSON and conversation metadata by student/parent context |
|`ChatSettings`,`ChatTeachersIds`,`Teacher`,`Parents`|Broker credentials, routing identities, teacher and parent reference data |
|`SchoolInformation`,`Books`,`FAQ`|School details, library/book information and help material |
|`BehaviorActualPoints`,`BehaviorStartingPoints`,`LuckyNumber`|Behavior point totals and lucky-number display |
|`system_message`|A service/version/device/account message, not a populated snapshot |

`ApiResponse` field declarations and annotation spelling are in the model ledger. Many arrays are nullable. The source importer conditionally inserts only non-null arrays after deleting stored records for the pupil/year. A future adapter must decide explicit coverage before replacement: missing module, empty authoritative module and failed parsing are different. Do not clear all cached modules after a partial/malformed response merely because the old client resets tables.

The native source deletes/imports many Room tables around updates; no general backend delta cursor or module-specific read API was recovered in the17 SchoolService routes. The periodic snapshot is broad; fetching grades does not imply a grades-only response. Reusing one parsed snapshot for several module projections needs an approved host batching/cache lifecycle; do not assume successive sandbox VM invocations retain memory.

## Main request recipes

All POST fields below are URL-encoded form fields. JSON-looking values are JSON strings inside form values unless otherwise stated. The primary base is the configured `/api/` origin. `securityToken` is the freshly derived hourly authenticator.

| Method/path | Exact fields and intent |
|---|---|
|GET`pobierzDaneUcznia`|token,securityToken,mobileId,ver,fcm_token,apiVersion; full snapshot/device context |
|GET`pobierzPogode`|token,securityToken; weather display, independent raw response |
|POST`trybRodzica`|token,securityToken,mobileId,activationCode,type,apiVersion; parent-mode action |
|POST`wyczyscUrzadzenia2`|token,securityToken,mobileId; explicit device reset |
|POST`ustawFcmToken`|mobileId,fcm_token,apiVersion; push registration |
|POST`aktualizujTokenyUrzadzenia`|tokens,securityToken,mobileId,rodzic,premium; device association |
|POST`wyslijStatusOdczytane`|object_id,type,token,securityToken,readDate; one read acknowledgement |
|POST`wyslijStatusOdczytaneWiele`|token,securityToken,read,apiVersion; JSON-string collection of read receipts |
|POST`wyslijDane`|token,securityToken,json,type; polymorphic payload dispatch101/102/103 |
|POST`stworzGrupeChatUczenNaucz`|token,securityToken,uczenId,nauczId; create teacher conversation |
|POST`przeczytajChatUczen`|token,securityToken,userId,topic; conversation read acknowledgement |
|POST`wyslijWiadomoscChatUczen`|token,securityToken,userId,message,topic,attachment,fromParent; older/topic chat send |
|POST`wyslijOdpowiedz`|task_id,message,token,securityToken,apiVersion, repeated attachments[],fileNames[],extensions[]; task reply |
|POST`zmienLicencjeDlaTokenow`|token,securityToken,tokensToUpgrade,paymentDate,license; commercial license association |
|POST`zaktualizujLicencjePremiumDlaTokenowPowiazanych`|token,securityToken,tokensToUpgrade,mobileId; related license update |
|POST`zglosProblem`|token,securityToken,userReport; explicit support report |
|POST`wyslijLogiAplikacjiMobilnej`|token,securityToken,mobileId,tokens,logs; diagnostic upload |

Commercial, reset, support and diagnostic calls are inventoried for completeness. They are not mandatory background actions for diary reads. Avoid sending vendor logs or payment/receipt claims as an interoperability shortcut. Legacy compatibility routes and modern communication-module routes coexist; a UI label is not evidence to substitute one for another.

## Polymorphic `wyslijDane`

### Type101: justification

Inner JSON uses `JustifyAttendanceModel`: `id_ucznia`=student.chatId, `data_wyslania`=display timestamp, `data_nb`=absence date plus day label, `godz_lekc`=selected time intervals, `frekw_id`=**JSON-array string of attendance ExternalIds**, `uspr`=reason. This is not Librus's lesson-number payload. Full UI/ordering/failure details are in [STATS-JUSTIFICATIONS](STATS-JUSTIFICATIONS.md).

### Type102: communication-module compose

`models/requests/CommunicationModuleMessage` is serialized by Gson. Fields: `recipientId`, integer`chatType`, `title`, `content`, `attachments`, `fileNames`, `extensions`, optional`topicUuid`, optional`parentId`. The default Gson serializer omits null fields; empty lists remain lists.

`ChatTypes.NEW_GROUP_WITH_TEACHER=0`, `EXISTING_GROUP=1`. The UI receiver key is parsed with split`":"`,limit2. Existing groups use the receiver/topic identity and omit topicUuid when null. A new teacher conversation creates a random UUID, attempts MQTT subscription, then includes that UUID. Parent mode sets parentId; student mode sets null. Do not invent a subject/pupil integer address format from the visible recipient label.

Files in this path are read as raw bytes and Base64 encoded with Android flag2 (NO_WRAP). `fileNames` uses name without extension; `extensions` is parallel. These are inner JSON arrays, not multipart. Preserve identical order and cardinality across all three lists. A file read failure must not silently pair another file's name and bytes. Bulk JADX contains duplicated close/throw control-flow warnings in this helper, so exact exceptional cleanup is qualified; the explicit Base64 call/field ownership is the recovered serialization fact.

Successful existing-group sending checks that raw response body contains substring`true`. New-group sending parses `ResponseMessageModel`, requires a topic and chat message, then inserts them unless the topic already exists. A new adapter should retain the exact observed response family while validating structured success; substring membership alone is not a reliable Boolean protocol. Missing/invalid response after a transmitted request is uncertain, not permission to send the message again.

### Type103: parent read receipt

Inner JSON fields are `parentId`,`readDate`,`objectId`. This is used in parent mode. Student receipts use `wyslijStatusOdczytane` with type`Chat_Wiadomosc` instead. Reading/updating a local badge and server acknowledgement remain separate operations. Failed acknowledgements should be queued/retried by owner without resending the original user message.

## Older topic chat and MQTT

Returned `ChatSettings` has BrokerLogin/BrokerPassword. ChatService connects over TLS on8883, sets returned credentials, subscribes at QoS1 to login/topic UUID and parses incoming messages into `MessageJson`. It reconnects with bounded retry state and throttles diagnostic reports. Snapshot `Messages` and `ParentsMessages` use JSON objects further normalized by the app; message body/attachment properties must be preserved before deriving a flat inbox item.

`MessageJson` annotated fields include `id_uzytkownika`,`imie`,`nazwisko`,`wiadomosc`,`tytul`,`zalaczniki`,`externalId`,`recipient`. `ChatMessage.ChatAttachment` includes a URL field (annotation constant resolves to`url`). Broker message delivery and HTTP send success are distinct confirmations. QoS1 permits duplicate deliveries; deduplicate by source-scoped message identity before notifications. A parent conversation must not enter a pupil's unrelated thread when the active profile changes.

MQTT is a host capability gap for the current sandbox SDK, not an HTTP route to guess. Snapshot polling can provide supported refresh behavior if confirmed; its semantics and freshness should be stated rather than advertised as realtime chat parity.

## Tasks/homework replies and file transport

Task replies use `wyslijOdpowiedz`, a form POST with repeated-array keys `attachments[]`,`fileNames[]`,`extensions[]`. In the inspected TaskReplyVM, selected URIs are decoded into Bitmaps, recompressed JPEG quality100 and Base64 encoded with Android flag0 (default, potentially line-wrapped). This is **different from** communication-module raw-file NO_WRAP encoding. The filename/extension metadata is collected separately from MyFile; a new adapter must avoid claiming arbitrary binary fidelity for this image-oriented path.

The native callback treats any successful HTTP status as initial reply success, then parses attachment response, updates task/reply history and local state. A failed follow-up/detail decode can leave a partially completed server action. `validateAttachments` returns empty body unchanged; otherwise it Gson-decodes a String and strips quote characters. Exact server errors and arbitrary-file acceptance require controlled tests. Do not invent a multipart upload because the feature is called attachments.

Returned Tasks/TaskAnswers preserve teacher, title, contents, due/reply dates, attachment links and answer history. Opening a task, local seen flags and a server read receipt differ. Keep local completion state and confirmed server response state separate, and scope them by token owner+pupil+task ID.

## Read state, cache and notifications

The app keeps local tables such as MarkRead,TasksRead,AnnouncementRead,RemarkRead and ReadNotSendedObject. Some read marks are local only; other modules post receipt type strings such as Ogloszenia,Zadania,Uwagi,Chat_Wiadomosc. Use the exact caller's type string and date formatter. A snapshot refresh must not erase unsent read receipts or new-item deduplication state.

FCM broadcasts select student/object/module using IntentNotification and snapshot data. New-message push registration is not evidence that Siberia's own FCM project is accepted by the server. Local scheduled reminders, theme/language, favorites, local notes, QR export and helper/premium UI are local/platform features with their own data-retention choices. Map them to Siberia conventions rather than copying vendor assets.

## Error and replay policy

Keep transport timeout/TLS failure, invalid JSON, system message, account/device limit, unsupported app/API version, denied capability, successful empty data and business rejection separate. Source code sometimes logs secrets, retries snapshots against an IP, stores a justification before sending, or tests raw substring`true`. Those are observed compatibility/edge behaviors, not recommendations to reproduce them.

Use immutable owner/data scope and selection generation around every awaited operation. Preserve the last valid module on a partial failure; do not report successful sync just because a timestamp advanced. A snapshot is broad and can contain personal data from several module families: do not log its body or persist it in insecure auth state as a workaround for SDK size limits.

For a mutation timeout after transmission, surface uncertain state and reconcile the snapshot/known ID before a deliberate retry. No general idempotency key or backend duplicate-suppression guarantee was recovered. License/reset/report/notification/history actions each need their own effect policy. HTTP GET alone does not prove effect-free behavior because the snapshot includes registration parameters.
