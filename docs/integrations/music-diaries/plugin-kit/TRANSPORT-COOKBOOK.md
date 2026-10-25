# Transport cookbook and illustrative snippets

Examples below explain serialization. They are not a working client, a captured transaction or proof that a server accepts the example. Use synthetic values in fixtures; do not paste credentials into shell history. Endpoint details and DTO shapes in the provider specifications take precedence over these abbreviated examples.

## Seven boundaries that must remain distinct

| Family | Origin | Encoding/auth | Response policy |
|---|---|---|---|
| Fryderyk token/version | Recovered bootstrap services | JSON + Accept + App-Version; identify/refresh have different maps | Token/version service behavior; preserve version errors |
| Fryderyk school data | Login response `url` + `/api/` | Bearer access token + JSON headers + App-Version | Decode JSON; `success` boolean selects `data` or structured error;401/426 have special meaning |
| MobiReg legacy | School path + `modules/api/njson.php` or `messages.php` | Form; parent login + lowercase MD5 digest + app compatibility fields | Versioned settings/sync tables and source error codes |
| MobiReg modern gateway | Normalized school origin + `modules/api/app.php` | Form: `view`, `format=json`, `token`, `JWTToken`, optional `pupilId`; extras merged last | Strict non-null `v` + `data` envelope; error branch separate |
| MobiReg modern REST | Normalized origin + school + `/api` | Bearer + JSON + User-Agent | GET200 with envelope/fallback; mutations2xx raw JSON or null |
| MobiReg mailbox | Discovered messaging URL, API normalization strips trailing `/sso` | Its own SSO Cookie; JSON or multipart |401/403 requests SSO recovery; method-specific body/status behavior |
| MobiReg homework | Discovered homework URL | Separate SSO Cookie; JSON or multipart | JSON helper200;401/419 recovery; do not borrow mailbox cookie |

Never install a single global interceptor that attaches all credentials. Prefer an explicit transport family per operation. Keep auth authority bound to the owner; absolute downloaded URLs are not implicit authorization destinations.

## Exact serialization examples

Fryderyk token exchange (JSON, synthetic mobile credentials):

```http
POST /api/tokens/identify HTTP/1.1
Host: swiadectwa.fryderyk.edu.pl
Content-Type: application/json
Accept: application/json
App-Version: <compatible-client-version>

{"username":"example-mobile-id","password":"example-password","device":"Example device"}
```

The next data request goes to the `url` in the successful token response, not necessarily the bootstrap host. `App-Version` is recovered from the original app's version helper. The required value and compatibility policy for a third-party client remain a runtime validation item; do not silently send Siberia's own release number as if it were verified.

Fryderyk refresh serializes `{"u":"example-mobile-id","t":"example-refresh"}`. It does not reuse the password-login map. An absence request includes a JSON null `id` when no supplied ID exists:

```json
{"id":null,"student_id":42,"start":"2026-10-26 08:00:00","end":"2026-10-26 12:00:00","absence_type":3,"absence_reason":"Synthetic example"}
```

This is a mutation example, not an instruction to submit it. Dates are local wall-time strings in the recovered builder; do not append `Z` or convert to UTC without server evidence.

Modern MobiReg password login:

```http
POST /example-school/modules/api/auth.php HTTP/1.1
Host: mobireg.pl
Content-Type: application/json; charset=UTF-8
Accept: application/json

{"login":"example-parent","password":"  example raw password  "}
```

Login is trimmed; a supplied password is trimmed to test emptiness, then the selected original text is sent. The spaces in this illustrative password are intentional. Legacy parent credentials instead send an MD5 digest in form field `parent_pass`; digest exactly once from the selected raw input bytes. MD5 here is a compatibility transform, not an authorization mechanism chosen for a new protocol.

Modern gateway form example, shown before URL encoding:

```text
view = marks
format = json
token = example-jwt
JWTToken = example-jwt
pupilId = 42
termId = 7
```

Use a form encoder. Do not JSON-encode the entire map or manually join values containing `&`, `+`, `=` or Unicode. Integer-like values in the recovered form are serialized strings. An illustrative Dart expression for the body is:

```dart
final body = <String, String>{
  'view': view, 'format': 'json',
  'token': jwt, 'JWTToken': jwt,
  if (pupilId != 0) 'pupilId': '$pupilId',
  ...extraParams, // Actual source ordering matters, especially for FCM.
};
```

For `register-fcm` / `unregister-fcm`, extra `token` is the FCM token and overwrites the initial JWT alias. `JWTToken` remains the JWT. These operations use account context without requiring a pupil. Do not change this ordering to make the map appear tidier.

## URI and date handling

Encode path segments and query parameters separately. SSO's messages token is encoded as a path component; avoid double encoding. A URI builder can escape a literal slash inside a component; string concatenation can turn it into a new path segment. Do not place a raw QR URI or password into diagnostic URLs.

Gateway calendar ranges use `dateFrom`/`dateTo` date-only strings. Fryderyk attendance changes use date-time strings. Legacy MobiReg cursor has a space separator, even when the settings response uses a `T`. Treat these as different serializers. Retain server cursor precision and advance only after durable sync completion.

Main API origin normalization is provider-specific. Preserve the recovered distinction between messaging SSO URL and messaging API URL. Do not strip every occurrence of `sso` from a URL. A school slug belongs to the tenant identity; do not accidentally append it twice.

## Multipart and downloads

Fryderyk attachment upload uses one part named `file`, filename basename, and `application/octet-stream`. Modern MobiReg module uploads use part name `files`; homework also sends `student` as a string form field. The request's multipart boundary must be generated by the multipart library; a hand-set bare Content-Type omits it.

Message creation and attachment transfer are separate operations. Persist the new message ID before uploading files. A failed second upload does not imply message creation failed. Return confirmed message creation plus per-file status; do not replay creation when retrying an attachment.

Mail attachment download uses its mailbox Cookie. The recovered homework download initially uses no such header; on401/403 it refreshes detail and asks for retry. Do not unify these by attaching every available cookie to every URL. Keep temporary downloaded files scoped and track original filename separately from a safe local filename.

## Response decoding must match the family

Decode HTTP bytes with the declared encoding, then validate the expected JSON root and envelope. A successful HTTP code is not a successful business operation. A JSON `data.err`, a poll `success:false`, a malformed body and an expired session are different outcomes.

Modern gateway defaults are `ttlFresh=60` seconds and `ttlRetain=1209600` seconds when the recovered numeric fields are unavailable. These are durations, not milliseconds. Its strict v1 reader accepts the recovered integer/string version representation and requires non-null data. Modern REST GET has a raw/protocol0 fallback; do not use that fallback to silently accept broken gateway envelopes.

For mail,2xx empty body can mean `true`; homework's JSON helper uses200 and empty object behavior. REST mutation empty body becomes null. Preserve these distinctions in fixtures. Provider-specific serializers should be unit tested without contacting any school server.
