# mobiDziennik authentication, bootstrap and transport specification

Scope: static client behavior from supplied12.13/code121300 Android split-package application. References such as `MD-F21` resolve through [evidence.json](evidence.json) to original APK member SHA256, literal anchor and line numbers. The [operation ledger](operations.json) is the precise machine-readable request index. No live service acceptance is claimed.

## Origins and encodings

| Family | Origin source | Request | Credentials / response |
|---|---|---|---|
| Email login and unlock | Packaged `https://mobidziennik.pl/logowanieapp` | POST jQuery form data | Email + raw `haslo`; direct user-like object or `error` |
| Password reset | Packaged `https://logowanie.mobidziennik.pl/logowaniesso/niepamietamhasla?app` | POST form data | `przypomnij_haslo_email`, `json`; `status`, `komunikat` |
| School sync / generic controller | Login/linked-context `sync_url` | POST form data with JSON strings | `login,email,haslo_hash,ciasteczko_autoryzacji`, optional raw `haslo` |
| Device authorization poll | Waiting account's `sync_url` | POST form data | Raw password + authorization key; truthiness check |
| Notification disable | Packaged central login URL | Direct POST form data | Global ID, device push token and backend hash |
| Generic blob transport | Explicit override or school `sync_url` | POST multipart outer fields | Same form-envelope credentials; `responseType=blob` |
| Static shell pages | App-local `pathname + '.html'` | Local GET | No school-account request |

`core.exec(functionName,params,nodebug,url,xhr)` uses the caller override when provided and central login otherwise. **`functionName` is not serialized as an `akcja`/`action` field.** It is used in logs and in the login-injection condition. A commented URL expression mentioning `?akcja=` is not active request construction. Adding `akcja=sync` merely from the local function label would invent a wire field. See `MD-F01..MD-F06`.

Normal requests pass an object as jQuery3.4.1 AJAX `data`, POST, `dataType:'json'`, `crossDomain:true`. With the packaged library defaults this is form encoding, not a JSON document. Nested payloads such as `device`, `lekcje`, `formularze` are JSON strings **inside** that form. Let a real form encoder escape `+`, `&`, `=`, Unicode and JSON punctuation; do not manually concatenate them. The shown callers set no Bearer header or explicit Cookie header. `ciasteczko_autoryzacji` is a **form field name**, despite meaning “authorization cookie.” No universal timeout is set in these visible calls; a future adapter should add a bounded policy and distinguish it from observed wire facts.

When `params.login` is falsy, `functionName !== 'logowanie'`, and `app.user` exists, the helper injects the current school login. When `params.device` is falsy, it copies Cordova's device object; outside Cordova it may use `{platform:'App browser'}`. It adds current `pushRegistrationId`, or an APNs fallback `apnsToken`, and Cordova `appVersion` from BuildInfo when available. It then JSON-stringifies that device object. A supplied truthy `device` bypasses this construction. The original comment says the browser marker is checked on the backend; acceptance of a third-party device/app identity is a runtime gate, not permission to impersonate the original client.

The blob variant creates XMLHttpRequest, POST, `responseType:'blob'`, then appends each outer field to FormData. It resolves status200–206 inclusive and rejects other load statuses. It has no recovered `onerror`, `ontimeout` or `onabort` completion handler. Do not copy that potential hanging-promise behavior. The helper does not establish a file part name or actual attachment upload workflow. Ordinary `post` inside a queued form is application payload, not an automatic multipart binary part.

## Login, credential material and identity

The UI requires an activated email address. It tells users without one to configure it through their school's ordinary website; this shell is not an arbitrary school-login/password form. The form reads untrimmed email/password and checks only nonempty `.length` in the shown function.

`MD-AUTH-LOGIN` sends:

```json
{"api2":true,"email":"synthetic@example.invalid","haslo":" synthetic raw password ","hash":true}
```

This map becomes form fields; it is not the HTTP JSON body. `hash:true` is a request flag. There is **no client MD5/SHA transform** in the inspected producer chain. Original login initially sets `password_hash=''` and retains the entered raw password; subsequent school responses supply/rotate `password_hash`. Treat that value as an opaque reusable credential, not as proof of an algorithm or a substitute for hashing entered input. Do not double-hash it or reuse MobiReg's legacy policy.

Successful central login returns a user-like object directly, not necessarily `{user:...}` and not a generic `data` envelope. The caller reads `data.error` on failure; otherwise it sets local password fields, preserves an already stored `auth_key/auth_check` where available, persists the user and starts school sync. Later full sync uses `{user,templates,error?}`. These are separate response shapes.

Keep at least three identities:

* global account owner: legitimate service/server plus email/global identifier;
* school/linked context: school `login` and legitimate `sync_url`;
* selected school year/data context: `school_year`, role and eventual pupil/academic module IDs once decoded.

