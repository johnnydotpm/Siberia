# Modern MobiReg3.1.7: recovered authentication and gateway contracts

These are code-derived contracts from the supplied **Android3.1.7 build116 revision6f4e7b8**, `libapp.so` SHA-256 `22dd67993cd25ccb0a56fca7eef87ffc1d40cc1bffd9057b671c7268afc4d97a`. They supersede earlier string-only uncertainty for the specific functions below. They are not live backend observations, and equal iOS version numbers do not automatically establish identical implementation.

The inputs are Blutter's named ARM64 assembly/object-pool reconstruction, cross-checked against independently parsed r2flutter function entries and original ELF instruction words. All PCs below are image virtual addresses. The local raw assembly is evidence, not source to copy. Compiler aliases, Smi tagging and indirect dispatch require care; constants described below were followed through the actual map stores and calls.

## Password login: JSON, original password text

`AuthService.login` entry `0x7953f8` calls `AppConfig.cleanAddress` (`0x794d50`) for page address, trims school code and login, resolves an existing account, and selects a credential:

- A supplied password is used when `password.trim().isNotEmpty`, but the original supplied string is retained, including leading/trailing spaces. The trim is an emptiness check, not the value sent.
- Otherwise it reads `AccountsStore.password(account.id)`.
- If no password is available, it reads the account refresh token and calls `_refreshWithToken` when nonempty. No password and no refresh returns false.

The settings screen reads password controller text at `0x794fc0..0x795030`, uses a saved password for the blank edit case, and passes it through `AppState.performLogin` (`0x795274`, call `0x795340`) to the named `password` argument. `AuthService` inserts that same string into JSON (`0x7959a4..0x7959c4`). This confirms **modern password login sends the selected text without the legacy MD5 transform**. `AccountsStore.setPassword` (`0x4a4c34`) writes it unchanged through FlutterSecureStorage at key `acc.<accountId>.password`; the return path reads that account-owned value. Do not double-hash it or apply the legacy adapter globally.

The auth URL is HTTPS authority plus `/<school>/modules/api/auth.php`. The URI constructor is called at `0x7958ec` with normalized address and the interpolated school path. The login builder is:

```text
POST https://<clean-address>/<trimmed-school>/modules/api/auth.php
Content-Type: application/json; charset=UTF-8
Accept: application/json

{"login": "<trimmed-login>", "password": "<selected-original-password>"}
```

The JSON map is created at `0x795988..0x7959bc`, encoded at `0x7959c4`, and passed to `http.post` at `0x7959e0`. No bearer/cookie or legacy device/app compatibility fields are added by this function. HTTP200 is required (`0x795a04`); decoded `status` must equal exact string `OK` (`0x795a24..0x795a6c`), and `token` must be present/non-null (`0x795a7c..0x795aa8`). A String type test precedes storage. Success stores JWT and selected password per account; `makeCurrent` controls current-account selection. The password-login path does not independently read/store a `refresh` response field. Non-200, non-OK, malformed/exception paths return false after logging; `message` is used for API error diagnostics.

`login` resolves supplied account ID or falls back to current account, then looks up school/login (`bySchoolAndLogin` at `0x79577c`). This is account selection behavior, not a pupil credential. Siberia should keep page authority in its identity as well, even if the source match omits it, to avoid cross-school collision.

## QR-code exchange and refresh

`AuthService.qrLogin` entry `0x793ee0` normalizes address, trims school and code, validates nonempty values, and constructs:

```text
POST https://<clean-address>/<trimmed-school>/modules/api/qrlogin.php
Content-Type: application/json; charset=UTF-8
Accept: application/json

{"code": "<trimmed-code>"}
```

The map literal is `0x794048..0x794068`, JSON encode `0x794070`, POST `0x794084`. The response requires HTTP200, `status == "OK"` and token data; `user.login` is extracted and trimmed to find the existing school/login account (`0x794140..0x7941f8`). The complete scanner QR payload format is upstream of this builder and is still a separate validation item; this endpoint receives the code string, not an assumed whole QR URL.

