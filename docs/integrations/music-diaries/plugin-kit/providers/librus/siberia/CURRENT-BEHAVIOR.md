# Existing Librus behavior and integration constraints

All observations here are from `syberia/` at the source baseline recorded in [README](README.md), without running the app or school services. Exact edit anchors and hashes are in [source-anchors.json](source-anchors.json). References to durations and status handling describe this implementation, not a server guarantee.

## Boundaries already present

`lib/src/data/librus/librus_client.dart` is a single client combining Portal authorization, Synergia API2.0, Synergia website cookies, XML mailbox cookies, HTML fallback parsing and normalized DTO mapping. `AppRepository` handles local-first persistence and merges selected cached data. `AppController` drives UI and async result guards. `domain/models.dart` contains cross-screen normalized types. A future official-app transport should be separable from those UI models; replacing the entire client would risk existing working fallbacks.

| Service | Existing source behavior | Boundary consequence |
|---|---|---|
| Portal web | GET `/konto-librus/redirect/dru`; POST hidden inputs plus email/password to `/konto-librus/login/action`; CSRF/Referer/X-Requested-With; capture `app://librus?code=...` | Web redirect flow and form metadata, not a plain password token grant |
| Portal OAuth | POST `/oauth2/access_token` with Dio `FormData.fromMap`; authorization-code and refresh grants | Existing wire is multipart, not automatically equivalent to URL-encoded form; confirm independently before changing |
| Portal APIv3 | Bearer GET `SynergiaAccounts` and `SynergiaAccounts/fresh/{encodedLogin}` | Portal token differs from returned Synergia access token |
| Synergia API2.0 | Bearer GET data/reference endpoints; POST `AutoLoginToken` | API credential is selected-linked-account scoped |
| Synergia website | GET `/loguj/token/{encodedToken}/przenies/uczen/widok/centrum_powiadomien`; require `DZIENNIKSID` cookie | Session bootstrap can have effects even though GET |
| XML mailbox | Open `/wiadomosci2`, follow login redirects while retaining cookies, then POST XML to `https://wiadomosci.librus.pl/module/{action}` | Distinct cookie host/path and envelope semantics; never substitute API Bearer |
| HTML mailbox | GET inbox `/wiadomosci/5`, outbox `/wiadomosci/6`, content `/wiadomosci/1/{5 or6}/{id}/f0` | Fragile document selectors; authenticated empty must remain distinct from missing table/error page |

The client ID and user agent exist in source; they are not reproduced here as a recommendation to impersonate a first-party app. Any newly recovered client credentials or application signing material belong in local evidence/private configuration, not public documentation. Server permission and integration policy must be validated separately from static compatibility.

## Authentication, profiles and persistence

Current main already has multi-profile support. `domain/profiles.dart` defines `SchoolProfile(id,account,synergiaLogin,name,school,label,color,slot,notify,studentId,parent,together)`. One secure `LibrusLogin` serves every profile under the same Portal login. The repository creates clients per profile and stores snapshots, selected settings, homework marks and notifications separately. Do not repeat the older plan's assertion that no account/profile separation exists.

`signIn` trims email, keeps the original nonempty password, clears runtime sessions, logs in, computes `LibrusLogin.keyOf(email)` and persists the login with fresh tokens. The login key is FNV-1a of trimmed/lowercased email; a profile ID is a hash of account key and Synergia login. These are deterministic naming helpers, not collision-proof database identities. Parent account metadata is `group == parent` in discovered accounts; a role label does not itself authorize a write.

`LibrusLogins.storageKey = syberia_portal_accounts_v2` stores a secure map of email/password/accessToken/refreshToken per account. The legacy key `syberia_portal_session_v1` is migration input only. `LibrusClient._saveSession` delegates to the login store; `_restoreSession` binds stored credentials to this client's Synergia login. API token and web cookies remain client-runtime state. Do not put selected pupil tokens into the shared Portal credential slot.

`LibrusLogins.renewed` serializes renewals per account inside one store instance and reuses tokens renewed less than1minute ago. `_renewLogin` uses refresh grant, falling back on a web credential login for a `LibrusException`; an empty refresh token returns the existing login. `_refreshPortalAndSynergia` then discovers the profile's account and obtains its fresh API token. It defaults an unspecified choice to student/group or `u` suffix, then first account. Explicit SchoolProfile selection should normally avoid this heuristic after migration.

The API token is considered valid for a hardcoded6hours; cookie sessions45minutes, with30second early margin. These are implementation assumptions, not measured official/server expiry contracts. Client in-flight futures separately coordinate API refresh and the two web sessions. Login-store locks and recently-renewed timestamps are in memory and do not serialize independent background isolates.

`forget` clears one client's sessions/reference lists but leaves the shared Portal login for sibling profiles. Repository `removeProfile` clears its data/settings, and removes the login only when no profile uses it. Logout/removal does not perform remote revocation. `_migrate` moves the old one-profile storage in restartable steps; preserve this migration when extending the account schema.

`domain/together.dart` supplies a merged view: sourced IDs are `profileId|localId`; DTOs carry `source` pointing to the profile and `localId` removes the prefix before provider operations. This provenance must survive every new field/copy/serialization path. Do not send a prefixed aggregate-view ID to a server.

## Data sync and freshness

`fetchSnapshot` concurrently fetches reference lists and chosen data parts. Data parts are Grades, Timetables for a week, HomeWorks, HomeWorkAssignments, Attendances, SchoolNotices, Notes, Grades/Comments and TeacherFreeDays. `HomeWorks` are mapped as exam/event records; `HomeWorkAssignments` are mapped as homework. Do not reverse these from the English names alone.

