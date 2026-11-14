# Ordered implementation tasks for future agents

This runbook is documentation for a later implementation request. The current task adds no provider source, app patch or release. Use current main and its instructions, not the old application tree on the documentation branch. Baseline and exact edit anchors are in source-anchors.json.

## Dependency order and shared decisions

```text
N-01 evidence/capability ledger
  → N-02 owner/enrollment contract
  → N-03 VM/crypto/size feasibility
  → N-04 read adapters and DTOs
  → N-05 host projections/partial sync
  → N-06 mailbox
  → N-07 statistics
  → N-08 native justifications
  → N-09 files/extended enrollment
  → N-10 background/UI verification
  → N-11 immutable packaging/catalog
```

Pure synthetic fixture preparation can proceed before host changes. Keep a single owner for shared ABI/model edits. Provider source modules can be implemented independently once operation input/output contracts and account boundaries are agreed. Do not let two agents independently change DiarySession, SnapshotCache or credential-key format.

Each task should report changed paths, provider feature/operation IDs advanced, exact static/synthetic/live evidence, checks run and remaining gates. A prepared request, compiled bytecode or visible empty page does not by itself mean a feature is supported.

## N-01 — establish capability and evidence status

Inputs: provider specifications, operation ledgers, model fields, feature inventories, capture gates and this host source plan.

For every requested module classify: recovered request+decoder+caller, recovered bootstrap only, captured remote controller needed, local-only behavior, external handoff, or unsupported/unverified. Include effect category and whether safe retry is proven. For mobiDziennik, do not mark grades/stats/justifications ready solely because the generic form tunnel or menu label exists. For Prymus, tie each `wyslijDane` type to its exact caller/body/success interpretation.

Output: per-provider support matrix and fixture list. Acceptance: every proposed manifest operation has an independently implemented contract and a source/version reference; unknown write fields remain gated rather than guessed from another diary.

## N-02 — enrollment, ownership and per-school context

Files: future `plugins/<provider>/plugin.json`, `src/main.dart`; existing `diary_plugins.dart`, `diary_plugin_registry.dart`, `app_repository.dart`, `domain/profiles.dart`, onboarding `ui/shell/account.dart` only if a host gap needs work.

Implement authenticate/accounts against recovered enrollment. Return a canonical owner and stable opaque child IDs. Keep mobiDziennik central identity versus per-school login/sync URL separate. Keep Prymus enrollment token, derived security token, pupil identity and activated parent state distinct. Add localized login-field labels/instructions and reject malformed enrollment without persisting a partial account.

Acceptance: one owner with two school/child contexts; independent owner with identical display IDs; re-enrollment returns same stable profile where intended; school-year switch doesn't overwrite old scope; raw password/code/token isn't trimmed or transformed except where recovered; no credentials in providerData; cancel enrollment leaves no orphaned secure record. Reuse existing disk leases and profile storage.

## N-03 — prove runtime feasibility before building every module

Files: provider helpers and SDK fixture builders; `plugins/sdk/lib/src/plugin_runtime.dart` only if a deliberate ABI/policy change is required; `tool/package_plugin.dart`/shared helpers when needed.

For Prymus, prove securityToken's nested SHA256 under dart_eval using synthetic values and a frozen fixed-GMT+01 clock, including hour rollover and summer. Either compile an independently authored compatible pure-Dart algorithm in provider sources or design a narrowly reviewed host capability. Do not add a native/provider process or claim package:crypto is already importable.

Measure redacted snapshot/template payload sizes and latency from an authorized capture. Decide whether per-module fetch is acceptable, whether a batch read preserves budgets, or whether a versioned host limit/codec extension is necessary. The original client's90second timeout does not automatically fit current15second transport/45second invocation policy. Avoid persisting full snapshots as auth state.

Prymus source also contains trust-all TLS/hostname behavior and a numeric-IP fallback. They are not requirements to reproduce. The current host verifies HTTPS with exact legitimate origins and rejects numeric-IP hosts. Verify the legitimate production endpoint's normal certificate path; a failure should remain a transport/configuration gate rather than turning off verification globally.

Acceptance: bytecode compiles from all provider src files; SHA256 vectors and exact GMT+01 hour text pass; request and result sizes tested near the UTF8/JSON budget; 64-request/timeout/loop guards terminate; transport failure remains a module error, not a successful empty snapshot. A future batch design must still validate/apply modules independently.

## N-04 — request builders and provider DTOs