When QR login matches an existing account with a saved password, the branch at `0x794218..0x794388` preserves the password and updates its JWT, address if needed and current account. The source log explicitly says password was not changed. Otherwise it creates/updates an authType=`qr` account, stores `token`, stores `refresh` if supplied, clears the password (`0x794660`) and sets current account. This is why access/refresh credentials belong to the account rather than each child.

`AuthService._refreshWithToken` entry `0x795e48` constructs its URL from `account.address` and `account.schoolCode`:

```text
POST https://<account-address>/<account-school>/modules/api/refresh.php
Content-Type: application/json; charset=UTF-8
Accept: application/json

{"refresh": "<account-refresh-token>"}
```

Map `0x795f58..0x795f74`, encode `0x795f7c`, POST `0x795f90`. Success requires HTTP200 and `status == "OK"`, followed by a non-null token. It stores the new JWT (`0x7960bc`) and stores a replacement `refresh` if the response contains it (`0x7960d0..0x796160`). Missing replacement refresh does not itself prove revocation or deletion of the old token. `makeCurrent` controls current-account selection. Errors return false. Token expiry duration, JWT validation claims, server revocation semantics and refresh replay/rotation policy remain unobserved.

## Gateway requestView: form body with two JWT aliases

`AppApi.requestView` entry `0x48ead4` obtains its endpoint via `AppConfig.getAppEndPoint(accountId)` and JWT via `AuthService.getToken(accountId)`. `getToken` (`0x48f9ec`) selects the explicit or current account ID and reads `AccountsStore.jwt`; it does not validate expiry or automatically refresh.

`AppConfig.getAppEndPoint` (`0x48fb00`) builds `https://<page-address>/<school-code>/modules/api/app.php`; `cleanAddress` removes an initial `http://` or `https://` pattern and one trailing slash. `requestView` requires an endpoint and token. Its optional arguments are `accountId`, `extraParams`, `pupilId`, and `requirePupil` (default true).

The actual request is a Dart `Map<String,String>` body passed directly to `http.post`, which yields a URL-encoded form through the HTTP library. It is **not JSON**:

```text
POST https://<page-address>/<school>/modules/api/app.php
User-Agent: MobiReg/3.1.7 (6f4e7b8)

view=<operation>
format=json
token=<account-JWT>
JWTToken=<account-JWT>
pupilId=<nonzero-pupil-ID-as-string>    # only if non-null/nonzero
...extraParams
```

Map stores are at `0x48ed08..0x48ed50`; the same JWT register is stored under both `token` and `JWTToken`. `pupilId` is converted to text before insertion (`0x48ed60..0x48edb8`). `extraParams.addAll` is **after** those defaults (`0x48edcc`), so duplicate extra keys override them. No Authorization bearer header is added here. Header map construction `0x48edf4..0x48ee38` contains User-Agent only. POST call `0x48ee4c` is followed by a15-second timeout (`Duration@995a11`, stored microseconds15,000,000).

`requirePupil=true` rejects missing/zero pupil context before issuing a request; account-level calls explicitly disable it. Retain the distinction between credential owner(account) and data subject(pupil). Do not fabricate `pupil_id` for this form: the recovered field is camel-case `pupilId`.

### FCM token collision is intentional in the builder

`registerFcmToken` (`0x793b00`) calls `requestView("register-fcm", requirePupil:false, accountId:..., extraParams:...)`. It puts the **FCM token** under `extraParams["token"]` (`0x793bb0..0x793bb8`) and optional `keepLogins` as a comma-joined string (`0x793bc8..0x793bec`). `unregisterFcmToken` (`0x78de30`) likewise supplies FCM token and `requirePupil:false` to view=`unregister-fcm`.

Because extras are merged last, these commands' final form has `token=<FCM-token>` while **`JWTToken=<account-JWT>` remains for authentication**. Rebuilding the form by forcing token and JWTToken equal after merge would break the recovered protocol. Token registration compatibility with Siberia's own Firebase project still needs server verification; the client contract alone does not establish it.

### Status/error behavior