Original storage keys users by `login` alone, shares credentials/auth state by `id_global`, and queries authorization key by email. Siberia should improve these namespaces rather than repeat potential collisions across providers/schools/years. A returned `id_global` is not a pupil ID. A school login is not globally unique. Preserve device/auth secrets under the owner, academic cache under selected context.

Known role codes are director1,teacher2,parent3,student4,outside_user5. This is a client role map, not a guarantee that every role can perform every generic form operation. Teacher lesson editing has additional unsent-state guards and should remain outside parent/student capabilities unless independently recovered and requested.

## School sync and current-page selection

`MD-SYNC` posts to the selected user's returned `sync_url`:

```text
login                    selected school login
email                    global account email
haslo_hash               opaque user.password_hash
ciasteczko_autoryzacji    user.auth_key
lekcje                   JSON.stringify(user.data)
formularze               JSON.stringify(user.forms)
page                     current template key
haslo                    raw password only when retained password.length > 0
device                   JSON string constructed by core.exec
```

The helper first reads any stored auth key for the email. It does not retrieve a JWT, calculate a server delta cursor or append a child ID. `sync_time` is a locally generated timestamp, not a recovered backend cursor. The request can update credentials/device state even with empty lesson/form maps, so a “pull” is not proof of zero server side effects.

Page grammar matters. Routes may have `?` parameters and a `!` detail suffix. Without a `js` parameter, the template key includes query and excludes the `!` suffix: `oceny?semestr=1!id=5` requests/cache-looks-up `oceny?semestr=1`. With `js` present, key is pathname: `wiadomosci?typ=odebrane&id=5&js` uses `wiadomosci`. Empty key selects the default: director→`wiadomosci`, others→`glowna`. This `page` value is not an arbitrary REST resource and should not be rewritten into a guessed endpoint.

The original route parser splits strings at `?`, `!`, `&`, `=` without percent-decoding and can discard extra `=` characters. A new typed router can improve escaping, but must preserve template-key semantics in compatibility fixtures. URL equality protects some page completions; it does not provide account-generation isolation.

Successful full response replaces current `app.user` with `data.user`, resets queued `data/forms` to empty, stamps local sync time, and calls `storage.update(data)`. `data.templates` is a name→string map. It contains required `js`, `nav`, `css` plus school-specific page templates. The shell then reloads those bootstrap pieces. A missing required piece can trigger logout in the original app; a future integration should preserve useful stale data and report an incomplete bootstrap instead of silently treating it as no diary data.

## Outbox push, pull and failure ordering

When pending lesson data or forms are nonempty, `MD-SYNC-OUTBOX` first sends the same sync envelope with `push:true`. After its promise resolves, original code clears request and in-memory queues, optionally refreshes `password_hash` when `data.user.password_hash_refresh`, saves local metadata, then sends a second pull request.

This ordering has important limitations (`MD-F20..MD-F28`, `MD-F43..MD-F48`):

* HTTP-success JSON reaches the first callback before the later common `data.error` handler. Queue memory can be cleared before business success was validated.
* The code dereferences `data.user` in this phase and fires `storage.update({user:app.user})` without awaiting a durable queue-specific acknowledgement.
* `storage.update` replaces the user row with empty queue objects. Network acknowledgement, memory clear and later template pull are not one SQLite transaction.
* The push failure handler can show a retry message without rethrowing, leaving later code to consume undefined response data.
* Concurrent `app.sync` calls return an already-resolved promise rather than joining the active result. A caller can report completion without its intended work finishing.

A future independent implementation should have an owner-scoped in-flight sync future and a durable outbox with stable operation IDs. Validate a concrete controller's business acknowledgement, persist that acknowledgement atomically with queue state, then refresh read data. A push timeout is uncertain, not proof of no mutation. No idempotency key or safe universal replay guarantee was recovered. Do not replay justification, message, lesson or homework writes solely because the wrapper advertises “retry.”

## Generic form tunnel

`app.push(name,kontroler,get,post,retry,func,xhr,url)` creates:

```json
{"FORM_NAME":[{"name":"FORM_NAME","kontroler":"CONTROLLER","get":{},"post":{}}]}
```

It puts that JSON string in `formularze`, adds `push:true` and the normal account credentials, then calls `core.exec`. Default local `func` is `sync`; it does not become a wire action. Explicit `url` overrides the school endpoint. Raw returned data is resolved without a business-error check in `app.push` itself. On transport failure with `retry` enabled, it appends the form into `user.forms[name]` and saves the queue before rejecting.

