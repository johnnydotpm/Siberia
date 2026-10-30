# Module workflows, caller payloads and cache effects

These are static client contracts from shipped8.4.1 source maps. Original `src/...` paths are evidence locators. Exact source hashes and line anchors for these workflows are in [workflow-evidence.json](workflow-evidence.json). API origins, transport headers and the complete function catalogue are defined by the parent Librus specification. Examples here are synthetic and must not be submitted to real accounts without an authorized test action.

## Read pipeline and dependency failures

The original application separates raw REST modules, builder joins and Vuex-ORM viewmodels. API success is only the first stage. Grades need subject, user, category, average and comment lookups; attendance needs type, lesson, user and subject; homework needs teacher and lesson/virtual-class subject; messages need sender/recipient users; calendar joins several module families. Return structured module outcomes with missing-dependency metadata instead of dropping source records.

`src/helpers/promise-helper.js` implements `afterAllAlways`: each rejected promise becomes a resolved Error value. Several builders replace Error values with empty arrays; others assume success after the same helper. This is partial-join behavior, not guaranteed all-or-nothing sync. A future adapter should identify the failed dependency, retain prior complete display data where appropriate and never advertise failure-induced emptiness as an authoritative server list.

Offline ORM restoration deliberately retains new code defaults when older persisted state lacks a key, and never restores code-owned `relatedKeys` from storage. Apply the same principle to migrations: data restores cannot freeze an old schema's relationship inventory or overwrite newly introduced defaults with undefined. Scoped profile migrations still need their own transactional design.

## Grades

`grades-builder.js/getGradesViewModel` first retrieves raw grades. With zero grades it still fetches subjects and creates subject containers. Otherwise deduplicate subject/teacher/category/comment references; use per-subject averages when only one subject is referenced, otherwise all averages. Comments are joined by comment IDs; resit relationships link records by `Resit.Id`. Source builder tolerates some dependency failures but may dereference a missing subject; a robust implementation should not crash or fabricate a subject.

Use separate parsers and cache namespaces for standard/point/text/descriptive/partial descriptive/behaviour/GO grades. Changing a grade category can alter weight, average inclusion and final/proposed status, so invalidation must include affected normalized grades and calculations. Preserve server averages separately from a local estimate. Never use original zero fallbacks as proof of a0 average.

## Attendance and justifications

Attendance display excludes standard type100 through both direct and custom-type mapping paths. Dates and lesson-number display are different from the raw lesson ID. Sending a justification uses lesson **numbers**, not `Lesson.Id` values.

Caller `src/pages/main-pages/justifications-page/components/NewJustificationView.vue/sendJustification` builds one of two JSON maps for `POST /Justifications`:

```json
{"messageFromParent":"Synthetic reason","lessons":[],"dateFrom":"2026-11-02","dateTo":"2026-11-03","sendNotify":false}
```

```json
{"messageFromParent":"Synthetic reason","lessons":[1,3],"dateFrom":"2026-11-02","dateTo":"2026-11-02","sendNotify":true}
```

First is chosen days; second is chosen lessons. Dates are `YYYY-MM-DD`; chosen lesson values pass through integer parsing. `sendNotify` is the user's notification choice only when now is same-or-before the relevant end day; otherwise it is false. This is the original UI policy, not proof the server rejects a different value. Body text is not renamed to `reason`, and no `student_id` is added by this builder.

The justifications store calls POST, reads response `Id`, then loads that record through its detail builder before updating last-change state. Treat a confirmed POST followed by failed detail fetch as confirmed submission with stale display, not as permission to repost. Availability is account-specific. Original store infers unavailable from error-message text containing403 and uses a module-global availability promise; a future implementation should use typed HTTP errors and per-owner single-flight checks to avoid collisions across schools.

List date range is derived from school year end: September1 of previous calendar year through end-year date. Original missing-date fallbacks can span2000-09-01 to2999-01-01; do not adopt an enormous fallback range without a deliberate bounds policy.

## Homework read, done and answer upload

Raw read and done operations are distinct:

| Action | Request | Success consumer | Local effects |
|---|---|---|---|
| Mark read | POST `/HomeWorkAssignments/MarkAsRead`, JSON `{homework: id}` | `Status==='OK'` | Set `MarkedAsRead=true` for matching account+ID; persist; update event-feed copies |
| Mark done | POST `/HomeWorkAssignments/MarkAsDone`, JSON `{homework: id}` | `Status==='OK'` | Set `MarkedAsDone=true`; persist; update event-feed copies |
| Local seen | no request in store | none | Set local `IsNew=false` only |
| Send/replace answer file | POST `/HomeWorkAssignments/AnswerAttachment/{id}`, multipart | response.data returned | Refetch homework detail; replace `StudentAnswerSend` from returned model |

