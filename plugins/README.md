# Diary plugins

Plugins belong in **`/plugins/` in `johnnydotpm/Siberia`**, alongside `syberia/`.
Librus remains built into the application; it is not a downloaded plugin.

## Current status

Fryderyk and modern MobiReg now have versioned, independently authored adapters.
The Flutter app downloads the selected plugin **before sending login data**,
then uses its installed, pinned release for login, child profiles, foreground
and background synchronization, messaging, notifications and widgets. Librus
continues to use its existing built-in client.

The `dev` app uses the repository's `dev/plugins/` catalog by default. Set
`DIARY_PLUGIN_SOURCE` to the `main/plugins/` HTTPS directory when promoting the
feature. Existing accounts retain their installed manifest/version; catalog
changes do not silently change an account's protocol.

See [Fryderyk](fryderyk/README.md), [MobiReg](mobireg/README.md) and
[research provenance](RESEARCH.md) for coverage and remaining gates. Tests use
synthetic responses. No live school account or device build was used to verify
current backend acceptance or native execution.

## Repository layout

```
plugins/
  catalog.json                     # one currently offered release per diary
  <provider-id>/
    src/                           # independently authored adapter source
    plugin.json                    # authoring metadata
    <version>/
      manifest.json                # generated release metadata
      plugin.evc                   # downloadable interpreted bytecode
  shared/protocol.dart             # bundled adapter normalization helpers
  examples/echo/main.dart           # test fixture, never in catalog.json
  sdk/                             # pure Dart loader/runtime + release tools
```

Releases are immutable. Publish a new version rather than changing an existing
artifact. The catalog selects a version; an installed profile must pin its
manifest and keep it locally, so it works offline and does not silently change
protocol on every sync. The production source is:

`https://raw.githubusercontent.com/johnnydotpm/Siberia/main/plugins/`

`PluginStore(source: ...)` accepts an explicit HTTPS directory for development
against `dev`. Shipping dev instead of main must be an explicit app decision.
The catalog and artifacts are distributed from this repository; third-party
catalogs are not discovered automatically.

## Manifest v1

An entry in `catalog.json.plugins` is the same object as the release's
`manifest.json`. Fields:

| Field | Meaning |
| --- | --- |
| `id` | Lowercase provider identifier, e.g. `fryderyk` |
| `name` | Diary display name |
| `version` | Numeric `major.minor.patch` release version |
| `apiVersion` | Host ABI, currently `1` |
| `runtime` | Bytecode/runtime pin, currently `dart_eval-0.8.5` |
| `artifact` | Exactly `<id>/<version>/plugin.evc` |
| `sha256` | Lowercase SHA-256 of the downloaded bytes |
| `bytes` | Exact length, at most 4 MiB |
| `operations` | Supported operation identifiers; unsupported is an error |
| `origins` | Exact allowed HTTPS origins, without paths or wildcards |

Catalog envelope: `{"schemaVersion":1,"plugins":[...]}`. Duplicate identifiers,
incompatible versions, unsafe paths, redirects, oversized files, partial files
and hash mismatches are rejected. Downloads are staged and atomically renamed.
A failing update leaves earlier installed releases intact. SHA-256 checks bind
an artifact to its catalog entry; they are **not a separate publisher signature**.
Repository access and HTTPS establish catalog trust.

## Execution ABI v1

A plugin is authored in the subset of Dart supported by dart_eval 0.8.5 and
packaged ahead of time as interpreted `.evc` bytecode. The host does not compile
source, load a native library or require JIT execution. The SDK tests run on the Dart VM here; native Android/iOS integration has not
been tested yet.

Entrypoint in `package:diary/main.dart`:

```dart
Future<String> main(String requestJson, Function http) async {
  // Decode request, perform only the requested operation, return JSON.
}
```

Input: `{"operation":"grades","input":{...},"state":{...}}`.
Output: `{"data":...,"state":{...}}` or an error with a stable `code`. Both cross the boundary as JSON strings. Auth refresh is a separate checkpointed operation. Each data module is invoked separately, so one failure cannot erase another module.
A new VM and isolate are created per invocation; there are no persistent globals.
The SDK does not interpret a provider's error/success envelope as a list of data.
The adapter must validate it and fail on incompatible or unknown schemas.

The only host capability is `await http(requestJson)`, where the request is:

```json
{
  "method": "POST",
  "url": "https://school.example/api",
  "headers": {"Content-Type": "application/json"},
  "body": "{\"field\":\"value\"}"
}
```

`body` is a raw string or absent/null; the host does not trim passwords or
rewrite JSON, form fields or HTTP methods. The returned JSON string contains
`status`, `headers` (lists of values), and raw UTF-8 `body`. HTTP error statuses
and redirects are returned to the adapter without automatically following them.
The host rejects requests outside the manifest's exact origins plus explicit
per-account grants. During enrollment the app validates HTTPS origins supplied
in declared server fields or returned by the authenticated bootstrap/discovery
operations, then stores those grants with that account. A running plugin cannot
add a grant. Mail and homework are separately scoped endpoints; the adapters do
not attach diary JWTs to module or attachment URLs. Redirects are not followed.

Default limits: 45 seconds per invocation, 64 HTTP requests, 1 MiB per JSON/HTTP
body. A timed-out isolate is killed and its network work cancelled. The VM gets
no filesystem/network/process permissions; HTTP goes through the host callback.
Plugin print output and internal exception text are discarded. Isolates do not
provide a memory quota or a security boundary for hostile native code. Only
reviewed first-party plugin releases belong in this catalog.

## Account and app integration

`syberia/lib/src/data/diary_plugins.dart` owns installation, secure account state
and the normalized DTO boundary. Provider paths, envelopes, decoding and request
serialization live in plugin bytecode. Release manifests declare credential
fields and localized login instructions; adding a diary does not require a new
provider-specific login form in the app.

An auth owner is provider + canonical server/tenant + account, hashed into a
separate secure-storage key. Sibling child profiles share that credential record
and keep separate data caches. Exclusive disk leases serialize operations across
foreground/background isolates. Lease fencing and profile-removal guards reject
obsolete results. Removing the last child deletes its owner's credentials;
signing out clears all plugin owners.

The app validates normalized module payloads through its cache codec. Missing,
unsupported and malformed modules retain their previous data and carry a visible
status. Server raw academic metadata (periods, final/proposed assessments,
unknown codes, summaries) stays under that profile's `providerData`; it is not
mixed into ordinary grade averages. Auth state and module tokens never belong in
that snapshot. Excluded grades are excluded from averages even in unweighted
mode. Opaque recipient keys remain strings, including leading zeroes.

Mailbox pages are read without acknowledging messages, at most 50 pages per
refresh. A remaining cursor is shown as incomplete data. Opening a message uses
the provider's documented read acknowledgement. Sending is never automatically
retried; an uncertain result asks the user to check Sent first. Attachments and
provider-native absence submissions are not yet exposed by this release.

## Authoring and checking

Use `plugin.json` containing `id`, `name`, `version`, `operations` and `origins`,
and adapter sources under `src/` (`main.dart` is required). From `plugins/sdk`:

```sh
dart pub get --enforce-lockfile
dart analyze --fatal-infos
dart test
dart run tool/package_plugin.dart ../<provider-id> ../<provider-id>/<version>
dart run tool/validate_catalog.dart
```

Packaging writes `plugin.evc` and `manifest.json` and refuses to overwrite an
existing release. Review and copy that manifest into `catalog.json.plugins`
only after adapter tests pass. These tools do not build the application or
create an APK/IPA. CI validates the catalog, SDK and test fixture on plugin
changes; application release builds remain manual.
