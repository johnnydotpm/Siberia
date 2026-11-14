# Actual plugin SDK contract and design constraints

This document describes existing API v1 at the recorded Siberia baseline. Examples are documentation fragments, not an implementation or a published release.

## Authoring and immutable release layout

The future source directories would normally be `plugins/mobidziennik/src/` and `plugins/prymus/src/`, with each provider's authoring `plugin.json`. They do not exist as a result of this documentation task. Choose a new semantic release version after implementation; do not overwrite another release.

`plugins/sdk/tool/package_plugin.dart` compiles only Dart sources found under the provider's src directory plus `plugins/shared/protocol.dart` as `package:diary_sdk/protocol.dart`. It requires `src/main.dart`; the VM enters `package:diary/main.dart`, function main. It writes `plugin.evc` and `manifest.json`, refusing an existing output. It does not build an APK or IPA.

Manifest API version is1; runtime pin is exactly `dart_eval-0.8.5`; bytecode maximum is4MiB. Artifact path must be `<id>/<numeric-major.minor.patch>/plugin.evc`. IDs are lowercase letters/digits/hyphens with an initial letter; bundled/reserved IDs cannot be replaced. Name, SHA256, exact byte size, unique operation names, exact origins, loginFields and localized instructions are validated. The catalog envelope is schemaVersion1 with at most100unique entries.

The catalog selects an offered release. Existing owners keep their pinned manifest; ordinary sync does not silently migrate protocol. Current automatic upgrade logic is narrowly for deleteMessage on existing Fryderyk/MobiReg releases with unchanged origins/login fields and a compatible superset of operations. Do not assume a new mobiDziennik/Prymus release automatically upgrades every enrolled owner. Define and test a deliberate migration policy if needed.

## Invocation envelope

Illustrative entry signature:

```dart
// ABI documentation only; no implementation is supplied here.
Future<String> main(String requestJson, Function http) async { /* ... */ }
```

Input is JSON `{operation,input,state}`. Output must be a JSON string containing `state` as an object and either `data` or an `error` object with a stable code. The runtime rejects invalid/oversized results. A new VM/isolate is created per invocation; globals are not durable session/cache state.

Initial connect calls `authenticate` with login fields and then `accounts`; the adapter's authentication data must contain an owner String. Accounts returns a list of `{id,name,school,parent}` with string IDs/names/school and boolean parent. At least one child is required. Later operations receive `pupilId` from the selected `SchoolProfile.pluginStudent`; the host appends it after caller input. Do not use an active global child as the source of request identity.

The current host parses every manifest field whose type is url during connect, including its cast to String. Therefore do not add a nominally optional blank URL field and assume it is ignored. Define the enrollment field validation/default contract explicitly or change the host deliberately. For mobiDziennik a returned authenticated tenant URL is a separate discovery/grant concern, not permission to accept arbitrary user-entered download origins.

The host persists returned state even when a valid operation result includes a provider error, so a successfully rotated credential is not lost. Return valid origin state on recoverable errors. Throwing one of the runtime's known stable error strings preserves the input state through its special error bridge; arbitrary exception text and print output are suppressed. Do not return a generic failure object with empty state when the host still needs `state.origins` and existing credentials.

Supported stable provider errors include protocol_error, invalid_origin, session_expired, invalid_credentials, unsupported_version, server_error, unsupported_operation, module_unavailable, invalid_input, page_limit, invalid_synergia_login, unsupported_account_role and account_action_required. A new error string needs compatible host interpretation and tests; do not leak bodies/tokens/stack traces through an error message.

## HTTP callback

`await http(requestJson)` accepts a JSON object with uppercase method GET/POST/PUT/PATCH/DELETE, full HTTPS url, string header values, and optional/null/raw-string body. HEAD/OPTIONS and binary bodies are not supported by the inspected bridge. The host does not JSON-encode form objects, trim passwords or infer the provider's envelope; the adapter owns exact serialization.

Response is JSON containing integer status, headers as lists of values, and raw UTF8 body. HTTP error statuses and redirect responses reach the adapter without automatic follow. A Dio transport failure is returned as status0 with empty headers/body. An authorization-policy denial fails the invocation rather than becoming an empty successful module.

