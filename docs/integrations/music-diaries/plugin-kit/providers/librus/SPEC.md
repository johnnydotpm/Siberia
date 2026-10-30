# Librus capability and operation specification

This is a future implementation guide for the two supplied8.4.1 clients. Read [authentication/transport](AUTH-AND-TRANSPORT.md) first. The [operation ledger](operations.json) records exact static URL expressions, method, parameters, config fields, helper import, response property reads, construction facts and source-map identity for328 exported functions/332 request calls. The [readable table](OPERATIONS.md) is navigation, not a substitute for each structured record and caller workflow.

## How to use a request record

1. Resolve its `source` and named function. Stable ID is derived from source path plus function name; it is not a server ID.
2. Select the service/credential from the calling store, not just the API filename. `axios_instance_expression` identifies the argument, often named `axiosInstance`, but that argument alone does not resolve the service.
3. Resolve variables in `url_expression` from parameters and construction facts. Values such as `ids` may already include a slash/comma/filter prefix. Preserve the caller's contract; do not insert extra delimiters to make a route look conventional.
4. Resolve `helper_import` to determine JSON versus Axios object versus multipart behavior. Examine explicit headers, `sendFile`, response type and config spreads in `config_fields`. A spread can supply/override fields; do not drop it.
5. Read the consumed response field and use a provider DTO before normalized Siberia models. `response_property_reads` includes intermediate reads, not an ordered formal decoder or proof that every field is required. A shared `.then(sliceDataFromResponse)` returns raw `response.data` even when no direct selector was captured.
6. Follow [module workflows](models/WORKFLOWS.md), the [DTO mapping](models/DTO-MAPPING.md), original-view action references and host triage. Build synthetic serialization fixtures before an authorized live test.

The AST ledger excludes direct Axios auth/download calls and helper definitions. Those are documented separately. It includes declared exported builders even when a route may be unused, gated or retained for development; presence is not proof of production reachability. Commented-out functions are not parsed as requests. For example, the old commented `/personalschedule/entries` helper is not a supported operation simply because it appears in a source comment.

## Profile, discovery, roles and academic periods

Portal identity and linked Synergia identity are distinct. Discover linked accounts through Portal and validate academic `/Me`. Preserve linked login, account kind, school/class, pupil identity, role, entitlements and service token separately. A kindergartner, student, parent and GO candidate do not have the same menus or write capabilities. Account `state` includes active/broken/technical-break cases; do not treat a missing accessible screen as an empty module response.

Fetch system/reference data needed by the builder before showing normalized details: users, subjects, grade categories, attendance types, school/class/classroom, calendars and semesters. Raw references often carry only an ID; preserve that ID even when the related label lookup fails. Period1/2/full-year is not a token owner. Academic year changes must not overwrite another year's cache or reuse local IDs without period/source context.

The official code contains JST/Huawei/development/widget variants alongside ordinary mobile production configuration. Keep them inventoried, but do not enable those alternative flows based merely on source presence. Browser widget X-OAuth header recovery is a separate path from mobile FormData OAuth. The normal onboarding target is the recovered production mobile flow.

## Grades and assessment

For the requested deeper statistical analysis, use [STATS.md](focus/STATS.md): it separates local Moje cele calculations from server-reported averages and documents formulas, filters and chart pitfalls.

The app supports separate standard/numeric, point, text, descriptive, descriptive-text, partial descriptive, behavior, behavior-point and system-proposal families. Their APIs, comments, categories, weights, averages, final/semester/proposed flags and skill trees are distinct. The operation table includes list, single and batch variants for those families. Do not compress everything into an integer grade or return0 when a descriptive or unavailable value cannot be averaged.

The standard builder joins grades with subjects, users, categories, comments and averages. Missing category/name defaults are presentation behavior, not authoritative server values. Improvement/resit links form relationships that need cycle/missing-reference handling. Averages can be school-computed; do not replace them with a client arithmetic average unless a declared grading policy supports it. Retain source grade family in comment identity to prevent cross-family ID collision.

See model mapping for exact raw→view fields and fallback branches. All62 declarations/801 fields are local Vuex-ORM schemas; a `number(0)` declaration is not evidence that the wire emits a mandatory numeric zero. Preserve raw fields and unknown values in DTOs rather than forcing the current Siberia Grade shape.

## Timetable, lessons and calendars

Core academic helpers include `/Timetables`, `/Timetables?weekStart={date}`, `/Timetables?day={singleDay}`, and `/TimetableEntries/{id-or-ids}`. They consume `Timetable` or singular/plural entry fields. The code additionally joins planned/realized lessons, substitutions, class/school/teacher free days, parent-teacher conferences, calendar events, virtual classes and classrooms.

Individual learning paths, one-to-one learning plans, other-activities registers and kindergarten day plans need typed detail beyond one subject/teacher/room. Preserve original/moved/canceled/substituted status, collections of teachers, actual times and related source IDs. Do not invent45minute periods or derive official attendance from a calendar event.

