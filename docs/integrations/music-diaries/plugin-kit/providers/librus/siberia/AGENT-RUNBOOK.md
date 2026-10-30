# Future-agent implementation runbook

Documentation only. This runbook is a plan for a later implementation request. Quoted tasks do not authorize school-account actions, messages or deployment. Primary app baseline is `fdd022da1759caf254873fbb6d8ffdea7e360b68`, not the old application tree on the documentation branch. Recheck repository instructions, upstream source drift and [source anchors](source-anchors.json).

## H-LIB-01 — reconcile official operations with the current client

Inputs: official APK/IPA artifact identities, operation/DTO ledgers, [current request inventory](current-requests.json), [current behavior](CURRENT-BEHAVIOR.md). For each official operation mark: existing exact compatible transport, existing alternate source, new recovered capability, local-only UX, SDK/advertising/analytics, or unresolved. Bind the operation to exact request builder, decoder and UI call chain. Do not replace a working API/XML fallback because a newer route string exists. Output a version/role/entitlement matrix with static/live statuses separate.

Acceptance: all official feature IDs retain a disposition; every enabled network operation has exact method,origin,auth,encoding,parameters,response contract and effect. Distinguish licensed/module-specific capability from account authentication. Do not copy third-party tracking/advertising into Siberia as diary parity.

## H-LIB-02 — service adapters and typed outcomes

Files: `data/librus/librus_client.dart`, `domain/librus_error.dart`, `domain/models.dart`, `data/snapshot_cache.dart`. Extract minimally separated Portal/API/mail adapters as needed while retaining compatibility facade. Add DTO→normalized mapping rather than decoding official JSON straight into UI types. Change optional failure handling so a failed module is stale/error and a successful empty response replaces its data. Preserve exact `Code`/structured errors in redacted diagnostic form. Separate fetch coverage from payload emptiness.

Output: typed service operation results and module freshness; additive cache schema and migrations; explicit unsupported status. Acceptance fixtures: optional403/401/timeout/malformedJSON vs valid empty; role denied vs missing module; partial sync; unknown enums; existing cache round trip. Existing read tests must remain unchanged or intentionally explained.

## H-LIB-03 — account/session safety

Files: `data/librus/librus_logins.dart`, `librus_client.dart`, `data/app_repository.dart`, `state/app_controller.dart`, `data/profile_store.dart`, `domain/profiles.dart`. Preserve existing shared-owner login plus per-profile child tokens/cookies. Introduce owner removal/token-generation guards if tests demonstrate late refresh can restore deleted credentials. Decide background-isolate token update ordering; in-memory queues alone are not durable locks. Keep a sibling profile's usable login when removing one profile.

Output: documented state machine for Portal owner + each profile's API and module sessions. Acceptance: siblings renew once, independent account not blocked, refresh failure retains or correctly invalidates material, logout/remove during refresh cannot resurrect, switching away/back doesn't publish stale data, aggregate profile-set change is guarded. A refreshed Portal token is never serialized as a child API token.

## H-LIB-04 — origin, redirect and cookie contract

Files: `librus_client.dart` `_request`, `_storeCookies`, `_Cookie.matches`; `debug/diagnostics.dart`; tests `librus_client_test.dart`, `diagnostics_test.dart`. Encode redirect policy per service; model cookies with relevant host-only/domain/path/Secure/expiry semantics. Preserve mailbox302cookie acquisition. Do not forward password/token body or sensitive headers across an unexpected307/308host. Do not generalize the old MAINT transformation to every cookie family. Keep diagnostics query-free and redact sensitive path segments such as token/fresh IDs.

Acceptance: redirect relative/absolute;303and POST301/302 rewrite;307/308 body policy; custom scheme terminates;18redirect cap; exact domain and path boundary; expired/deleted cookie; same-name different-path cookies; token-in-path redaction; no response body logging. These are protocol fixtures, not permission to call unrelated hosts.

## H-LIB-05 — DTO completeness and data projection