`name`, `kontroler`, `get`, `post` are opaque controller arguments. A `post` property is not proof of an HTTP POST endpoint separate from this tunnel, nor does `get` guarantee a pure read. The real form names, controller IDs and field maps for grades, e‑usprawiedliwienia, compose/send, homework answers and files are defined by downloaded server templates. They are absent from the supplied first-party bootstrap scripts. Keep concrete actions unavailable until that exact caller and response handler are captured and traced.

## Business errors and device approval

The JSON transport helper distinguishes connectivity/status/parse/timeout/abort errors, but ordinary business errors are inspected by each caller. Preserve `error.type`, `error.message`, `error.logout`, `error.unauthorized`; do not equate HTTP200 with success. `core.connectionError` maps status0,404,500, parsererror,timeout,abort and unknown errors, retaining response text in the original debug object. Do not log raw response bodies or secrets in Siberia.

During sync, a returned `user.auth_key` can be saved even in the error branch. `error.unauthorized` moves the current identity into `userDAuth`, clears active user and opens device authorization. The waiting page POSTs `login,email,haslo,ciasteczko_autoryzacji,sprawdz_autoryzacje:true` to that context's `sync_url`, every3seconds while active. The original merely checks response truthiness; it does not validate a strict success schema. A truthy error object should not be considered a verified approval in a new client.

The waiting UI says approval instructions are sent by email and approval can also happen from an already trusted device's “Moje konto → Moje urządzenia.” The actual approve/revoke controller is downloaded. A `mojeurzadzenia?id=...&js` notification route proves navigation, not an approval API body.

`error.logout` triggers local logout. A message-only error can show feedback and return false; that is not a valid empty dataset. Unknown/malformed error shapes should remain protocol errors. A later refresh failure must not move one account's device-approval state into another context.

## Local lock and logout

`auth_check==1` activates biometric re-entry after at least5minutes inactive. Fingerprint unavailable/failure/cancel falls back to a password overlay. Password unlock uses central login fields plus `auth:true`; successful response hides the overlay without replacing tokens in that branch. This gate protects local access, separately from backend device authorization.

Logout attempts notification disable when an FCM token is present, then updates all matching-email rows as logged out. `storage.logout` forcibly sets `resetPassword=true`, clearing raw password and password_hash regardless of its argument. It retains auth key and cached templates in the shown routine. Local logout is not proof all backend sessions were revoked. Removing only one profile in Siberia should not accidentally clear a sibling owner's login or another provider's snapshots.

## Push, files and local UX

The shell requests notification permission, gets an FCM token and subscribes to token refresh. A changed token calls the generic sentinel form `name:'-',kontroler:false,get:{},post:''`, allowing normal `device.pushRegistrationId` augmentation. There is no separate proven “register-token” URL. APNs fallback can exchange a token through a response user field. Third-party app/project push delivery remains a deployment/backend gate.

Notification disable is a direct central POST `{powiadomienia_wylacz:id_global,push_klucz:token,hash:backendHash}` without core's device/login injection. The original shows logout notification feedback on AJAX success without a strict response success field. Scope this effect carefully; it can disable notifications for an owner/device.

Tapped notification types route to received mail, grades/final grades, behavior/notes, attendance, tests, homework/current-or-archive, or devices. Non-tap payloads are ignored by this handler. It verifies global owner and school login before switching; retain the same isolation plus a generation check in Siberia. Push paths do not establish academic write contracts.

Packaged file helpers save received blobs through native storage, adding filename suffixes and trying Android cache/Download paths, or iOS Documents. Camera/FileOpener plugins are declared. This establishes native capability only. No concrete uploaded-file part name, MIME whitelist, maximum attachment size or homework/message upload endpoint was recovered. Do not borrow `files`, `file` or `attachedFile` from the other providers.

Theme supports light/dark/system and native status/navigation colors. Text zoom follows system accessibility then buckets60..200%. Manual sync throttles10seconds; resume may refresh after60minutes, but it suppresses refresh when editing a teacher lesson, composing a message, working on justification panel/homework answer, or filling visible inputs. `onOnline` sync code is commented. Keep these local UX rules separate from backend capabilities.

## Statistics and e‑usprawiedliwienia priority

`frekwencja` and `#page-freq-justif.act` occur in active resume protection, so an absence-justification UI exists in the app's server-driven surface. There is no packaged body/status/date-selection implementation to recover. No packaged grade/attendance statistics formula was found in the complete selected bootstrap and asset boundary. Existing CSS status classes, push category names and sample forms do not establish such algorithms.

The next bounded task is to retain a controlled account's sync response and the returned `js`/attendance/grade templates, identify the real controller request builder and decoder, and then document exact formulas/submission fields. Do not reuse Librus `/Justifications`, lesson-number rules, status strings or My Goals arithmetic unless independent mobiDziennik evidence establishes them.
