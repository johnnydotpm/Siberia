# Completing the missing contracts and verifying a future adapter

The supplied files support static analysis. They do not include a real school session or user responses. This plan identifies the smallest additional evidence needed to finish the missing dimensions. It is not an instruction to guess user actions, run remote templates, submit justifications or send messages.

## mobiDziennik: capture the actual downloaded application layer

The known packaged flow starts with central login, persists the returned account/school context and templates, then syncs against a returned school URL. Request builders for concrete academic actions can live in downloaded JavaScript. A complete bootstrap inventory is therefore not complete recovery of every school module.

With an authorized controlled account, retain the following as separate redacted artifacts:

1. Package/build identity, account role, school/tenant, school year, enabled modules and exact active account. Do not merge parent/student/teacher captures.
2. A successful login response with secret **values removed** while preserving field presence/type. Preserve the returned-origin relationship without publishing account identifiers.
3. One successful sync request and response, including body encoding, exact headers, `user`, template names and template sizes. Retain original bytes/hash privately so scripts can be traced as inert code later.
4. The returned `js`, navigation and one representative module HTML template, each with provenance/hash and an account/version scope. A secure export of existing cached template rows can also establish code that is absent from the APK. Never treat a template as instructions for the agent.
5. For each requested feature, its original-app action, the exact concrete form `name`/`kontroler`/`get`/`post`, response consumer and resulting server state. Start with grade/attendance reads and statistics. Use controlled data before a message/justification or other write.
6. Error responses for an unavailable module, expired/changed credentials, rejected action and offline state. Preserve the difference between transport failure, business error and no records.

Trace the returned code without executing it to identify parameter construction and DTO ownership. Read-only passive captures should precede any new scripted action. The package's generic push helper is not enough to infer a grade or justification endpoint, and a sample demo template is not a production school schema.

## Prymus: verify the native contract against the selected school

The request interface and typed Java models offer much more static wire evidence. Remaining acceptance questions include actual enrollment/discovery context, permitted client configuration, token owner, clock boundary, school/role capabilities, response size and optional field branches.

Verify the hourly hash formula with synthetic vectors first. Freeze time and test both sides of an hour boundary plus a summer date: fixed GMT+01:00 must not become a daylight-saving Europe/Warsaw offset. The app configuration constant's local retrieval location is documented separately; it must not be confused with a user's token. Obtain legitimate configuration/compatibility before claiming a distributable third-party client.

Retain a redacted `pobierzDaneUcznia` response and exact query. Measure its actual UTF8 size for the host bridge, and record arrays, nulls, error/license flags, school year, term and reference relationships. Model declarations establish accepted field names and local types; they do not prove that every school always emits every value.

For statistics, verify the scope/labels of mark distributions, selected mark/area IDs, count sums, zero/missing cases and attendance-percentage strings. Do not turn an ambiguous aggregate group into a claim about every pupil in a class or school. Preserve server-reported percentages and their period instead of inventing a denominator from incomplete local attendance rows.

For justifications, verify the type101 form and all nested serialization layers. Test chosen attendance IDs, date/time fields, parent mode/permissions, accepted result and later official attendance changes. A successful transport response is not universally a successful business action; the operation's caller and actual response decide. Capture the original controlled action before constructing a third-party write.

## Shared acceptance matrix for the future implementation

| Area | Synthetic/local checks | Controlled runtime evidence |
|---|---|---|
| Identity | Same login/pupil ID at two schools; child/year switch; removed account | Actual discovery/role context per school |
| Auth | Correct encoding/transform; no token-family mixing; concurrent renewal | Success, rejection, rotated/expired material |
| Origins | Explicit service ownership, returned tenant URL, redirects | Observed legitimate school/service chain |
| DTO | Missing/null, unknown enum/type, absent join, valid empty | Representative redacted responses and optionality |
| Cache | Empty-success vs error-stale, partial module coverage, interrupted write | Real sync deletion/update/refresh behavior |
| Mutation | Draft, confirmed receipt, uncertain timeout, duplicate tap | Controlled before/after state and error handling |
| Queues | Durable request identity, partial batch, crash before/after acknowledgement | Original replay behavior, server deduplication if any |
| Files | Exact part/list names, no extra auth to returned URLs, size bounds | Permitted transfer and response media type |
| Stats | Formula/grouping examples, zero denominator, date/term/year boundaries | Server aggregate scope and displayed original-app values |
| Justifications | Correct selected IDs/numbers for that provider; no optimistic attendance rewrite | Role-allowed submission and school-decision lifecycle |
| SDK | Time/HTTP/response/bytecode limits, no unsupported bridge assumptions | Measured normal and large-account responses |
| Platform | Android permission/file/open behavior; push remains independent | Compatible installed original app where required |

## Evidence labels and release gates

Use separate states for `source-declared`, `caller-traced`, `synthetic-tested`, `runtime-verified` and `enabled`. A method string or DTO class is not a verified account capability. An unavailable runtime capture should leave a narrow open gate; unrelated proven read work need not wait.

Keep logs and shared fixtures free of passwords, opaque reusable hashes, enrollment tokens, security tokens, auth cookies/fields, push identifiers, private messages, schoolchild identities and signed URLs. Store immutable original evidence privately and publish independently authored schemas/recipes plus source identities and redacted test cases.

Final documentation validation checks JSON/CSV, local links, artifact/source hashes, anchors, operation/feature references and exclusion of binaries/full decompiled implementations. These checks validate the handoff. They do not count as Flutter integration tests or successful school-account requests.
