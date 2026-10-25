# Proposed integration design — not existing Siberia API

The current application is a Flutter app in `syberia/`, with Librus-specific gates and shared state. These names describe a proposed boundary, not classes already present. Apply the [source plan](siberia/SOURCE-PATCH-PLAN.md) before connecting provider traffic.

## Ownership must precede transport

Use two identities. `AuthOwner` identifies `(provider, canonical server authority, tenant/school, account)`. `DataScope` adds `(pupil, academic period)` to that owner. A parent switching children retains the same auth owner; school switching changes the owner even when the login text matches. A pupil ID is only unique inside its provider/server/tenant namespace.

Store tokens, refresh material and account credentials under the auth owner. Store grade/timetable/homework snapshots under the data scope. Store mailbox cookies under `(auth owner, mail module origin)`, and homework cookies under `(auth owner, homework module origin)`. Store mailbox content under its account-level context unless a recovered request actually includes a pupil. Do not invent a child parameter to make every operation fit one abstraction.

Illustrative Dart design fragment; it requires adaptation to Siberia's models and persistence:

```dart
// Proposed types, not an installed plugin interface.
enum ProviderId { librus, fryderyk, mobireg }
typedef AuthOwner = ({String provider, String authority,
  String tenant, String account});
typedef DataScope = ({AuthOwner owner, String pupil, String period});

enum ModuleState { success, stale, failed, unsupported }
// Payload and error types intentionally omitted from this design fragment.
```

`ModuleOutcome<T>` is the proposed typed result carrying state, optional payload, freshness and a structured error. `RequestSpec` is the proposed request description carrying operation ID, owner/scope, method, URI, body encoding and effect category. `DiaryTransport` would execute a spec; `DiaryPlugin` would expose provider identity, capabilities and operation dispatch; a registry would select it by provider ID. These are design responsibilities rather than required public class names. The source plan may name a narrower app-facing interface for one subsystem.

Canonicalize a host for identity without changing user-visible account labels. Do not lowercase a case-sensitive path, login, QR code, token or password. Keep IDs as opaque strings at the integration boundary; only convert to integers at fields proven numeric. Retain original provider IDs and enum values alongside normalized values. Recipient IDs may be strings; existing integer-only Siberia models need an additive mapping.

## Request boundary

Each operation description should bind an operation ID, transport family, auth owner, optional data scope, exact encoding, and effect category. Categories should distinguish pure read, read-with-server-side-effect, mutation, authentication and local action. An implementation may represent them with a `RequestSpec`, but the JSON ledgers here are documentation and do not constitute a universal executable schema.

Keep separate encoders for Fryderyk JSON, legacy MobiReg form, modern MobiReg gateway form, modern MobiReg Bearer REST, mail cookie JSON/multipart and homework cookie JSON/multipart. They share an HTTP adapter, not an authorization decorator. Explicitly prohibit sending the main JWT to an attachment URL merely because that URL appeared in a response.

A transport adapter should accept already constructed request data, honor cancellation and return status/headers/raw bytes. Provider code owns envelope interpretation. This prevents a common `status == 200` or generic `data` unwrap from changing module semantics. Decoding errors are protocol failures, not automatically credential failures.

## Session and asynchronous result isolation

Capture the owner, scope and a monotonically increasing selection generation before starting work. After every awaited request, refresh, download or decode, verify that the result still belongs to the captured context before publishing it to active UI state. Successful late results can be retained in the matching cache, but cannot replace the newly selected child's screen.

Illustrative publication guard:

```dart
final capturedGeneration = selectionGeneration;
final capturedScope = selectedScope;
final result = await fetchFor(capturedScope);
if (capturedGeneration != selectionGeneration ||
    capturedScope != selectedScope) return;
publish(result);
```

This fragment alone does not scope credentials, cancel a request or make cache writes safe. Scope those separately. A token refresh lock is per auth owner, not global and not per child. Persist rotated credentials together; prevent a response using an older token generation from overwriting a newer rotation. Do not clone refresh tokens into each pupil profile.

## Capabilities and partial sync

Compute capabilities from provider generation, role, configured modules, discovered context and proven server response. An unsupported feature should have a reason such as `moduleNotConfigured`, `roleNotSupported` or `contractNotRecovered`. Unknown capability is distinct from forbidden and distinct from empty data. A newly added provider should not report successful sync when dispatch was skipped by a Librus-only branch.

Sync modules independently. Keep last successful grades when mail SSO fails. Merge successful results with their own updated-at and freshness state. Distinguish `success with zero items` from `failed; keep stale items`. Store the raw provider value for unknown enum cases and show a neutral fallback; never assign an unknown attendance code to present.

List pagination needs request identity and a scope-specific cursor. Do not append an inbox page to sent mail, mix search results with unfiltered results, or reuse a page after changing term/child. For Fryderyk fixed page size8 and MobiReg mail limit20, advance the provider's own page/offset, not a shared guessed increment.

## Additive model evolution

Use provider DTOs before normalized Siberia models. A DTO preserves source nullability, nested music-specific lesson/exam/accompaniment data, role relations and provider-only statuses. Mapping should explicitly list losses. Do not flatten every music-school lesson into a generic subject/teacher pair and silently discard the rest.

Keep durable local IDs separate from network IDs. Namespace notification identities, attachment caches, pending operations and widget storage. Background isolates must load the provider/session registry and the same scoped storage migration as foreground code. The existing Librus profile format must remain readable; migrate transactionally and test an upgrade from existing persisted state.

## Implementation sequence

1. Add ownership and migration without enabling new network traffic; verify existing Librus behavior.
2. Add provider dispatch and module outcomes; remove false-success paths.
3. Add exact credential flows and discovery; verify a controlled account before enabling mutations.
4. Add read modules with DTO fixtures and stale-data handling.
5. Add module SSO and mail/homework separately.
6. Add supported writes with explicit pending/confirmed/uncertain results and partial attachment handling.
7. Extend background sync, notifications, widgets and settings only after the same ownership rules work in foreground.

The detailed tasks, file anchors and acceptance criteria are in the Siberia subdirectory. No step implies that the current repository already has a dynamic plugin loader.