Some calls are marked optional. `_apiGet(optional:true)` converts every non-success, including a final401 or malformed JSON, and Dio transport failures to `{}`. Downstream parsers commonly turn missing arrays into empty lists. Consequently this source can confuse unavailable/failed optional modules with legitimate empty data. The existing special-case preservation is for messages; extending modules should add per-module outcome and freshness instead of repeating this pattern.

API inbox fetch is one request with `alternativeBody=true&changeNewLine=1&afterId=0&limit=50&page=1`. There is no page loop here. XML inbox/outbox use archive0 without an explicit pagination field. HTML parsers read the currently returned table. These facts prove bounded fetched results only; do not claim complete history or pagination support from this client.

Reference lists are cached for24hours in `librus_references_v1_{accountHash}.json`, keyed by email plus selected Synergia login. Old single-cache data is migrated when its owner matches. The memory cache is also account-keyed. `fetchedAt` is stored UTC and read into local time. A32bit FNV-style hash is an identifier convenience, not a collision-proof security boundary. Unknown references can trigger refresh after10minutes; freshly missing IDs are recorded to avoid a loop. Preserve this optimization and existing per-profile files.

Snapshot persistence uses `SnapshotStore.forProfile(id)`: file `librus_snapshot_v1_{profileId}.json`, preferences fallback `last_librus_snapshot_v1_{profileId}`. The unsuffixed names remain legacy migration inputs. Writes are queued in one store instance and temporary-file renamed. That prevents half-written files, but does not establish cross-isolate revision ordering: foreground and background instances can still race and the last rename wins. Preserve per-profile isolation; add revision policy only where a demonstrated race requires it.

Repository sync preserves cached messages if the new snapshot carries `messagesError` for the same profile; sent mail is loaded independently and kept; already loaded later timetable weeks are kept. Background sync throttles20minutes, walks notifying profiles, selectively fetches notification-enabled parts and checks profile existence again before writing. Errors for an individual profile are left for a later attempt. Do not replace an unrequested part with the empty placeholder that `fetchSnapshot(parts:...)` returns.

## Mail behavior already exposed

Inbox order is API→XML→HTML fallback. Sent mail is XML→HTML fallback and has a controller2minute reload pause. A fallback may produce less data than the earlier source; record which source was used and its completeness. Failure diagnostics intentionally avoid bodies/cookies/tokens.

XML requests have `<service><header/><data>...parameters...</data></service>`, application/xml and cookie auth. The helper requires HTTP200 and an expected response/action structure, detects server error tags/status/type, and handles `eAccessDeny` with one fresh session retry **except SendMessage**. This exclusion prevents automatic duplicate sends and should be retained. Generic retry logic must classify newly added actions individually.

`sendMessage` accepts nonempty recipient IDs, trimmed subject/body, deduplicates IDs, UTF8/Base64 encodes subject/body and `<Actions/>`, then requires status `ok` and a numeric new ID. It supports no compose attachment argument, draft, reply context, trash/delete, archive selector or recipient groups. `fetchMessageRecipients` recursively flattens lists and skips `contactsGroups`. The current recipient type is integer-only.

Message detail comes from `GetMessage(messageId, archive0)` then HTML fallback. The controller treats opening/fetching detail as a server mark-read action and updates local unread state only after success. Bulk mark read loops through detail reads; it is effectful and can partly succeed. Attachments are IDs/names; `GetFileDownloadLink(fileId,msgId,archive0)` returns a validated http/https URI and the UI opens it externally. It does not prove a successful file download or attachment upload.

## Concrete source risks to resolve rather than propagate

1. **Optional module error→empty collapse:** preserve stale data and status;403/unavailable is not zero records.
2. **Profile-ID-only result guards:** controller send/sent/detail operations include `snapshot.profile.id` checks. Switching away and back can admit an older response; the aggregate view uses the shared ID `together`, so a changed included-profile set needs its own revision check. Returned content can still reach a caller after context changed. Retain correct `source` routing while introducing any generation guard.
3. **Removal during shared refresh:** `_logins.renewed` reads an account, awaits network work and writes it back. Removal/clear uses a different queue and does not cancel that pending turn. A late renewal can reinsert a removed login unless guarded. Client `_session` completion similarly needs a generation check. Prove this with a controlled deferred-future fixture; no production incident is claimed.
4. **Cookie model loss:** `_Cookie` stores only name/value/domain/path; it ignores Secure, expiry, SameSite and host-only semantics. Domain/path matching is a simple suffix/prefix. Do not expand its use to arbitrary new module origins; use a tested scoped jar or explicit policy and acceptance fixtures.
5. **Redirect method/body preservation:** `_request` follows up to18redirects, including cross-host http(s), rewriting POST toGET for301/302 and303. Existing context headers and body can survive307/308; provider-scoped redirect policy needs explicit checks before a new sensitive flow uses it.
6. **Fallback IDs/dates:** several parsers use object `hashCode` or `DateTime.now()` on malformed/missing source identity/date. This can create unstable cache IDs and artificial new notifications. Preserve raw values and protocol issues; use a documented deterministic scoped key when a source ID is legitimately absent.
7. **Timetable synthesized identity:** `${day}-${LessonNo or epoch}` can collide for multiple distinct events in one lesson slot. Preserve official event identity where available and handle simultaneous substitutions/groups.
8. **Rich text loss:** `_plainText` strips mail/announcements content; existing models cannot recover HTML structure or inline/attachment relationships later. Keep original sanitized rich representation in an additive DTO.

These are static source observations and inferred failure modes, not reports of reproduced production incidents. Future tests should demonstrate each relevant case before changing behavior.