The answer part is named **`attachedFile`**, with the selected file object and its filename; `sendFile:true` bypasses the JSON serialization helper. Do not send JSON around the binary, use the mail module's part name, or invent a separate text-answer endpoint.

Original UI exposes file sending for student accounts. It requires `SendFilePossible`, a due date not before today's day, and if answer state exists, `StudentAnswerSend.count < StudentAnswerSend.max`. `MustSendAttachFile` controls requirement/status presentation; it is not the entire eligibility check. Parent accounts can see that an answer was sent from a student's account without gaining upload capability.

Before upload, original UI retrieves file-transfer restrictions. Missing restrictions or `upload===true` blocks upload; `upload_3g===false` permits slower mobile network types in its network policy. No connection blocks it. These inverse-looking booleans are observed policy, not a spelling correction. Network-speed and device checks are app policy, while server403 still needs a permission/restriction result.

After upload, a failed detail refresh still calls the success callback with the confirmed upload result. Retain this partial outcome. Original mark-read action eventually returns string`success` even when business Status was notOK; a future adapter must not mirror that false-success behavior. Mark-done returns success/error differently, so a common “HTTP returned means done” wrapper is incorrect.

## Synergia mailbox

### Pagination and incremental reads

`getMessages` uses limit300, starts page1, and continues while the latest page contains exactly300 messages. `afterId` is a separate incremental ID cursor supplied by caller. It is not a page offset. Folder filters are exact strings such as `&getAllTypes=1`, `&inSended=1`, `&inTrash=1`, and combined sent+trash. List has `alternativeBody=true&changeNewLine=1`.

Store cursor starts1 when no valid stored highest ID exists. New page batches update cursor to highest message ID. Received and sent have separate dirty/cursor state. Fetch-by-ID through the change path can request all four folder combinations starting at IDminus1, then filter the exact target. Do not replace this caller with a guessed folder-neutral detail semantic without verifying behavior.

The store helper sorts then accesses element0, so an empty new batch can throw. In a force-update path the catch returns cached rows. A future adapter should handle a successful empty delta without exception and retain cursor. Bound pagination and detect duplicate/non-progressing pages; these protections are proposed, not observed.

### Compose and reply caller maps

`SendMessageView.vue/sendMessage` sends plain subject/body strings; it does **not** JSON-stringify these individual fields. The network helper serializes the full map once.

```json
{"subject":"Synthetic subject","body":"First line\nSecond line","receivers":["example-recipient-1","example-recipient-2"]}
```

Reply uses a different map and omits receivers:

```json
{"subject":"Re: Synthetic subject","body":"Synthetic reply","originalMessageId":"example-message-9"}
```

`originalMessageId!==null` selects the reply branch. Do not include both maps just because the UI already knows recipients. Original UI validates at least one selected recipient, nonempty subject and nonempty body before confirmation; reply recipient picker is restricted. Recipients' availability/out-of-work state can trigger a confirmation and school-provided message. This does not imply a server prohibition against off-duty recipients.

POST returns `response.data.Message`, whose `Id` is refetched through the detail action before UI reports completion. A failed fetch after successful send is an uncertain display result; do not retry send automatically. Preserve the confirmed server ID.

### Delete, pin and local copies

Deletion is PUT `/Messages/{id}` JSON `{action:'delete'}`, then local model gets Deleted=true and its trash state updated. It does not establish a permanent HTTP DELETE operation. Pin is PUT with action`pin` or`unpin`; response Message.isPinned updates ORM and event-feed copies. Original store also recognizes exact server messages `Message already pinned.` and `Message already unpinned.` as state reconciliation. Keep these special cases narrowly scoped; do not treat every409 as success.

Unread count, original ReadDates, local IsNew and server side effects must remain distinct. The builders do not prove that merely opening any list row acknowledges it. Verify the relevant detail/open caller before exposing mark-read behavior. Attachments are retrieved through a dedicated metadata/URL operation; no generic message-attachment composer upload was established by this reviewed send caller.

## LibrusGO mailbox

GO list uses offset pagination with limit100 and response `pagination.total`, unlike Synergia's page300/afterId. Original loop stops only at exact count equality. Add empty-page/nonprogress/total-change bounds in a future adapter, preserving partial results on failure.

GO composer escapes `& < > double-quote single-quote`, then changes body newlines to `<br>`. It sends:

```json
{"subject":"Synthetic &amp; subject","content":"Line 1<br>Line 2","recipients":[{"id":"example-go-recipient","type":"example-type"}]}
```

Recipient `type` is supplied by selected recipient data; do not guess all recipients are teachers. POST outbox returns `response.data.id`, then detail is fetched. Received mark-read is a separate PATCH `/messages/inbox/{id}/read`. GO recipients lack Synergia's availabilityStatus in this UI path. Error409 opens conflict handling; `errors.subject[0]==='VALIDATION.TOO_LONG'` maps to UI maximum100characters, but exact server counting rules still need runtime verification.

