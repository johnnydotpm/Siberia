# Current host behavior and integration gaps

All source paths are repository-relative and refer to inspected main `eb7a4d566f449ebcb2e8c3bce62721c50beb7c7c`. Literal anchors and file hashes are in source-anchors.json. This document describes existing source, not live deployment correctness.

## Distribution and registration already exist

`plugins/README.md`, `plugins/sdk/lib/src/manifest.dart`, `plugin_store.dart` and `plugin_runtime.dart` define downloadable first-party plugins. The catalog at `main/plugins/catalog.json` offers Fryderyk, MobiReg and Librus Legacy; Librus is bundled and wins over any catalog entry with its ID. The app default source is `https://raw.githubusercontent.com/johnnydotpm/Siberia/main/plugins/`; `DIARY_PLUGIN_SOURCE` can explicitly select another HTTPS directory for development.

`syberia/lib/src/data/diary_plugin.dart` defines the shared `DiaryPlugin` and `DiarySession` interfaces. `diary_plugin_registry.dart` selects the bundled adapter or a downloaded wrapper according to `SchoolProfile.providerId`. The repository signs in through that registry and creates profiles through `addPluginProfiles`, retaining provider ID/name and opaque `pluginStudent` IDs. New providers should normally use this existing path instead of hardcoding their traffic into the UI or adding a second registry.

The onboarding field schema currently supports only `text`, `url`, `password`; labels are translated with `context.tr`. Localized instructions select the current language, then English, then the first provided text. There is no manifest field type for QR camera scanning, device approval, role picker or browser OAuth. Manual token input may support an initial Prymus onboarding path, but full QR/activation parity requires a deliberate host extension and tests.

## Session ownership and locking already exist

`DiaryPlugins.connect` installs the selected verified release before calling `authenticate`. It accepts returned owner data and hashes it into `plugin-<provider-id>-<sha256(ownerData)>`. It invokes `accounts` before storing the secure record and requires at least one student. `SchoolProfile.idFor(account, 'plugin:<child-id>')` creates the stable local profile identity; siblings can share a credential owner while retaining separate snapshots and notification slots.

Secure records use `diary_plugin_account_v1_<owner>` and contain the pinned manifest and returned provider state. `_locked` uses exclusive disk files and lease fencing across foreground/background isolates:50second wait budget, five-minute stale-lease threshold,15second heartbeat. The final state save checks that the lease still belongs to the invocation. Reuse this machinery. A provider should not implement a conflicting global token singleton or copy one rotating credential into every child snapshot.

An owner is whatever canonical `authenticate.data.owner` the independently authored adapter returns. Therefore its exact string format matters. It must distinguish provider, legitimate server/tenant, account enrollment and any identity boundary proven by the source. A mutable selected pupil or school year should not accidentally rename the owner and orphan every profile. Conversely, two independent school logins must not collide because they have the same display name or numeric pupil ID.

Per-account allowed origins are carried in provider `state.origins`. The host validates them as exact HTTPS origins and supplies them to the next invocation. The current code validates the syntax of returned origin lists; provider authors must additionally constrain discovery to legitimate authenticated endpoint data. Do not describe a state string as proof that a new authority is authorized, or treat arbitrary returned URLs as credential destinations.

## Data reads already dispatch per module

`DiaryPart` has grades, timetable, events, homework, attendance, announcements, notices, messages and luckyNumbers. `DiaryPlugins.sync` creates one VM invocation per requested module, retaining omitted or failed modules from the old snapshot. New modules are validated through SnapshotCache before replacement. Successful empty data replaces the corresponding module; a failed module retains prior data plus `moduleErrors`.

Normalized results use `{items:[...],metadata:...}`; the complete module object is retained under that profile's `providerData`. `attendance.complete:false` sets `attendanceComplete:false`. `nextCursor` marks the result partial. Native metadata such as raw grade categories, school-computed statistics, period references and unknown source codes can stay there while the ordinary UI uses normalized rows. Credentials, password hashes, authenticator secrets, raw login responses and module cookies must stay in secure provider state, never providerData.

The host adds a local profile prefix plus base64url raw ID when mapping network rows to shared models. Recipient IDs remain opaque strings and carry their owner. Message operations reverse that local ID only for the matching profile. Do not pass a local prefixed ID directly to a provider request or parse all identifiers as integers.