Origins are exact HTTPS authorities: no wildcard, credentials, fragment, localhost, numeric IPv4 host, IPv6 host or non443port. Redirects are not followed automatically. The adapter must not forward password fields, tokens or auth cookies to an unrelated redirect/download authority. A discovered mobiDziennik sync URL may include a path; its separately granted origin is only scheme+host+port. Preserve the path in provider state without claiming that every URL under that origin is equivalent.

Headers are limited to32 entries; names are alphanumeric/hyphen and values cannot contain CR/LF. Host, Connection, Content-Length, Transfer-Encoding and Proxy-Authorization are forbidden. Let the host own connection/framing headers. Form values containing plus, ampersand, equals, Unicode and JSON strings need one form-encoding pass; the bridge forwards the raw string exactly.

## Current budgets

| Budget | Existing value | Consequence |
|---|---|---|
| Bytecode |4MiB|Pure-Dart helpers must package within the pinned compiler/runtime |
| Invocation wall time |45seconds default|A provider's original90second HTTP policy is not inherited |
| HTTP calls per invocation |64|Do not hide unbounded pagination/bootstrap/template polling inside one operation |
| Invocation input/output JSON |1MiB UTF8 each|Includes input/state/data/error JSON structure and escaping, not just a file's original bytes |
| HTTP callback request JSON |1MiB UTF8|Includes method/url/headers/body and JSON escaping, so usable form-body size is smaller |
| HTTP response body |1MiB streamed bytes|Full student snapshots and remote template sets must fit before UTF8 decoding |
| Connect/send/receive |15second transport controls|A single slow server call may fail before total invocation deadline |
| Mail refresh pages |50 host-side pages|Return nextCursor; remaining cursor means partial rather than complete |

The byte/character distinction matters: JSON containing nonASCII text can exceed a UTF8 byte budget before a character-count estimate does. A raw snapshot placed in both state and data multiplies JSON cost. Do not retain a full Prymus pupil snapshot in the secure credential state merely to reuse it across module invocations.

The absence of binary bodies does not rule out every file-transfer protocol. Prymus's form-based routes can carry repeated attachment/name/extension string fields; if the recovered producer uses Base64, a bounded pre-encoded string can be represented by the existing callback. That still needs a host file picker/input contract, accurate decoded/encoded size limits and exact repeated-key serialization. Do not replace repeated `attachments[]` fields with a JSON array or assume they are multipart without tracing the specific source caller.

## Normalized module shape

The standard read return is `{items:[normalizedRows], metadata:providerSpecificData}`; optional nextCursor/complete remain at module level. Do not return vendor HTML or a vendor envelope directly as items. `DiaryPlugins.sync` validates projected rows through SnapshotCache and keeps the complete module under profile providerData.

Key normalized row contracts from the cache codec:

| Module | Core keys / types |
|---|---|
| grades | string id/subject/value/description/date/category, numeric weight, integer semester; boolean countsToAverage; assessment string; optional previousGrades list |
| timetable | string id/subject/teacher/room/start/end; optional bool cancelled/substitution, original fields, movedTo date and number |
| homework/events | string id/title/subject/date/kind; kind must match EventKind, optional description/typeLabel/number |
| attendance | string id/date/subject/type/symbol/kind; integer lessonNumber and semester; kind must match the host enum |
| messages | string id/sender/subject/preview/receivedAt, bool unread/sent/hasAttachments, recipients list and optional recipientRead |

For exact cache spellings and optionality, inspect source-anchors.json and SnapshotCache before implementation. Missing required normalized fields should fail that module and retain stale data, not fabricate a successful empty list. Provider metadata can preserve raw statuses, source reference IDs, statistical aggregates and date semantics that these projection fields cannot express.

## Required host extensions must be explicit

A manifest can syntactically declare `submitJustification`, but that alone does not add a repository method, session interface, UI, pending-submission model or safe preparation rule. Extend them deliberately. New write operations must stay outside the safe-read automatic retry set and must checkpoint credential preparation without replaying the write.

For Prymus SHA256 authentication, first test whether a compatible self-contained pure-Dart implementation compiles and behaves under dart_eval. Importing `package:crypto` into a provider is not supported by the current package tool simply because the host SDK itself depends on crypto. A reviewed host crypto callback would be an ABI design change, not an existing capability.

For mobiDziennik remote controllers, the runtime has no JavaScript engine, DOM or browser session. Treat authenticated template/JS captures as evidence to reconstruct known request/DTO contracts. Do not wire server eval into the plugin VM or add a global unrestricted WebView as a shortcut.