Files: future `plugins/mobidziennik/src/*`, `plugins/prymus/src/*`; synthetic provider tests under `plugins/sdk/test/`.

Implement exact form/query/body/header encoders and versioned response readers. Preserve repeated form keys and JSON-inside-form layers. Keep server IDs separate from normalized local profile IDs. Add pure DTOs or explicit map validation before normalizing. Preserve unknown enum values and source-specific fields in nonsecret metadata.

For mobiDziennik, acquire the missing authenticated module/controller capture first. Do not embed remote eval or claim that parsing arbitrary template text reproduces its data semantics. For Prymus, decode broad snapshot sections and relations consistently; do not read a local database autoincrement ID as the external server key.

Acceptance: complete method/URI/auth/body fixtures, Unicode/plus/ampersand/equals cases, exact field casing, absent versus null, status/error envelopes, singular/plural/list branches and malformed data. Request capture must not execute vendor source as part of adapter tests.

## N-05 — shared projections, metadata and partial sync

Files: `diary_plugins.dart`, `domain/models.dart`, `domain/diary_part.dart`, `snapshot_cache.dart`, `domain/together.dart`, `app_repository.dart` only where the existing contract is insufficient.

Use existing `{items,metadata}` modules, per-profile namespaced IDs, SnapshotCache validation and moduleErrors. Add optional typed detail for grade results, task answers, topics and native justification status instead of fake Grade/Event rows. Decide generic-calendar replacement semantics rather than leaving duplicates in the exam-only replacement path.

Acceptance: new metadata survives cache/copy/together round trip; missing/failed modules retain stale prior data; successful empty replaces covered data; optional unsupported module shows availability state; no cross-profile collision; credentials absent from cache; final/proposed/noncounted grades remain excluded from ordinary averages; incomplete attendance suppresses unwarranted percentage claims.

## N-06 — mailbox operations and effects

Files: provider mailbox helpers; `DiarySession`, downloaded wrapper and `DiaryPlugins` only for additive semantics; `ui/shell/messages.dart`, `message_compose.dart`, repository/controller and diagnostics.

Map recipients, folders/cursors, detail/acknowledgement, sending and deletion only where recovered. Prymus has multiple message/chat/parent surfaces; do not pretend every message has the same recipient discovery or send envelope. A source-local read flag is not proof of server acknowledgement. Keep mobiDziennik form queue writes outside routine reads.

Document MQTT as a separate transport capability. Existing HTTP plugins cannot open TLS8883 or keep broker subscriptions alive. A polling-only first implementation should state its confirmed snapshot coverage/freshness and preserve topic IDs; a future realtime bridge needs independent lifecycle, credential and duplicate-delivery tests.

Acceptance: folder pagination terminates, duplicate/cursor/no-progress cases handled, unread and local-new distinct, scope switch during load fenced, send timeout uncertain, detail-read effects recorded, no blind replay after credential recovery. Extend the current credential-only prepare allowlist deliberately for any new mutation and persist valid credential changes before sending it.

## N-07 — statistics and school/class comparisons

Files: typed provider metadata/schema; `domain/models.dart` or dedicated statistics module; grades/attendance views and localized source labels.

For Prymus preserve Na tle klasy histogram/base-grade class mean, selected-mark highlight, MarksResults/MarkAverage source identities, AttendanceStatistics and the exact regression/cumulative methods from the provider specification. Keep school/cohort-provided aggregates separate from a local personal estimate. Do not reuse the earlier Librus chart calculation as the Prymus algorithm.

mobiDziennik statistics remain unavailable until its school-specific controller/data contract is recovered. Existing local calculations can be offered only as explicitly labeled Siberia estimates with a defined denominator and complete input.

Acceptance: modifier/weight/inclusion rules, class histogram totals, selected-mark identity, sparse/out-of-order points, OLS zero-variance/insufficient-data handling, school-year/semester/subject switching, incomplete attendance, and multiple pupils in Together. Avoid adding a rank/percentile absent from the recovered consumer.

## N-08 — native electronic justifications

Files: proposed typed operation/result boundary in `DiarySession`/download wrapper, `DiaryPlugins`, repository/controller, dedicated DTO/pending store and attendance/parent UI. Existing `domain/parent.dart:AbsenceRequest` is a mailbox request record; do not overwrite its semantics.