Personal custom timetable cycles use the personal-schedule service with the Portal token: GET `/cycles`, filtered `?synergiaAccountIdentifier=...`, GET/PUT/DELETE `/cycles/{id}`, POST `/cycles` returning `identifier`, and event-log date/time filters. These are user-owned custom events, not permission to edit official school timetables. Their recurrence/exceptions and dates must remain separate from real lessons.

Use school-local dates for date-only requests. Source Moment-format strings and date helper expressions are recorded at their callers; do not copy date-format letters blindly between JavaScript and Dart. DST, full-day intervals, weekends and academic period bounds require dedicated fixtures.

## Attendance and justifications

The dedicated [e‑Usprawiedliwienia protocol guide](focus/E-USPRAWIEDLIWIENIA.md) expands the form, role/date gates, status strings, notifications, attachments and uncertain-submission handling.

Attendance list/detail/batch requests consume `Attendances`/`Attendance`; type definitions determine symbols and normalized meaning. An unknown ID must remain unknown, not present. A justification request is a proposal/workflow rather than an immediate edit of official attendance.

Recovered justification routes are GET `/Justifications?dateFrom=...&dateTo=...`, GET single/batch variants, GET `/Justifications/Attachment/Available` consuming `canSendAttachment`, and POST `/Justifications`. The compose caller supplies `messageFromParent`, `lessons`, `dateFrom`, `dateTo`, and `sendNotify`. **`lessons` contains lesson numbers selected for the interval, not attendance IDs.** The caller controls whether future/current periods can send a notification; do not infer a notification API from that boolean alone. The attachment-available flag does not by itself prove an attachment upload route.

List/detail status, teacher decisions, and pending requests must be preserved separately from applied attendance. Gate compose by actual role/settings/eligible dates and server permission. See workflows for the exact local date and notification condition.

## Synergia messages

This API is a recovered alternative/additive path to Siberia's current API2.0/XML/HTML mailbox fallback. Validate it independently before replacing a working fallback.

| Action | Method and route | Important request/response detail |
|---|---|---|
| Full/delta folder list | GET `/Messages?alternativeBody=true&changeNewLine=1&afterId={lastMessage}&limit=300{filter}&page={page}` | Page starts1; loop until response Messages length differs from300; filter supplied by caller |
| Detail | GET `/Messages/{id}?alternativeBody=true&changeNewLine=1` | Reads singular `Message` |
| Send | POST `Messages` | New compose `{subject,body,receivers:[Id...]}`; reply `{subject,body,originalMessageId}` omits receivers |
| Remove | PUT `/Messages/{id}` | `{action:"delete"}`; do not substitute HTTP DELETE |
| Pin/unpin | PUT `/Messages/{id}` | `{action:"pin"}` / `{action:"unpin"}`; reads `Message` |
| Unread | GET `Messages/Unread` | Reads `UnreadMessages` |
| Employee-hours notice | GET `Messages/OutOfWork` | Direct `schoolEmployeeOutOfWorkMessageForParents`, trimmed only if string, otherwise empty |
| Attachment metadata | GET `/Messages/Attachment/{id}` | Returns response data; subsequent download behavior is separate |

Incoming subject/body are JSON-encoded strings consumed with JSON.parse in the view builder. Outgoing compose fields are plain subject/body strings before the Synergia helper serializes the request map. List `Receiver` versus detail `Receivers` also differ. Do not blindly copy response casing or encoding into send fields. Recipient group endpoints and user-resolution batches are documented in workflows; opaque identities and account namespaces must survive UI normalization.

The per-folder high-water marker (`afterId`) and HTTP `page` are two different dimensions. Lists can fetch several pages in one call. Pinned state, unread state and local “new” indicators are different. A server read side effect or local-only flag must be determined from the relevant consumer; do not mark all detail requests as pure solely because they use GET.

The inspected Synergia send path does not establish an arbitrary-file multipart message upload operation. Attachment metadata/download and homework upload are proven separate capabilities. A compose attachment feature cannot be claimed by reusing the homework route.

## Homework

Routes preserve the unusual `HomeWorkAssignments` spelling/case. GET list consumes `HomeWorkAssignments`; detail consumes singular `HomeWorkAssignment`; batch wraps a singular result into a list when needed. GET `/HomeWorkAssignments/Attachment/{id}` returns attachment metadata.

POST `/HomeWorkAssignments/MarkAsRead` and `/MarkAsDone` each send `{homework:<id>}`. These server actions are different from Siberia's existing local homework-done toggle. Store server confirmed state separately and reconcile after failure. The builder maps Topic→Title, Date→AddDate and DueDate→Date; retain their meanings rather than swapping creation and due timestamps.

