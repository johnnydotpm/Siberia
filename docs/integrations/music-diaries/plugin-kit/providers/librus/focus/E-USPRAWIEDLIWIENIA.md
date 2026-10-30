# e-Usprawiedliwienia: complete recovered workflow

This specification prioritizes electronic absence justifications for the supplied Librus8.4.1 Android/iOS clients. It is **documentation only**. It describes shipped source, illustrative wire bodies, proposed Siberia behavior and remaining runtime questions separately. The same1331 first-party app source-content records are byte-identical between the supplied packages; native differences still apply. No account, app session or school endpoint was exercised.

The companion [evidence ledger](justification-evidence.json) contains30 bounded facts,22 source identities,85 exact line anchors, six related request operations, four synthetic payload illustrations and28 acceptance cases. Each fact `J-xx` below resolves to a source-map member, original-source index, source-content SHA256 and line. Original Vue components use their original source URL, not generated loader wrappers.

Read [authentication/transport](../AUTH-AND-TRANSPORT.md), [operation reference](../OPERATIONS.md), and [host tasks](../siberia/AGENT-RUNBOOK.md) alongside this guide. Proposed task names/types below do not describe already implemented Siberia functionality.

## 1. What the operation means

A justification is a **submitted parental request** for an interval or selected lesson numbers. Sending it does not directly change an attendance category. The source submits a `Justifications` record, fetches its receipt/detail and later displays status/count updates. There is no attendance-edit request in this create flow. `sendNotify` optionally asks the service to notify teachers of a planned absence; it is not the app's FCM notification preference.

Keep three pieces of state separate:

* Submission delivery: draft, submitting, confirmed receipt, uncertain outcome or failed validation.
* School decision: raw `send`, `accept`, `reject`, or an unknown future value.
* Official attendance records: independently fetched categories and counts, which may change after school processing.

An `accept` status and `justifiedAbsences` count are received facts. Do not immediately rewrite every attendance inside the requested date range to justified or assume every submitted lesson was accepted.

## 2. Exact transport recipes

Use the selected linked **Synergia account** Axios instance: base `https://api.librus.pl/3.0`, Bearer token for that linked account, JSON accept header and the common configured timeout. This is neither Portal OAuth nor the HTML mailbox. The account is selected by `login` outside the JSON body; there is no invented pupil ID or Portal account ID field in this request.

| Operation ID | Function | Method and relative URL | Response consumed |
|---|---|---|---|
|`LIB-620d57fd4a`|`getJustifications`|GET `/Justifications?dateFrom={dateFrom}&dateTo={dateTo}`|`response.data.data`, list |
|`LIB-319044758e`|`getJustificationsById`|GET `/Justifications/{id}`|`response.data.data`, one object |
|`LIB-32615b9f68`|`getJustificationsByIds`|GET `/Justifications{idsSuffix}`|data array, or singleton wrapped as array |
|`LIB-b6a379281d`|`getJustificationsAttachmentAvailableFlag`|GET `/Justifications/Attachment/Available`|`response.data.canSendAttachment`; active composer caller **not present** |
|`LIB-6d1b9b729d`|`postJustification`|POST `/Justifications`|`response.data`; store next reads uppercase `Id` |
|`LIB-824da08372`|`getTimetablesFromSingleDay`|GET `/Timetables?day={YYYY-MM-DD}`|`response.data.Timetable`; supplies lesson-number choices |

Multi-ID store calls supply `idsSuffix` as `"/" + uniqueMissingIds.join(",")`, for example `/901,902`. The raw helper does not insert that slash on its own. This is not a query parameter, and an empty missing-ID set should not be sent blindly.

`synergia-rest-core._post` sets method `post`; `_request` JSON-stringifies truthy body data unless `sendFile` is true. Justification creation passes an ordinary object, not multipart and not a file. The common instance sets Accept/Bearer/timeout; the inspected helper does not explicitly set a universal Content-Type. Preserve the recovered JSON bytes and verify the required outgoing media header with a controlled fixture rather than claiming a header not observed in this caller. A future implementation's explicit JSON media header should be an intentional compatibility decision.

### Form A: whole selected days

Synthetic body, never captured or sent:

```json
{
  "messageFromParent": "Synthetic reason only",
  "lessons": [],
  "dateFrom": "2030-03-04",
  "dateTo": "2030-03-06",
  "sendNotify": false
}
```

An empty `lessons` array means this form does not choose individual lesson numbers. It is not a missing required selection. Equal day bounds are allowed by the local form. Inclusive range/server processing semantics require live validation; the display treats it as the selected day interval.