Prymus type101 must serialize external attendance IDs in `frekw_id` as the recovered JSON-array string, not local host IDs or Librus lesson numbers. Preserve pupil/date/lesson/reason fields and parent-mode permission. mobiDziennik concrete controller/payload remains a capture gate when absent from the package.

Add explicit draft/submitting/confirmed-receipt/uncertain/rejected states. A local optimistic insert or response substring `true` alone is not an authoritative attendance update. Reconcile native request history and official attendance after accepted processing. No pending submission should run merely because background sync starts.

Acceptance: exact body/date/type fixtures, wrong-owner/external-ID rejection, only eligible account mode, double-tap, timeout after transmission, local optimistic state not confirmation, POST success plus failed refresh, app restart with pending outcome, profile removed during send and later server acceptance. Keep this mutation outside safe-read retries.

## N-09 — files and richer enrollment

Files: host file-selection/enrollment UI, typed adapter input, runtime callback only if required, attachment/detail models and cache policy.

For form-based string/Base64 uploads, preserve exact repeated attachment/name/extension keys, value ordering and association. Add decoded-byte and encoded-UTF8/JSON size limits. Do not convert them into multipart or a JSON-array field without evidence. For true binary download/multipart requirements, design a bounded explicit bridge instead of putting binary bytes into ordinary UTF8 body.

Keep Prymus task-reply JPEG recompression/default Base64 separate from raw-file NO_WRAP communication attachments. A user-visible file picker needs a declared transformation/filename policy; the plugin's raw-string callback does not supply Android Bitmap encoding by itself.

Prymus QR/native activation parity requires a real host enrollment action; current manifest field types cannot declare a camera flow. Account permission must come from server enrollment, not a role-override preference. Keep provider module cookies/tokens separate from an arbitrary download URL.

Acceptance: one/two files, mismatched metadata arrays, nonASCII filename, Base64 plus/padding encoding, oversized body, expired signed link, denied origin, partial upload/refresh outcome, cancelled picker, invalid QR and duplicate activation callback. Downloaded message detail/attachment methods must expose the recovered file metadata rather than silently return no attachments.

## N-10 — foreground/background/UI coverage

Files: `state/app_controller.dart`, `background_notifications.dart`, `school_notifications.dart`, `home_widget.dart`, `ui/shell/account.dart`, grade/attendance/mail/homework views and parent preferences.

Use existing profile slots, notify/together selection, quiet/digest settings and pinned widget ownership. Make capability/error/stale/uncertain states visible. A provider cannot be reported fully refreshed when only central login/templates were obtained. Do not turn a missing controller or denied module into an empty success.

Acceptance: both providers coexist with Librus/Fryderyk/MobiReg; sibling profiles isolated; owner lease serializes foreground/background; notification and widget links open correct profile; excluded Together pupil stays excluded; reconnect/removal does not resurrect credentials; offline view works from validated cached modules; user drafts survive recoverable read errors.

## N-11 — immutable packaging and release review

Files: new provider authoring directories, generated new release directories, `plugins/catalog.json`, SDK tests and `.github/workflows/plugins.yml` format source list.

The existing provider test builder is hardcoded to Fryderyk/MobiReg main.dart files. Add a builder that includes every src file for the new adapters, matching package_plugin.dart; otherwise separate SHA256/DTO helpers may compile in packaging but be absent from tests. Add new provider src paths to the formatting check, not only the catalog.

Run appropriate future checks from `plugins/sdk/`:

```text
dart pub get --enforce-lockfile
dart format --output=none --set-exit-if-changed lib test tool ../shared ../<provider-id>/src
dart analyze --fatal-infos
dart test
dart run tool/package_plugin.dart ../<provider-id> ../<provider-id>/<new-version>
dart run tool/validate_catalog.dart
```

Run relevant host checks from `syberia/` after actual host changes:

```text
flutter pub get --enforce-lockfile
dart format --output=none --set-exit-if-changed lib test
flutter analyze --fatal-infos
flutter test test/diary_plugins_test.dart test/plugin_installation_test.dart test/bundled_diary_plugin_test.dart test/profiles_test.dart test/parent_mode_test.dart
flutter test
```

The inspected workflows pin Dart3.13.3 and Flutter3.47.4. Native widget changes additionally require the recorded Swift simulator typecheck; SDK-only synthetic tests do not establish native Android/iOS execution. Packaging refuses overwrite; publish a new immutable version and review its catalog hash/size/permissions. User authorization for this documentation does not authorize a future deployment or a real pupil's submission.