Student answer upload is multipart POST `/HomeWorkAssignments/AnswerAttachment/{id}` with part `attachedFile` and the file's original name. `sendFile:true` prevents JSON conversion. The UI checks student role, `SendFilePossible`, due-date bounds, response counts and file-transfer restrictions; the exact checks are in workflows. A truthy setting or existing attachment is not proof that parent users may submit. No free-text answer request was established in this inspected caller chain.

File restrictions are fetched from `/FileTransferRestrictions`; the request helper falls back to `{upload:true,upload_3g:true}` after failure. These are restriction flags: the inspected homework UI blocks sending when restrictions are missing or `upload===true`. Do not misread that fallback as permission to upload. Preserve the underlying failure and the exact caller policy, and validate server acceptance separately.

## Announcements, notes, school information and photos

Announcements/notes and their categories have distinct builders. Preserve author, date, pupil/class relation, rich content, attachments, local new state and notice kind. Safe HTML display is presentation logic, not permission to execute embedded JavaScript. School/class/teacher/conference information needs reference joins and capability-aware screens rather than fabricated empty labels.

Student identification photo has GET `/Auth/Photos`, POST create/replace paths, and PATCH removal request `{for_removed:true}`. Removal is a request state, not proof the photo disappeared immediately. The photo PATCH comes through the GO helper with the supplied Synergia instance, so its body encoding differs from other Synergia helper calls. Camera/gallery permission, cropping and server photo requirements are separate pieces; preserve eligibility/rejection/status metadata.

## Meals and browser handoffs

The academic meal integration includes `/Auth/ZamowPosilek/Menus`, date-range `/Orders`, `/MealSets`, `/News`, `/News/{id}`, balance information and cancellation-related calls. Some readers catch failures and return empty data; retain partial/error state in Siberia. Reading one news item marks it read on the backend according to its caller contract, so that GET is effectful.

Meal display joins menu names and nested meal sets, formats prices/allergens and preserves order identifiers. Ordering and payments in the UI use an autologin/browser redirect such as `/zamowPosilek/redirect/{SCHOOL|KINDERGARTEN}/mobile[/destination[/date[/menuId]]]`. Do not invent a native “place order” endpoint because the UI has an order button. Browser closure/back-to-app is only a reason to refresh; it is not proof of payment or order success.

## Librus GO

GO has its own contexts/auth, permissions/terms and lower-case routes. It includes messages, timetable/lesson details, report-absence/catch-up suggestions, payments/documents/invoices, schools, legal approvals, avatars, push and candidate states. Preserve context/participant identity even when a Synergia user has the same displayed pupil name.

GO inbox/outbox pagination uses limit100 and offset, accumulating `response.data.data` until its length matches `response.data.pagination.total`. This differs from Synergia page300/high-water lists. Add a no-progress/duplicate/maximum-page guard in new code; a changing or inconsistent total can otherwise cause an unbounded loop.

GO send posts `/messages/outbox` with subject/content/recipient objects; mark-read is PATCH `/messages/inbox/{id}/read`; attachment URL retrieval is POST `/messages/attachments/{id}/url`. These must not be converted into the Synergia message body map. GO invoice generation/status polling and signed downloads are workflows with partial outcomes; reopening or closing a payment browser does not confirm a transaction. Payment/signature/terms changes require explicit capabilities and controlled verification.

## Reminders, goals, content, push and commercial surfaces

Portal reminder routes `/notification-params` support list/create/update/delete. List uses page1/perPage20 and the returned `last_page`. Portal goals `/mobile-addons/goal` support list/create/update/delete. Monthly summaries/trends, videos/progress, help/articles, theme/avatar and entitlement/subscription/demonstration flows are included in the operation/feature ledgers.

ChangeRegister/PushChanges are a separate school-account synchronization protocol: register/update carries appVersion plus sendPush `'0'`/`'1'` and optional provider/device; poll by pushDevice; delete acknowledged change IDs. Portal and GO push registration have their own bindings. Only acknowledge change IDs after affected entities are durably updated, so a crash cannot lose an event. A local poll-notification implementation in Siberia is not equivalent to official FCM/APNs delivery. A third-party app's push backend identity/entitlement still needs validation; copying vendor Firebase configuration does not enable it.

Advertising/impression/statistics, billing/IAP receipts, promotions, dev-only test pushes and vendor analytics are recorded as application surfaces. Their presence is not an instruction to reproduce vendor tracking or commercial infrastructure in Siberia. Retain a documented disposition per feature: core/additive diary capability, local UX, external handoff, official-platform-dependent commercial feature, SDK-only behavior or unresolved. A test-only export is not a production API commitment.

## Definition of a finished future capability

For every enabled feature, retain operation ID and source version, service/owner, full method/URI/body/headers, raw DTO and normalized mapping, role/module gate, pagination/cache/change behavior, errors, effects/replay policy and test provenance. Serialization/decoder tests can be synthetic; claim live support only after authorized account verification. The host runbook and per-operation triage show where current Siberia already has a related path and where additive work is necessary.
