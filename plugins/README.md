# Diary plugins

Plugins belong in **`/plugins/` in `johnnydotpm/Siberia`**, alongside `syberia/`.
Librus remains built into the application; it is not a downloaded plugin.

## Current status

This directory contains a working distribution/execution SDK and its synthetic
integration tests. **The app's login and synchronization still use Librus.** The
SDK is not yet connected to the add-diary screen, account store or background
sync. `catalog.json` is intentionally empty: there are no published, working
Fryderyk or MobiReg adapters here yet. The echo example is an SDK test fixture,
not a diary and not demo school data offered to users.

The research on branch `docs/music-diary-reverse-engineering-2026-10-25` describes
protocols recovered from shipped clients. It is input for implementing adapters,
not proof that today's servers accept those requests. No live school account
was used to test this SDK.

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

Input: `{"operation":"sync","input":{...},"state":{...}}`.
Output: `{"data":...,"state":{...}}`. Both cross the boundary as JSON strings.
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
The host rejects requests outside the manifest's exact origins. In v1 all
origins are static: dynamic school-origin enrollment and cross-module cookie
scopes need a host-managed per-account grant design before those adapters ship.
Do not solve this with unrestricted host access or blanket token forwarding.

Default limits: 45 seconds per invocation, 64 HTTP requests, 1 MiB per JSON/HTTP
body. A timed-out isolate is killed and its network work cancelled. The VM gets
no filesystem/network/process permissions; HTTP goes through the host callback.
Plugin print output and internal exception text are discarded. Isolates do not
provide a memory quota or a security boundary for hostile native code. Only
reviewed first-party plugin releases belong in this catalog.

## Account and app integration requirements

The next integration must download a selected release **before submitting login
credentials**, show install/network errors, and reuse the installed release for
subsequent sync. Existing Librus profiles must continue to work unchanged.

The host owns auth state in secure storage, scoped by provider + canonical
server/tenant + account. Child and academic-period data have separate scopes.
Serialize auth mutations per owner and reject late results after switching or
removing an account. Do not store credentials in this package cache or in logs.
Persist a rotated token pair atomically after validating the complete operation
result; uncertain mutations must not be retried automatically.

The SDK deliberately does not yet define school DTOs. The app integration needs
a versioned normalized data contract (including opaque recipient identifiers,
unsupported capabilities, partial failures, textual grades and parent roles).
An unsupported module is not an empty record list. Failed modules retain their
last successful data. Message sending and absence submissions require user
confirmation and remain bound to the selected account.

## Authoring and checking

Use `plugin.json` containing `id`, `name`, `version`, `operations` and `origins`,
and adapter sources under `src/` (`main.dart` is required). From `plugins/sdk`:

```sh
dart pub get --enforce-lockfile
dart analyze
dart test
dart run tool/package_plugin.dart ../<provider-id> ../<provider-id>/<version>
dart run tool/validate_catalog.dart
```

Packaging writes `plugin.evc` and `manifest.json` and refuses to overwrite an
existing release. Review and copy that manifest into `catalog.json.plugins`
only after adapter tests pass. These tools do not build the application or
create an APK/IPA. CI validates the catalog, SDK and test fixture on plugin
changes; application release builds remain manual.
