# Future integration acceptance scenarios

These are synthetic test specifications, not live test results. Current application baseline: `fdd022da1759caf254873fbb6d8ffdea7e360b68`. Use exact official request recipes and model constraints from neighboring documents; values42/43/901below are invented.

| ID | Setup/action | Required result |
|---|---|---|
| LIBHOST-AUTH-01 | Two profiles under one Portal login request refresh concurrently | One owner-level refresh sequence per shared store, both get the resulting Portal token, each independently obtains its selected Synergia API token. |
| LIBHOST-AUTH-02 | Another Portal login has a slow/failed refresh | Independent account proceeds; no token/cookie transfer between account owners. |
| LIBHOST-AUTH-03 | Remove last profile and its login while refresh is awaiting response | No late credential reinsertion, orphan snapshot recreation or notification. A sibling profile prevents premature login deletion. |
| LIBHOST-AUTH-04 | Refresh rotates both tokens, returns missing token, or fails transport | Persist a validated rotation coherently; preserve usable material according to explicit policy; transient failure is not automatic invalid credentials. |
| LIBHOST-AUTH-05 | Legacy single-profile install upgrades | Existing data/settings/homework marks migrate once into correct SchoolProfile; repeated interrupted migration remains idempotent. |
| LIBHOST-SCOPE-01 | Profile42 fetch begins; user switches43then back42 before it completes | Generation/revision determines whether old result is accepted; profile-ID equality alone does not make it current. |
| LIBHOST-SCOPE-02 | Together view has profiles42/43; change included set mid-request | Updated source membership is respected; response cannot repopulate excluded source or publish aggregate stale state. |
| LIBHOST-SCOPE-03 | Same remote message ID901in two profiles | Sourced IDs remain distinct. Opening/attaching to42sends local901with42owner only. |
| LIBHOST-MODULE-01 | Grades fresh success, homework403, notes timeout, messages success empty | Preserve stale homework/notes and errors; replace messages with legitimate empty; partial sync status is explicit. |
| LIBHOST-MODULE-02 | API3.0 and old2.0 return differently shaped envelopes | Decode by service version; no permissive empty fallback or field alias guessed from similar name. |
| LIBHOST-CACHE-01 | Foreground and background complete out of order | Per-profile durable revision policy prevents older payload/cursor from overwriting newer state; atomic rename alone is insufficient evidence. |
| LIBHOST-CACHE-02 | Profile removed while background fetch runs | Recheck saved profile before publication/store write; removal persists. Existing recheck should remain tested. |
| LIBHOST-MAIL-01 |300mail records then300then17with overlapping item after concurrent new mail | Exact official paging/cursor advance; deduplicate by owner+folder+ID; no lost items or infinite loop. No claim server snapshot consistency unless observed. |
| LIBHOST-MAIL-02 | API mailbox denied, XML valid; HTML login page200 | Valid fallback used; HTML login page never accepted as empty inbox. Surface source completeness. |
| LIBHOST-MAIL-03 | Send returns statusok without ID or network timeout after bytes sent | Missing-ID result isn't confirmed. Timeout remains uncertain; automatic session replay never duplicates creation. |
| LIBHOST-MAIL-04 | GET detail confirms read; bulk read second item fails | Confirm first locally, retain failure/pending on second; do not mark all items read from initial button tap alone. |
| LIBHOST-MAIL-05 | Message pin/unpin/delete commands have ambiguous response | Distinguish desired state and confirmed provider state; reconcile before replay; local removal alone is not remote delete. |
| LIBHOST-HW-01 | Existing private checkmark loaded after new serverMarkAsDone support | No unsolicited upload. Private completion and server status stay separate until deliberate user operation. |
| LIBHOST-HW-02 | Answer upload field mismatch or second file fails | Exact field `attachedFile` per official recipe; preserve confirmed first transfer; don't resubmit whole homework silently. |
| LIBHOST-ATT-01 | Parent can create justification but student role cannot | Capability/eligibility state controls UI; local attendance record is not rewritten as server approved. |
| LIBHOST-DTO-01 | Unknown attendance standard type, descriptive grade, missing date | Preserve raw value/protocol issue; no present/zero/now fabrication. Existing supported fields still render. |
| LIBHOST-DTO-02 | Two timetable events share day+lesson number | Stable distinct source keys; no collapse of substitution/group records. |
| LIBHOST-DATE-01 | School-local dates cross spring/fall DST | Date-only values stay calendar dates; existing calendar-days helpers retained; instant parsing remains explicit. |
| LIBHOST-COOKIE-01 |302sets module cookie,307unexpectedhost, matching-name path cookies | Capture intended302cookie, block sensitive redirect replay, respect exact host/path/secure/expiry policy. |
| LIBHOST-DIAG-01 | Token/fresh path segments, Cookie/Authorization/body/error fields contain examples | Diagnostics output has no secrets, names, child IDs or message content; field-path/status diagnostics remain useful. |
| LIBHOST-EXTRA-01 | Meal/payment/school-ID/personal schedule unavailable for account | Explicit unsupported/unavailable state, no auth reset loop or fake empty success; no payment transaction during read smoke tests. |

Authorized runtime release gates must record package version/platform, role, school/account module activation, request/response provenance, observed side effects and any changed server behavior. Test writes with a controlled account/recipient and before-after verification. Static route construction and a successful synthetic serializer test are separate completion dimensions.