### Form B: selected lessons in one day

Synthetic body:

```json
{
  "messageFromParent": "Synthetic reason only",
  "lessons": [2, 4],
  "dateFrom": "2030-03-04",
  "dateTo": "2030-03-04",
  "sendNotify": true
}
```

The array contains decimal **lesson numbers**, produced by `Number.parseInt(value,10)`. Do not send attendance IDs, timetable-entry IDs, lesson-definition IDs or normalized local cache IDs. Preserve source account identity separately and validate that selected numbers belong to the intended date/context before serializing.

## 3. Role, school/class and entitlement gates

Evidence: `J-01`–`J-05`.

The page descriptor carries `premium:true`. `JustificationsContainer.fillModelView` returns early for a broken current account, a student account or a nonpremium current account. Student UI explains the module is for parent/guardian;403 becomes a school/class unavailable explanation. Generic transport or schema failure has a different error path. Lack of premium, role denial, school/class denial, offline failure and successful empty history must not collapse into one empty list.

The original `isAccountTypeStudent` helper returns true only for numeric group8 or string `student`, and false for null/missing group. This negative check is not a complete positive proof that every other group is a parent. Kindergarten/user-kind variants need their own validated capability; preserve the raw role instead of treating `not student` as server authorization.

There are three attendance shortcuts:

| Entry | Source eligibility | Composer preset |
|---|---|---|
|Attendance card|Nonstudent; module available; `TypeId === "1"`; JST additionally hides nonpremium shortcut|`attendanceObjectRef` and current linked login |
|Date group|Same gates; at least one entry has exact string TypeId1|`attendanceChosenDay`; whole-day form |
|Attendance detail|Uses detail's explicit account ID for role/premium/availability rather than whichever account happens to be selected|`attendanceObjectRef` and detail account ID |

When availability is undefined, shortcuts request a module check and hide until a result. An explicitly false availability hides them. Outside JST, a nonpremium shortcut can remain visible with a premium badge and redirect to the offer on click. These are original UI policies, not claims about bypassing server permissions. A source TypeId1 shortcut criterion does not mean all potential date/lesson justifications must be prefiltered to TypeId1 by the API.

## 4. Composer state and exact validation

Evidence: `J-06`–`J-15`.

Default composer state is `ChosenDays`, all three date values set from current `moment().toISOString(true)`, empty body/selection, false notification checkbox. Date widgets use `value-zone="local"`; wire date strings are `YYYY-MM-DD`. This is the client's local-date behavior; the authoritative school timezone remains a runtime question. Do not turn these date-only fields into UTC instants or append `Z`.

The day-group shortcut sets start/end/single to the chosen day. A per-attendance shortcut starts in `ChosenLessons`, loads that date's timetable and tries strict equality between timetable `lessonNo` and attendance `Lesson`. If found, it prechecks that value; otherwise it falls back to whole days. A string/integer mismatch can therefore change the original default mode. A future implementation should normalize the canonical lesson identity deliberately while preserving the source value for diagnostics.

| Input | Recovered local validation | Important limit |
|---|---|---|
|ChosenLessons|At least one checked lesson and nonempty single date before confirmation|No proof of server eligibility merely from appearing in the timetable |
|ChosenDays|Start/end must be nonempty; end cannot precede start by day|Same date allowed |
|Start date change|If new start is same/after end, end becomes start|The end picker also has `min-datetime=startDate` |
|Reason|Textarea `maxlength=1000`|No nonempty/trimmed-body check in the inspected confirmation validator |
|Past/future range|Date controls shown without a past/future min/max restriction beyond end>=start|No maximum7/14/30-day span or backdating window recovered |
|Confirmation|Explicit confirm dialog, spinner while sending, cancel/back-abandon dialog|A UI double-click guard is not server idempotency |

The browser maxlength is a UI text-length rule; it does not establish the server's byte limit, trimming or Unicode counting. If Siberia requires a nonempty reason or adds a range limit, label it new client policy and validate it against the actual service rather than attributing it to the supplied client.

### Lesson selection is derived from the timetable

`onSingleDatePicked` clears checked lessons, calls `timetables/getViewModelFromSingleDayForLogin`, maps every returned item to `{lessonName:subject, lessonNo}`, and resets the loader. The store calls the single-day timetable builder and raw GET described above. The composer does **not** additionally filter absence type, canceled lessons or already-justified records. Server eligibility may be narrower; that remains a controlled-account gate.

