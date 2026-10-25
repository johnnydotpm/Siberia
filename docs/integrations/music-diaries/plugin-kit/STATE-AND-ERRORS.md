# Session, failure and retry specification

This document combines observed client behavior with explicitly labeled implementation recommendations. Provider specifications carry exact caller evidence. Recommendations prevent data mixing and duplicate writes; they do not claim the original clients implement these protections.

## Fryderyk session

Observed: identify stores username, access token, refresh token and discovered data URL. Access-token acquisition uses JWT expiry and a shared refresh future; expiry is checked against now without a recovered early-refresh margin. Refresh uses stored username and refresh token and rotates token material. The single-flight slot is cleared on completion and failure. Logout clears four secure-storage values and cache; no server token-revocation call was recovered.

Recommended state transitions: `signedOut → identifying → ready`; `ready → refreshing → ready`; terminal credential failure → `needsLogin`; transient refresh failure → retain recoverable material and report failure. Namespace secure keys per auth owner instead of copying the original four global keys. Refresh and logout must serialize against the same owner so a late refresh cannot repopulate a logged-out account. A clock-skew margin would be a Siberia policy, not recovered behavior.

## MobiReg modern session

Password login, QR exchange and refresh are separate entry points. QR produces a login/account context and can provide refresh material. A password account may retain its stored password when updated by QR; a QR-only account must not invent a password. Password login's successful branch does not store a refresh token. A replacement refresh token is optional on refresh; absence preserves the existing one.

The gateway `getToken` merely reads secure storage; it does not itself check JWT expiration or refresh. A401 invokes the unauthorized callback once, guarded by a resettable flag, without automatically retrying the request. Do not document automatic refresh as observed behavior. A future adapter may orchestrate explicit recovery, separately from the transport helper.

Context discovery must complete before pupil-dependent views. `users` is account-level (`requirePupil:false`) and supplies role/pupil context plus module URL/token configuration. Module availability depends on these discovered values. A missing homework URL does not mean there are zero homework records.

Mailbox and homework have independent SSO state. Mail SSO obtains cookies while redirects are disabled, including cookies from a redirect response. Mail helper auth failure statuses are401/403; homework uses401/419. An HTML login page returned as200 is a decode/protocol failure until proven otherwise; do not report it as an empty successful list.

## Operation outcome and retry matrix

| Condition | Required outcome | Retry guidance |
|---|---|---|
| Read times out before response | Module failed/stale; preserve previous data | Bounded retry of a pure read only |
| DNS/TLS/offline failure | Transport failure; account not automatically invalid | Resume when connectivity returns |
| Malformed JSON / wrong DTO type | Protocol failure with redacted location | No infinite auth-refresh loop |
|401 on main API | Needs session recovery; preserve owner | Recover only the matching owner, re-evaluate replay safety |
| Mail401/403 or homework401/419 | Recover that module's session | At most one SSO cycle; mutation replay requires outcome reconciliation |
| Forbidden role/action | Capability/permission error | Do not repeatedly log in |
| Fryderyk426 | Client compatibility/version error | Surface upgrade/incompatibility state |
| HTTP success with business error | Business failure with provider code | Follow the operation's policy |
| Mutation timeout after sending | `uncertain`, not `failed with no effect` | Reconcile state; no blind replay |
| Message created, some files failed | Confirmed creation + partial attachments | Retry only unresolved file transfers if safe |
| Unsupported operation | Explicit unsupported reason | Never return a successful empty payload |

Safe-looking GET can acknowledge a mail read. Authentication can register devices/sessions. Archive PATCH toggles state rather than setting an explicit target boolean. Classify these as effects and handle retries accordingly. No idempotency key or universal deduplication guarantee was recovered.

## Legacy synchronization transaction

Legacy full sync and delta sync are distinct. Shared library export tables do not prove parent write permission. Apply import actions according to table mappings: insert/replace, update/upsert and delete; omitted action defaults to insert. Stage the result and apply all related tables with cursor advancement in a durable transaction. A crash after half the tables must not move the cursor past unprocessed changes.

Persist cursor by auth owner plus the server/sync context proven in the provider report. Preserve local read state and acknowledgement queue separately; the old worker reporting success after I/O does not establish successful server acknowledgement. Reusing its login-only worker identity across schools would cause collisions and should not be reproduced.

## Logout, background work and logging

Logout cancels or invalidates in-flight work, increments generation, clears matching secrets and module cookies, and prevents old completions from publishing. Decide explicitly whether encrypted cached diary data remains available offline; do not delete another child's or provider's snapshot through global clear calls.

Diagnostics may retain operation ID, provider/version, redacted authority, status, decode path, duration and a random correlation ID. Exclude raw passwords, reusable MD5 digests, JWTs, refresh tokens, SSO path tokens, Cookie/Set-Cookie, message content and schoolchild identities. Record a missing JSON field path without logging the full response. Redaction must apply to failures and request inspectors as well as successful logs.
