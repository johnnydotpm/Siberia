# Synthetic transport and state examples

These examples are independently authored, not captured traffic. Names, IDs, credentials and `.invalid` URLs are fictional. They illustrate recovered outer serialization; controller-specific placeholders are **not** claimed accepted server actions. No school mutation was sent.

## Email login keeps the selected password unchanged

Before form encoding:

```text
POST https://central.example.invalid/logowanieapp
api2 = true
email = parent@example.invalid
haslo = "  example + & password  "
hash = true
device = {"platform":"Android","appVersion":"12.13","pushRegistrationId":"SYNTHETIC_TOKEN"}
```

Here `device` means one JSON **string** form value. Use a form encoder so the literal plus remains plus and ampersand remains inside the password value. Assert the decoded form's password exactly equals the original input, including spaces. The password must not become MD5, SHA, Base64 or a trimmed value. `hash=true` remains a separate flag.

Synthetic direct login response field subset:

```json
{"login":"school-login-42","id_global":"owner-7","email":"parent@example.invalid","sync_url":"https://school.example.invalid/mobile-sync","school_year":"2026/2027","type":3,"main":1}
```

This is deliberately a field subset, not a complete valid response. The original caller adds local raw password and sets password_hash empty, then initiates school sync. Token-like returned fields require secure owner storage. The endpoint path `/mobile-sync` here is invented because a real `sync_url` is discovered, not statically reconstructed from a school name.

## Empty queue bootstrap

Before form encoding:

```text
POST https://school.example.invalid/mobile-sync
login = school-login-42
email = parent@example.invalid
haslo_hash = SYNTHETIC_OPAQUE_SERVER_CREDENTIAL
ciasteczko_autoryzacji = SYNTHETIC_AUTH_KEY
lekcje = {}
formularze = {}
page = oceny?semestr=1
device = {"platform":"Android","appVersion":"12.13"}
```

`lekcje`, `formularze`, `device` are three string form fields containing JSON. They are not recursively flattened form maps and are not a top-level JSON body. Optional `haslo` is omitted when no retained raw password exists. No `akcja=sync`, Bearer header or guessed pupil_id is added by this recovered recipe.

The corresponding success shape is `{user:{...},templates:{...}}`. A metadata-only illustration can use:

```json
{"user":{"login":"school-login-42","password_hash":"SYNTHETIC_ROTATED_CREDENTIAL"},"templates":{"js":"SYNTHETIC_INERT_PLACEHOLDER","css":"SYNTHETIC_INERT_PLACEHOLDER","nav":"SYNTHETIC_INERT_PLACEHOLDER","oceny?semestr=1":"SYNTHETIC_INERT_PLACEHOLDER"}}
```

These placeholder strings are not valid executable school templates and must never be executed. A decoder fixture can use them to check cache indexing and missing-field behavior only.

## Route key cases

| Visible route | Requested/cache template key | Detail parameters retained for page behavior |
|---|---|---|
|`oceny?semestr=1!id=5`|`oceny?semestr=1`|semestr1 and detail id5 |
|`wiadomosci?typ=odebrane&id=5&js`|`wiadomosci`|typ, id and js flag |
|`zachowanie!id=6`|`zachowanie`|detail id6 |
|empty|director→`wiadomosci`, other roles→`glowna`|none |

The original parser does not percent-decode. A future URI parser can improve encoding but should keep these template selection results. Cache keys also need owner/server/year; route equality alone cannot distinguish two pupils with the same page open.

## Generic form envelope, without inventing an academic action

```json
{"SYNTHETIC_FORM":[{"name":"SYNTHETIC_FORM","kontroler":"UNRECOVERED_CONTROLLER","get":{"example":"value"},"post":{"example":"value"}}]}
```

This JSON becomes the `formularze` form value in `MD-FORM`, accompanied by `push=true` and the selected user's credentials. The placeholder controller/body are invalid examples, not a message or justification recipe. It is incorrect to rename that map to `/Justifications` or copy another diary's `absence_type` field merely because mobiDziennik also offers absence justification.

For a real implementation fixture, replace placeholders only after capturing the original selected school template's exact call to `app.push`. Record method, endpoint override, retry flag, local function label, `name/kontroler/get/post`, response handler, role and visible action. A valid outer serializer is necessary but does not prove the inner mutation is correct.

## Device authorization polling

```text
POST <waiting account's discovered sync_url>
login = school-login-42
email = parent@example.invalid
haslo = SYNTHETIC_RAW_PASSWORD
ciasteczko_autoryzacji = SYNTHETIC_AUTH_KEY
sprawdz_autoryzacje = true
device = <JSON string from common helper>
```

Test false response → schedule another poll; true response → restore matching waiting identity and sync; page exit → no continuation; failure → retry/backoff policy; logout/switch → generation invalidates the callback. The original checks any truthy JSON value, so a future strict decoder must not treat `{error:{...}}` as verified device approval merely because it is truthy.

## Notification token change and disable

Changed token uses the existing form tunnel with:

```json
{"-":[{"name":"-","kontroler":false,"get":{},"post":""}]}
```

The FCM token enters `device.pushRegistrationId`. Do not invent a `/register-fcm` route based on another provider.

Disable is a distinct direct central POST:

```text
powiadomienia_wylacz = owner-7
push_klucz = SYNTHETIC_FCM_TOKEN
hash = SYNTHETIC_BACKEND_PUSH_HASH
```

No core helper device/login injection belongs to this direct call. The operation can change an owner's device notification registration; matching credentials and explicit selected owner matter.

## Outbox uncertainty and account switch

Scenario: a queued synthetic form is transmitted, the server processes it, and the connection closes before a response. Required future outcome is **uncertain**, with the original queue item retained and no automatic duplicate write until reconciliation is possible. Do not mirror the original broad promise-success queue clear.

Scenario: ownerA/profile42 starts sync, switches to profile43, then profile42 completes. Store any useful result only under its captured owner/server/year/profile key. It must not replace profile43's screen, credentials or templates. Two requests to the same `page=frekwencja` are still different contexts.

## Local chunking and transaction fixtures

Template chunk size is1,000,000JavaScript UTF16 code units. A supplementary-plane emoji occupies two such units. Source code writes chunks as repeated `(login,name,html)` rows; original retrieval has no explicit ORDER BY. A future capture/decoder should preserve chunk sequence explicitly rather than assume incidental row order. Tests must include an empty template, a split surrogate pair boundary, multiple chunks, failed replacement and cache interruption.

The per-SQL-call transaction does not make push→queue-clear→pull atomic. A future host should persist operation receipt/checkpoint and queue state together, then refresh templates/data separately. No server cursor or idempotency key was recovered to make a stronger guarantee.