Files: `domain/models.dart`, `data/snapshot_cache.dart`, `data/librus/librus_client.dart`, `domain/together.dart`, relevant `ui/shell` views and `l10n/app_localizations.dart`. Use [DTO mapping](DTO-MAPPING.md). Preserve server IDs, reference IDs, raw statuses, rich content and optional typed detail. Avoid unstable hashCode/now identities for new records. Update withSource/copy/equality/serialization for every new field and source-bound operation. Retain existing grade improvement chain and school-local calendar helpers.

Acceptance: old cache loads; new DTO fields survive copy/cache/together round trip; same remote ID in two profiles remains distinct; aggregate operation unwraps local ID; descriptive grade isn't0; unknown attendance isn't present; two simultaneous lessons don't collide; DST date stays school day.

## H-LIB-06 — complete reads and pagination

Files: API operation adapters, mail adapters, `AppRepository`, `AppController`, `ui/shell/messages.dart`. Add only recovered page/cursor recipes; first request presently fetches50API messages on page1. Source fallback completeness differs; annotate it. Isolate folder/search/cursor/request generations. Support cancellation and bounded loading. One source's max ID cursor is not another source's page number.

Acceptance: first/last/empty page, duplicates during concurrent new mail, folder switch mid-fetch, search cleared, source fallback mid-pagination, archive scoping. No endless retries for denied/unknown module. Current sent pause2minutes is UI throttle, not server TTL.

## H-LIB-07 — recovered writes and attachment flows

Files: service operation adapters; `AppRepository`; `AppController`; `ui/shell/message_compose.dart`; typed homework/justification UI when recovered; cache serializers. Explicitly classify local marks, server read acknowledgements, sending, upload, delete, archive, restore and submission. Keep SendMessage excluded from blind session-retry. Separate compose-created ID from attachment transfer; persist confirmed partial success. Do not expose a write whose parameter/permission contract is unresolved.

Acceptance: exact UTF8/Base64/XML fields for existing SendMessage; missing ID despite statusok; timeout aftersend→uncertain; recover read safely; readall partialsuccess; same ID wrong profile rejected; attachment upload retry doesn't recreate message; local done mark never sends server submission. Controlled live tests require an authorized test recipient/account.

## H-LIB-08 — profile/UI/platform coverage

Files: `ui/shell/account.dart`, `onboarding_sign_in.dart`, `messages.dart`, `events_homework.dart`, `together.dart`, `school_notifications.dart`, `background_notifications.dart`, `home_widget.dart`, native widget stores. Extend existing per-profile slots/notify/together settings; do not reintroduce a singleton profile. Action buttons should display module capability and retained stale errors coherently. External modules require distinct opening/session rules, not reusing arbitrary cookies in browser URLs.

Acceptance: add/readd/remove profile; parent/student entitlement difference; included/excluded aggregate profile; source notification navigation; widget pinned to correct profile; background disabled leaves foreground usable; offline-first load; reconnect keeps another account; no accidental ad/payment/analytics dependencies.

## Validation commands for future code changes

Run from `syberia/` on the implementation branch using the toolchain in its workflow (inspected workflow uses Flutter3.47.4). These commands are proposed checks, not results from this documentation task:

```text
flutter pub get --enforce-lockfile
dart format --output=none --set-exit-if-changed lib test
flutter analyze --fatal-infos
flutter test test/librus_client_test.dart test/profiles_test.dart test/profile_notifications_test.dart test/together_test.dart test/diagnostics_test.dart
flutter test
```

Choose focused tests for the touched module first. Existing suites also include profiles_ui,profile_widgets,profile_demo,background_check,auto_sync,sent_messages,message_read_and_layout,homework,homework_done,timetable_sync,calendar_days and grade calculators. Native iOS widget changes additionally require the workflow's Swift simulator typecheck. Static documentation consistency checks do not replace these code checks, and synthetic fixtures do not establish server acceptance.

Future-agent output should report changed paths, advanced feature/operation IDs, exact checks/results, fixture provenance and unresolved live gates. Update source anchors deliberately after reviewing a source change. Do not claim full official parity solely from adding endpoints.