The timetable builder's `getLessonNo` may turn substitutions into display text containing original/new numbers separated by U+F2EE. Passing that display text into `parseInt` keeps its numeric prefix; nonnumeric text can produce NaN, and JSON serialization can turn that into null. **Recommended Siberia policy:** keep display text separate from the raw canonical lesson number; validate numeric selections and resolve moved-lesson identity before enabling the submit button. Do not silently reproduce display-text parsing for school actions.

The async picker handler has no generation/date guard. If a user chooses another date while the first response is pending, the old result can populate the new form. Scope the request by owner/date/generation, discard obsolete completions and clear invalid selections. Preserve local draft text across recoverable timetable errors; distinguish no registered lessons from failed loading.

## 5. Planned-absence teacher notification

`shouldAskForNotification` compares today with:

* `endDate` in whole-day mode;
* `singleDate` in selected-lesson mode.

It uses `now.isSameOrBefore(date,"day")`, so **today counts**, and a range beginning in the past but ending today/future can still show the checkbox. A wholly past range does not. The checkbox defaults false; the body always contains a boolean `sendNotify`. When the condition is false, serialization forces false even if the checkbox had previously been true. No hour-of-day or selected lesson start-time comparison occurs here.

The confirmation copy says scheduled teachers receive a system message about the planned absence. It is not proof of guaranteed delivery, an email address list, recipient IDs in the body, or a FCM topic subscription. The response's `notifiedTeachers` is preserved, but no complete nested teacher schema was established by this flow. Do not guess it from unrelated teacher DTOs.

## 6. Receipt, response fields and statuses

Evidence: `J-17`–`J-24`.

The source store sends using the explicit login's Synergia Axios. After POST resolves, it reads **uppercase** `response.Id` and calls detail GET. Detail/list response fields are **lowercase**, then the builder normalizes them into the ORM model. Preserve that distinction.

| Wire field | Normalized field | Recovered consumption/default |
|---|---|---|
|`id`|`Id`|ORM string default null; primary identity also includes account login |
|`lessons`|`Lessons`|Copied through; generic attr default null; preserve raw shape rather than claiming all responses are arrays of numbers |
|`attachment`|`Attachment`|Copied through; ORM boolean default false |
|`messageFromParent`|`MessageFromParent`|Falsey input becomes null in builder; ORM declares string default empty; detail suppresses null and literal `"null"` |
|`postDate`|`PostDate`|Copied; ORM string empty; displayed through moment as `DD.MM.YYYY HH:mm` |
|`justificationStatus`|`JustificationStatus`|Copied; ORM string empty; preserve exact raw value |
|`justifiedAbsences`|`JustifiedAbsences`|Copied; ORM number default0; display as received, not a locally calculated count |
|`dateFrom`/`dateTo`|`DateFrom`/`DateTo`|Copied; ORM strings empty; displayed as day interval |
|`notifiedTeachers`|`NotifiedTeachers`|Copied; generic attr default null; nested schema remains unresolved |
|local account parameter|`SynergiaAccountId`|Caller login; not an extra server field |
|local only|`IsNew`/`Deleted`|ORM booleans default false |

These are consumer/default observations, not a complete server JSON schema. The builder does not enforce a separate required/nullable contract for every wire field. Single-detail builder treats an empty object as zero records. Multi-ID raw wrapper converts non-array data to a one-element array; malformed/null roots should remain protocol failures in a new adapter rather than being declared empty.

Known values are exact lowercase `send`, `accept`, `reject`. Main list groups `send` as sent and `accept`/`reject` as processed. Item/detail/feed labels explicitly test send and accept, then fall through to rejected for anything else. An unknown value can disappear from the main groups or be mislabeled rejected. **Recommended mapping:** preserve raw status and use a neutral unknown label/group; map rejected only from known `reject`.

Detail shows interval, status, accepted-absence count, reason, attachment-present boolean and added date. There is no accept/reject control, direct attendance editing or justification deletion button in these components. Long press/context menu copies fields. The generic message action can prefill a question about this justification, using the first class teacher's display name. That opens ordinary mail composition; it is not a justification decision/edit API.

## 7. Attachments: available flag is not an active upload feature

The raw GET `/Justifications/Attachment/Available` exists and returns `canSendAttachment`. However, in the inspected composer:

* `canSendAttachments` state is commented out;
* the add-attachment markup is inside an HTML comment;
* the flag-fetch block is inside a JavaScript comment;
* there is no active import/caller of that getter or a justification upload builder in the bounded first-party source search.