Gateway success requires HTTP200 and a nonblank body, then `ApiEnvelope.parse`. HTTP401 parses an optional `message`, invokes the installed unauthorized callback once using an internal flag (`0x48f100..0x48f188`), and subsequently throws an HTTP error. `resetUnauthorized` (`0x49ff70`) clears that flag. This function does **not** retry the operation or refresh the token. A higher-level coordinator may do separate recovery; do not invent an automatic retry of mutations.

Missing endpoint/token, required pupil missing, empty body, other non-200 status and malformed envelope become typed bad-response errors; exception classification distinguishes offline/transport errors. Keep previous valid cache on these failures. A401 must not become an empty successful data array.

## ApiEnvelope v1 and REST fallback

`ApiEnvelope.parse` (`0x48f364`) requires a decoded string-keyed map with non-null `v` and a `data` key. Integer or string-convertible `v` is parsed; the supported value is **1**. The comparison at `0x48f540` uses tagged Smi raw2, which represents Dart integer1. A different version throws `AppUpdateRequiredException`. Do not mistake raw2 for protocol2.

Recovered shape:

```json
{
  "v": 1,
  "serverTime": "<DateTime.tryParse-compatible timestamp>",
  "ttlFresh": 60,
  "ttlRetain": 1209600,
  "data": "<module-specific payload>"
}
```

The TTL fields are numeric seconds, converted to integer seconds then multiplied by1,000,000 for Duration. Defaults are60 seconds and1,209,600 seconds(14 days), respectively (`0x48f708`, `0x48f7d8`). `serverTime` is parsed with `DateTime.tryParse`; the current constructor path does not retain its result in the envelope object's fields, so do not assume it drives the cache clock without tracing cache code. If `data` is a map containing `errno`, the parser throws an API error using its `errno` and optional `message` even if envelope v is correct. A list or other module payload remains raw data.

`parseOrFallback` (`0x76dda8`) is deliberately broader for REST: if the decoded root has envelope `v`/`data`, it uses strict parse; otherwise it wraps the decoded payload with protocol0 and default freshness/retention. This fallback is **not used by gateway requestView**, which calls strict parse directly. Do not globally accept an envelope-less response on the gateway.

## Separate REST transport uses Bearer auth

`AppApi.restGet` (`0x76da44`) and `restMutate` (`0x76bcc4`) build their base through `_apiBase` (`0x76c418`): `https://<page-address>/<school>/api`. A caller path is appended. These use current-account token/config; unlike requestView's explicit accountId option, these helpers do not expose that scope parameter in the recovered signatures. A new adapter should pass an explicit immutable account context rather than rely on a mutable global current account.

REST headers are `Authorization: Bearer <JWT>`, `Content-Type: application/json`, and the build User-Agent. GET (`0x76dc60`) requires200 and returns `ApiEnvelope.parseOrFallback`. Mutation supports exact strings POST/PUT/DELETE and dispatches at `0x76bf74`, `0x76bfbc`, `0x76c000`. POST/PUT JSON-encode a non-null body; DELETE sends no body in this helper. Mutation accepts2xx, returns null for an empty trimmed body, otherwise returns JSON-decoded data directly. All use the15-second timeout. Unknown verbs throw an argument error. This transport must not be confused with cookie-authenticated MailApi/HomeworksApi or form-authenticated gateway.

## Bounded remaining gaps

- Auth response token/refresh expiry, server revocation policy and actual account role fields require authorized runtime fixtures. No server was contacted.
- Upstream QR scanner payload grammar still needs full caller tracing; the exchange builder receives a trimmed code string.
- Full module-specific `view` schemas and every feature model remain separate tasks; this report establishes the shared transport and auth contracts.
- iOS3.1.7 source revision differs. Shared strings support candidate parity but these specific PC contracts are Android evidence until the iOS call path is compared.
- Library/compiler display names can misattribute closures; all critical contracts here are tied to named outer builder PCs, their map stores and HTTP call instructions. The raw-byte validator verifies instruction/entry locations, not runtime backend behavior.
