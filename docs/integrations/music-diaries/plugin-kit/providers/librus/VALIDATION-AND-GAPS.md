# Verification, provenance and exact remaining gates

## Static input coverage

Input SHA256/version metadata are in [artifacts.json](artifacts.json). Android8.4.1/code64872 and iOS8.4.1/build6487 both package Cordova web resources. The Android subtree records manifest/entrypoint/deep-link evidence and confirms byte hashes of web resources. All1331 shared first-party main-map source-content records match across the two platforms. Platform-native behavior, permissions, browser callbacks and build wiring remain separate facts.

REA inspected/extracted the IPA and analyzed the web tree as inert text. Important retained evidence:

| Evidence ID | Scope |
|---|---|
| `ev_f18efbf8550ee0eeedfd5a1fbefd47564bec2d8289c1d465994b46d821f448db` | IPA archive graph/integrity inspection |
| `ev_e02d4b05441d5f5b5866e1345743fbd07fa09298f8f969d8d1059f6b7d627813` | Materialized regular files with containment/integrity checks |
| `ev_7148cdd8584c46d62d7e851dca71815e2d9ae6e08d7921bd9537cdb987c0ecb2` | Static JavaScript application analysis |
| `ev_0ea09c0f9723bf56893331167b009277a5cbdebfb2bbe0432a3bb4a2ff96bc02` | Bounded summary view of the retained JS evidence |

REA parsed455JavaScript files, visited1430905AST nodes, and reported zero parse failures. Its broad semantic graph reached the100000node ceiling, explicitly retained partial coverage and140393 semantic unknowns. It does not resolve every Axios request or prove full control flow. The oversized MCP response was exported locally; analysis was not rerun merely to circumvent the transport limit. The raw332MB evidence export is not part of Git.

The request ledger was independently extracted from exported named/default source-map function declarations with Babel AST parsing. It covers328 functions/332 helper call sites with zero parse failures in that selected API-source set. It deliberately does not count every direct Axios/auth/download call as the same catalogue. Manual source tracing supplements authentication, caller payloads, module codecs, effects and state behavior.

## Source-map corroboration and its limits

[source-map-callsite-checks.json](source-map-callsite-checks.json) checks the original compiled bundle hash and its sourceMappingURL footer, then maps each original request-call location to the shipped generated code and back. **296 of332 call sites map back to the same original source line;36 have no generated mapping at that point.** None of those36 is thereby proven unreachable, removed, corrupt or supported. They remain source-content declarations requiring further reachability/runtime corroboration before enabling a capability based only on them.

For example, the justification attachment-available getter exists in sourcesContent but its call point lacks this generated mapping. The documentation preserves its declared request while avoiding a claim of observed runtime use. A mapping point is evidence of source-location linkage, not an execution trace or proof of complete semantic equivalence. Source maps can contain unused source declarations; equal Android/iOS content hashes alone do not prove that identical branches execute on both platforms.

The iOS main Mach-O reports LC_ENCRYPTION_INFO_64 cryptid0 in its original header. The application was never launched, patched or decrypted for this research. Native strings mainly concern Cordova/SDKs; main diary contracts were traced through packaged web code. There is no basis to substitute Firebase or advertising SDK URLs for school-data API endpoints.

## What the counts mean

*195 semantic feature rows: an analyst-defined coverage checklist, including local/browser/commercial/platform behavior.
*308 Vue component records: includes reusable UI, dialogs and detail components, not308 independent features.
*328 exported request functions/332 call sites: route variants and shared resources, not332 distinct endpoints.
*62 local ORM declarations/801 field rows: local defaults/types/relations, not801 mandatory server fields.
*52 builder records and23 workflow anchors: scoped consumer evidence, not a complete formal wire schema.
*30 current Siberia source fingerprints/108 literal anchors: current-main edit locators, not applied patches.

The final [documentation checks](documentation-checks.json) validate syntax, links, source identities/anchors, operation routing and inventory consistency. No Flutter application test or authenticated API test is implied by a passed documentation check.

## Required future fixture and runtime gates

| Gate | Exact question / fixture | Completion evidence |
|---|---|---|
| AUTH-PORTAL | Legitimate client ID/redirect, browser login/cancel/error; callback encoding and correlation | Authorized code exchange and redacted successful/error responses |
| AUTH-ROTATION | Portal refresh plus linked-account fresh token; sibling profile concurrency,410/424/503 | Token-owner state machine; no cross-profile token publication |
| AUTH-GO | Challenge encoding, loginToken exchange, actual Authorization header and returned contexts | Controlled GO account exchange, permission/terms/candidate states |
| CODEC | Synergia JSON-string helper versus Axios object/FormData final wire Content-Type | Actual emitted request bytes/headers per adapter, not guessed JSON default |
| REACHABILITY |36 source-content request points lack generated mapping; other unused/dev branches | Compiled caller trace or authorized original-app action before claiming support |
| API-VERSION | Official3.0 vs Siberia2.0/XML/HTML behavior and permissions | Side-by-side redacted fixtures, preserve working fallbacks |
| DTO | Raw IDs/enums, JSON-string message body, singular/plural shapes, null/default branches | Per-operation raw fixtures; keep local ORM defaults distinct |
| PAGE | Synergia300page+afterId, GO100offset+total, reminder20+last_page | Empty/final/full/duplicate/non-progress tests, bounded loops |
| DATE | School timezone, date-only semantics, DST, lesson number vs ID, recurrence split | Boundary fixtures and observed school dates; no UTC day shift |
| WRITES | Message delete/pin/reply; homework/read/done/file; justifications | Controlled test data, exact role and server outcome recorded |
| FILES | Type/size policy, inverse restriction flags, signed URL expiry and credentials | Library-generated multipart check plus permitted upload/download |
| PHOTO | Eligible account, photo body/status/removal-request lifecycle | Test-school photo workflow; distinguish pending from completed removal |
| CHANGES | Device register/poll/ack, missed changes and interrupted persistence | Acknowledge only committed entity changes; no lost/replayed notifications |
| PUSH | Third-party push identity and school support vs official backend setup | Verified deployment contract; local polling remains separately labeled |
| MEALS | Integration state, menu/order/balance and external handoff results | Refresh-confirmed order/payment state; browser close alone not success |
| GO-DOCUMENTS | Signed invoice download/polling, legal approvals, payment states | Independent context permissions and confirmed partial/final outcomes |
| ENTITLEMENT | Role/school/premium/JST/GO flags and subscription-dependent routes | Capability matrix per account; source UI badges aren't server authorization |
| STORAGE | Existing profile migration, logout/removal during refresh, isolates/widgets | Snapshot compatibility and deterministic race regressions on current source |

Use synthetic fixtures first. The [module cases](models/synthetic-cases.json) and [wire examples](REQUEST-EXAMPLES.md) are labeled invented. Then obtain a user-authorized test account and record app/build, school, role, enabled modules, exact action and redacted original request/response. Prefer passive capture of a controlled original-app action over guessed mutations. No real pupil records, reusable credentials, signed links or callback codes should enter Git.

## Future-agent completion rules

For each feature and operation, separately record: documented, independently implemented, synthetic tests passed, live role/server verified, and enabled. Use `unsupported/unverified` when an unknown blocks the operation. Do not label an empty response a successful implementation when dispatch was skipped or a source fallback swallowed an error.

Keep unresolved dimensions narrow: an unverified photo removal does not block read-only timetable implementation. Conversely, the existence of a request function cannot be used to declare every account entitled to call it. Review the H-LIB task and source drift before changes; the published documentation branch's old application files are not the current-main baseline.
