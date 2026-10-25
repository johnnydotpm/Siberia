# Evidence, verification and remaining gates

## What the evidence establishes

The supplied packages were unpacked and hashed. Java-side legacy MobiReg code was examined with JADX/REA. Flutter AOT snapshots were analyzed with matched Dart metadata tooling and named ARM64 listings, followed by raw instruction/object-pool checks. The [artifact manifest](evidence/artifacts.json), [toolchain provenance](evidence/toolchain-provenance.json) and [validation summary](evidence/validation-summary.json) identify the inputs and bounds.

Modern MobiReg independent checks covered3086 direct branch/pool-load checks,21 module operation entrypoints and18 academic call dispatches. Its r2flutter parse covered843 snapshot clusters,173419 objects and25593 instruction entries. Fryderyk Android had795 direct branch/pool-load checks. Newer Fryderyk iOS validation covered3613 instructions,408 direct branches,48 pool indices and134 literal references with zero mismatches in that bounded set.

These counts validate evidence locations and decoding consistency. They do not prove every feature branch was decoded, every type is understood or every request works against a current server. Blutter modern MobiReg reported one optional named-parameter analysis issue in dependency code at0x418668. An early Fryderyk iOS annotation pass had a two-entry pool-index offset error; it is invalidated. Only corrected annotations and validated original bytes support the newer report.

The package intentionally excludes original APK/IPA files, extracted proprietary binaries, full decompiled listings, downloaded tools, authentication material and live student data. Curated ledgers retain artifact hashes, function names, code locations and reasoning sufficient to revisit a claim when the original local research is available.

## Evidence vocabulary

| Label | Meaning | Does not establish |
|---|---|---|
| Recovered/static caller | Named code builds/calls the described request | Current server acceptance |
| Typed constructor | Decoder consumes the specified wire type/field | Field is always emitted by the server |
| UI-observed in artifact | Screen/string/handler exists in supplied package | Availability for every school/role |
| Inferred | Meaning follows surrounding callers/data flow | A wire guarantee |
| Proposed | Recommended Siberia design | Existing repository API |
| Synthetic example | Invented fixture illustrating a recovered shape | Captured traffic or real account data |
| Runtime gate | Needs controlled account verification | A failure of the static result |

When a JSON field has an unresolved nullable/default branch, preserve that flag rather than interpreting a sample's value as a schema. A constructor accepting a stringified numeric field does not mean all other numeric fields are equally permissive.

## Required fixture families for the future implementation

Use the provider vectors as starting material. Add hand-authored, explicitly synthetic variants before an account is available:

* Authentication: exact raw/trimmed password distinction; legacy digest once; missing/rotated refresh; concurrent refresh; logout during refresh; malformed/expired JWT; wrong authority.
* Discovery: parent with multiple pupils; student self context; missing module URL; configured old homework module; different school with identical username; academic period switch.
* DTO decoding: required missing field, explicit null, empty collection, unknown enum, int versus numeric string, nested pupils, music-specific lesson/exam data, Unicode and date boundary.
* Gateway: valid `v/data`, null data, business `err`, invalid version, TTL defaults,401 callback once; extras overriding token for FCM.
* Mail: all folders, empty page, search, recipient IDs, reply/forward context, read side effect, cookie acquisition from redirect, send success/upload failure, expired module session.
* Homework: active/archive list, pupil detail, solution save, file upload, archive toggle,401/419, wrong-pupil result,200 HTML or malformed JSON.
* Sync/cache: failed module retains stale data, legitimate empty replaces data, interrupted legacy transaction, deletion/import actions, switching child during fetch, background/foreground race.

Assertions must compare full method, URI path/query, exact header ownership and serialized body. A test that merely checks an endpoint string exists does not verify these contracts. Store expected multipart part names and field values without hardcoding a generated boundary.

## Controlled runtime verification plan

No real account was supplied and no original app or school data endpoint was exercised. Implementation agents should obtain an authorized test account and record app version, role, school origin and enabled modules. Start with login/discovery and read-only data. Record a redacted original-app request/response pair per transport family; protect response bodies containing pupil data. Capture the original action rather than guessing route methods from names.

Then compare exact headers, encodings, token rotation, cookies, date/time interpretation, pagination termination, role permissions and error formats. Verify code paths whose field/default branch remains flagged in the provider tables. Use a controlled mailbox/homework recipient before validating writes. Record before/after state and confirm server effects. Do not replay a production mutation just to resolve a timeout.

Minimum unresolved runtime gates:

| Area | Question to resolve | Release consequence |
|---|---|---|
| Fryderyk version policy | Accepted third-party App-Version and426 behavior | Block unsupported client compatibility, not account data |
| Dynamic origins | Actual school/module origins and account configuration | Validate ownership before using returned URLs |
| Roles | Which recovered operations are allowed for parent/student/teacher | Enable capability per tested role |
| Field branches | Remaining constructor defaults/coercions; real optional fields | Preserve unknowns until tested |
| Dates | School timezone, DST and inclusive range boundaries | Avoid shifting lesson/absence day |
| Pagination | Empty/final-page and concurrent changes | Avoid duplication or skipped mail |
| Writes | Server validation, duplicate handling, attachment limits | Keep uncertain writes disabled until verified |
| Modern iOS parity | Whether same-version iOS behaves like Android | Do not claim parity from version label |
| External modules | Session lifetime, redirects and download authorization | Verify independently of main JWT |

## Documentation quality checks performed here

The final package is checked for JSON syntax, local Markdown links, exact94feature inventory coverage, source-anchor availability and exclusion of executable plugin files/raw app artifacts. Source anchors are tied to the recorded Siberia baseline and must be rechecked after upstream changes. Such checks verify the handoff, not the future adapter.

An implementer should finish one operation with a typed DTO, exact serialization fixture, owner/scope isolation test and live verification record before declaring that capability ready. Unverified operations can remain documented without being exposed as supported features.