## Current mailbox coverage

Downloaded sessions expose recipients, send, inbox/sent listing, detail/read acknowledgement and delete. Mailbox aggregation follows `nextCursor` for at most50pages, rejects repeated cursors, and retains a remaining cursor as incomplete. The adapter must ensure list reads do not acknowledge messages unless that side effect is explicitly intended and documented.

`invoke` optionally performs a credential-only `prepare` checkpoint before message, sendMessage and deleteMessage. The safe-read allowlist can refresh/account-discover/retry once after `session_expired`; mutations are outside it. A provider operation named `grades` that secretly drains a queued form mutation would violate this assumption. A new mobiDziennik adapter must keep explicit writes separate from ordinary synchronization even when the original shell uses one tunnel for both.

`send` marks many ambiguous failures as `send_uncertain`, preserving the need to check Sent. `deleteMessage` requires `{deleted:true}` from the adapter. These are useful patterns for future explicit absence submissions, but the host has no universal submission-result type yet.

## Capabilities that still need host work

| Surface | Current source | Required future decision |
|---|---|---|
| Provider-native absence/justification write | No method in DiarySession; parent AbsenceRequest is a mailbox-request log | Add an explicit typed operation/UI/result flow before exposing Prymus type101; do not route it through sendMessage |
| Justification history/status | Arbitrary plugin operation can exist and `justifications` is a safe-read name, but no shared DiaryPart/UI projection | Preserve native metadata, then add a typed read module/page and explicit capability state |
| Binary attachments | HTTP bridge accepts UTF8 body strings; downloaded `attachment()` throws and detail constructs `attachments:[]` | Add a reviewed binary/download API and typed host exposure; do not fake support with a URL field alone |
| File upload/multipart | No file-selection capability in plugin ABI; HTTP bodies are raw strings | Recovered text/Base64/repeated-form-field uploads may fit the existing callback; add bounded UI/input handling. True binary/multipart endpoints require a deliberate bridge extension |
| Enrollment QR/device approval | Only text/url/password fields | Add a clear host enrollment capability or ship a documented manual-token path initially |
| Statistics/averages beyond current grade records | providerData can retain them; ordinary Grade and current charts do not describe arbitrary cohort/result arrays | Add typed metadata/UI and provenance; do not inject aggregates as fake Grade rows |
| Broad native snapshot | Sync dispatches each module independently with a fresh VM | Evaluate one optional bulk-read path for Prymus, preserving per-module validation/failure behavior |
| Provider cryptography | Package compiler includes only diary sources and shared protocol helpers | Supply compatible pure Dart code or intentionally extend the reviewed host ABI; a package import alone does not work |
| Prymus MQTT chat | HTTP callback only; no arbitrary TCP/TLS sockets or MQTT capability | Poll a verified snapshot path with an explicit freshness label, or design a reviewed realtime bridge; do not call polling realtime parity |
| Remote JS templates/controllers | No JavaScript evaluation capability | Keep them as capture evidence; reconstruct explicit DTO/rendering contracts after controlled capture |

The current parent-mode `AbsenceRequest` stores mailbox delivery state `sent`/`uncertain`, selected attendance record IDs and message identity. It does not prove that the school accepted an official electronic justification. Native Prymus submission must have a separate source/type/outcome and later attendance reconciliation.

## Model and UI behavior relevant to statistics

`Grade` now explicitly preserves `countsToAverage` and `assessment`, and the calculator excludes noncurrent/noncounted records. Existing migration defaults remain compatible. Keep those flags; old first-pass instructions proposing their creation are outdated.

`AttendanceKindDetails.countsAsPresence` treats present, late, late-excused, released and other as presence-like. A provider's unknown code must not be silently mapped to other merely to satisfy this enum; preserve raw source code and completeness. Prymus AttendanceStatistics can carry a school-defined denominator distinct from a locally counted list. Show the origin of any percentage, selected semester and completeness, and retain source totals for reconciliation.

The source already supports per-profile notification/together/widget settings and background sync. Extend that flow instead of creating a global provider cache. Preserve decoded content as text/typed rich data through `pluginText`; executing downloaded mobiDziennik HTML/JS is not an implicit consequence of adding a diary.