## LibrusGO payments and invoices

Payment custom-list is POST with `{dateTo,statuses}` and offset query. Builder advances by returned item count and waits for equality with total, then translates statuses/currencies. It catches any failure and returns[]; do not erase a previously loaded ledger on this fallback. Keep complete paid and remaining amounts distinct.

Online payment is explicitly initiated through a dedicated POST with due ID, returns link data, then opens a browser. Browser exit, load error, or URL containing `command=back-to-app` merely invokes refresh/closed callback; none proves successful payment. Confirm final state by refetching. No automatic replay of payment initiation on timeout.

Invoice download creates an asynchronous invoice-file request, takes returned `id`, polls status every1000ms with maximum10attempts, `immediate:false`, `throwOnError:true`. Status`failed` throws; status`done` proceeds to the request URL endpoint. Then download the presigned URL. Keep this URL's host/token scope separate from the GO Bearer API and do not log it. Confirmation PDF is a different GET with Acceptapplication/pdf and blob response.

## Meals: local API reads/cancel versus browser ordering

Meal reads supply orders, menus, meal sets/allergens, news, balance and integration status through Synergia integration routes. Original code often catches failures as empty menus/news or zero-looking balance. Preserve `transport failed`, `not integrated`, `no balance account` and successful0balance separately. News detail is described by its original caller as marking read on the backend; treat it as an effectful GET pending runtime corroboration.

The reviewed ordering UI does **not** build a native order JSON POST. It opens authenticated external ordering. `meal-orders-store.js/openZpRedirect` constructs exact path:

```text
/zamowPosilek/redirect/{SCHOOL|KINDERGARTEN}/mobile
/zamowPosilek/redirect/{SCHOOL|KINDERGARTEN}/mobile/payments
/zamowPosilek/redirect/{SCHOOL|KINDERGARTEN}/mobile/ordering/{YYYY-MM-DD}[/{menuId}]
/zamowPosilek/redirect/{SCHOOL|KINDERGARTEN}/mobile/news/{newsId}
```

It delegates to Synergia target-URL autologin. Returning refreshes balance and the last-viewed order range. This is browser module support, not a recovered direct ordering API. Cancellation is direct DELETE with `orderIdentifier`; on success remove matching local order, reload day detail and refresh balance after a UI delay. UI suppresses cancellation for past dates and hides relevant controls for student accounts. Server409/codes still govern actual capability. A timeout can leave cancellation uncertain; reconcile the order before retry.

## Change register, cache invalidation and event frames

Two mechanisms coexist:

1. **Synergia ChangeRegister/PushChanges.** Register/update per connected account with app version; push mode includes provider/device and string sendPush`'1'`, nonpush mode string`'0'`. Main client maps platform to FCM/HWI/HWI_JST; token containing `drut_` selects nonpush. Poll uses account pushId and an in-flight account guard.404 invalidates pushId and reconnects. Deleting consumed changes batches at most30IDs per request. It is server acknowledgement, not local garbage collection.
2. **Gateway custom-event frames.** `event-frame-builder.js` resolves `objectType==='Cycle'` into custom timetable events. Type`created`, `edited`, `deleted` controls local mutation; edits with missing local model refetch by object identifier. `changed[]` entries update fields, and `entry`-prefixed names are rewritten into nested entry fields. String booleans convert by comparison with`'0'`. Unknown types/failed processing are not evidence of successful synchronization.

Original change-issue retry state records TriesCount and LastAdded. Retry count increases only after at least24hours since saved issue; limit defaults5. At limit it clears affected module storage (all grades route through subjects), acknowledges those changes and removes issue rows. A future adapter should prefer explicit quarantine/resync and durable acknowledgement after successful state persistence, not copy destructive fallback invisibly.

Event feed rows embed copied module data. Marking homework read/done and pinning mail update both ORM and matching event copies. Deleting records also invalidates reminders. New custom cycle frames can affect multiple timetable occurrences, so invalidate range and reminder projections by source cycle, not only displayed row ID.

Recommended transaction order: fetch changes under captured account generation; fetch affected raw records and dependencies; validate and persist module deltas/tombstones; derive feed/unread/reminder changes; commit durable checkpoint; acknowledge consumed change IDs. If any stage fails, retain enough source identifiers to resume. Do not acknowledge every downloaded change before dependent data is persisted. Push delivery into Siberia's own Firebase project is not established merely because official-app registration code exists.

## Suggested fixture checks

See [synthetic-cases.json](synthetic-cases.json). Assert exact request maps, decoding transformations, owner isolation and cache consequences. A request serializer unit test cannot establish role permission, accepted app version or live service behavior. Keep those release gates explicit.