Existing records can carry an attachment boolean, and cards/details show that fact. The detail's attachment row is a label, not a recovered download action. Do not invent an upload path, multipart key, file limit, download URL or compose attachment field from the boolean/getter. Keep attachment send/download capability unresolved until a concrete caller/contract or authorized runtime evidence is obtained. Homework/photo upload recipes are unrelated and must not be copied here.

## 8. Cache, refresh and duplicate-risk handling

Evidence: `J-25`–`J-30`.

The source cache is keyed by linked login plus justification ID. `getViewModel` returns nondeleted cached rows only when isDirty is false **and the result is nonempty**; a clean empty history still triggers a fetch. Cold fetch range uses September1 in the year preceding the school end date, through the end date. Missing school end date produces a very broad fallback `2000-09-01` → `2999-01-01`; this is a fallback query, not a supported composer range or documented server maximum. List UI then sorts PostDate descending, although the preliminary cached query orders by a `Date` property not declared in this model.

Availability is marked true on successful list/detail; textual403 detection marks it false. The availability check uses one module-global promise. A second account's check can return immediately while another is in progress, without receiving its own result. A future implementation should use owner-scoped in-flight state and structured HTTP status, preserve stale cached data for transient errors, and reconcile successful empty results over the covered range.

Local `markAsSeen` saves the model; local delete actions mark `Deleted=true`. **They do not issue a server DELETE or server read acknowledgement.** Change-stream resource `Justifications` resolves by account+resource ID into feed entries; Edit is presented as processed, other types as added. The page key incorporates current account and lastChange to remount ordinary list state. No direct attendance invalidation is proved by these handlers.

The original send success chain is:

```text
POST /Justifications
  → read response.Id
  → GET /Justifications/{Id}
  → insert receipt/detail in scoped model store
  → update lastChange
  → close composer and show success
```

Any rejection—including the follow-up GET—falls into a generic not-sent UI. This can misstate a confirmed creation as failure. Recommended future states:

```text
draft → submitting → confirmedReceipt(id) → detailReady
                     confirmedReceipt(id) → detailUnavailable (retry GET only)
         submitting → uncertain (request may have reached service)
         submitting → rejectedValidation (known server rejection)
```

Validate response.Id before constructing a URL; absent ID is a protocol problem with possibly completed creation, not proof nothing happened. Persist confirmed ID before follow-up. On POST timeout after transmission, retain the draft and uncertain state; reconcile history/detail before offering a deliberate retry. No idempotency key or duplicate-suppression guarantee was recovered. Broad auth retry interceptors are not permission to blindly replay an effectful POST.

Every completion must retain the captured account/session generation. A detail fetch, scope switch or logout must not publish data into a sibling account, resurrect deleted credentials or turn an old draft into a new child's submission.

## 9. Future-agent implementation tasks and done criteria

These are instructions for a later authorized implementation task, not code shipped by this research.

| Task | Concrete work | Completion evidence |
|---|---|---|
|J-IMPL-01|Add source-preserving justification DTO and scoped cache module; integrate H-LIB-02/03/05|Old cache migration unaffected; same remote ID in two profiles isolated; raw status/lessons/notifiedTeachers survive round trip |
|J-IMPL-02|Add exact six recovered request recipes; use linked Synergia owner and JSON body contract|Fixtures assert method/base/path/query/body and Id/id response distinction; no Portal token/attendance ID mixup |
|J-IMPL-03|Build parent-capability list/detail with explicit unavailable, stale and unknown status states|No source fallback labeling unknown as rejected; successful empty and failed fetch distinct |
|J-IMPL-04|Build whole-days/selected-lessons composer plus shortcuts|Date/locality rules, canonical numeric lesson mapping, async date generation, body length and teacher-notify checkbox cases covered |
|J-IMPL-05|Implement confirmed receipt/uncertain outcome and reconciliation|POST success/detail failure never resubmits; timeout remains uncertain; logout/switch races tested |
|J-IMPL-06|Add change/feed refresh and controlled role/server verification|Status update does not itself rewrite attendance; test account validates role, dates, duplicates and server errors; attachment mutation remains gated |

The full28-case matrix is in the evidence JSON. Prioritize J-T10–T15 (lesson numbering/date races), J-T16–T20 (notification/attachment/duplicate risk), and J-T21–T28 (unknown status/account isolation/receipt handling). All examples are synthetic; they establish test design and serialization expectations, not live service acceptance.
