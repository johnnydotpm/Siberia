# Authentication, origins, serialization and lifecycle

## Origin and token matrix

The following are compiled8.4.1 configuration facts, not independently checked current service availability. Exact byte offsets and bundle hashes are in [artifacts.json](artifacts.json). API configuration is assembled in `src/store/modules/user-config/librus/user-account-librus_actions.js`, login action around lines265–274 and restored-context action around611–620. The named fields and their values must stay separate:

| Service | Recovered base | Credential owner | Request codec |
|---|---|---|---|
| Portal browser | `https://portal.librus.pl` | Interactive Librus account/browser session | Browser navigation, not JSON API login |
| Portal OAuth | `https://portal.librus.pl/oauth2` | Librus/Portal owner | Multipart FormData token exchange |
| Portal API | `https://portal.librus.pl/api/v3` | Portal access token | Axios object/FormData, operation-specific |
| Synergia academic API | `https://api.librus.pl/3.0` | Selected linked Synergia account access token | Synergia helper JSON-stringifies truthy data except file requests |
| Synergia gateway | `https://synergia.librus.pl/gateway/ms` | Linked Synergia token | Helper and caller-specific; not the HTML mailbox |
| Personal schedule | `https://personalschedule.librus.pl` | Portal token | Portal helper; custom timetable/reminder operation dependent |
| Librus GO | `https://librusgo.pl/api` | GO context token | GO helper leaves object data to Axios |
| Browser GO | `https://librusgo.pl` | Browser/autologin context | Web redirects, not automatically the GO API token |

The common `getAxiosFromConfig` (`src/store/modules/helpers/axios-helper.js:13`) sets `Authorization: Bearer <accessToken>`, `Accept: application/json`, and timeout60000ms. It does not set a universal Content-Type. A token selected for the wrong Axios instance remains a credential isolation bug even if two services share a host. Do not attach every credential to a globally shared Dio instance.

The operation inventory's `family` groups source files. It is **not** an unconditional origin or codec. For example, student-photo removal imports `_patch` from the GO helper but calls it with a Synergia Axios instance. Resolve each request's `helper_import`, then the caller's instance. A leading slash in an Axios route does not mean discarding the configured `/3.0` prefix; a Dart implementation should use an explicit tested base-plus-route join instead of blindly applying RFC `Uri.resolve` to these route strings.

## Portal browser authorization

Source: `src/store/modules/user-config/librus/auth/librus-account-auth.js`, `src/helpers/oauth-helper.js`, `src/helpers/inappbrowser-helper.js`, `src/helpers/safariwebcontroller-helper.js`.

1. Build `/konto-librus/redirect/dru` on Portal. Huawei chooses `druh`; ordinary Android/iOS choose `dru`.
2. Preflight that URL and Synergia `/3.0/Me` with15s timeout. The original preflight allows most HTTP errors but rejects503, HTTP500 containing `Web Page Blocked!`, and transport failures. This is reachability handling, not authentication success.
3. Navigate to `...?action=login`, or `action=register` for the signup flow. iOS uses SafariViewController; Android uses InAppBrowser.
4. Receive the registered callback, configured redirect URI `app://librus`. The callback helper expects code-related `app`, `librus`, `code` text and uses a regex to collect query values.
5. Exchange the authorization code as multipart FormData at OAuth `/access_token`:

```text
grant_type = authorization_code
client_id = <registered-client-id>
redirect_uri = app://librus
code = <received-one-time-code>
```

Use a multipart library-generated boundary. The original does not send this as JSON, a password grant, or URL-encoded form. The registered client identifier is a configuration value, not a user's password; confirm legitimate third-party client registration and accepted redirects rather than assuming an unrelated client ID is compatible. For local reproduction, the packaged compiled environment's `clientId` field and the above source method are the precise retrieval points. No user credential needs to be published.

Observed callback behavior is weaker than a robust future implementation: `isCorrectUrl` checks substrings in the first40characters, and `getUrlParameters` does not percent-decode. `oAuth2Validator` returns code, treats command as cancellation, otherwise fails with error. Do not document OAuth state/nonce verification or PKCE for this Portal flow as present when the inspected code does not show it. A future app should validate the parsed callback scheme/host/path and bind it to one pending login; any improved state/PKCE behavior must match the server's registered contract and be labeled a new design policy.

## Portal session refresh and linked account discovery

`user-account-librus_actions.js:createLibrusAxiosInstance` and `createGatewayAxiosInstance` build separate instances using the Portal access token and attach an auth-refresh interceptor. `refreshLibrusInstance` uses one shared `librusRefresh` promise and POSTs multipart fields:

```text
grant_type = refresh_token
client_id = <registered-client-id>
refresh_token = <Portal-refresh-token>
```

Success replaces token data, rebuilds Portal/personal-schedule instances, updates the failed request Authorization and saves the store. The in-flight variable is cleared after completion/failure. Failure dispatches logout in the original client. This is observed application behavior, not a recommendation to erase offline data on every transient refresh failure.

Portal `/Me` identifies the Portal owner. `/SynergiaAccounts` discovers linked accounts; `/SynergiaAccounts/{username}` retrieves one and `/SynergiaAccounts/fresh/{username}` refreshes the linked credential/context. They return Portal response data directly rather than Synergia's `data.Me` envelope. **The fresh GET is credential-state-changing despite its method.** Do not classify every GET as a harmless retry.

The selected linked account's `accessToken` builds Synergia academic and gateway clients. `refreshSynergiaInstance` deduplicates by linked login in `refreshPromises`. It asks Portal for a fresh account, updates account/token state and recreates the two linked-account instances.503/424 become `broken-technicalBreak`;410 falls back to account discovery and removes stale `pushId`. Other failures propagate. `validateSynergiaAccount` then requests academic `/Me`, reads `Me.Account.Login` and stores `Me.Account`, including entitlement fields such as `IsPremium`, `IsPremiumDemo`, `PremiumAddons`.

A Portal owner can contain several Synergia accounts and GO contexts. Do not overwrite all linked tokens when switching the visible pupil. Account IDs, pupil IDs, selected academic period and service tokens are distinct. Current Siberia already has shared-login and profile storage primitives; see its updated runbook rather than adding another global auth singleton.

## Librus GO exchange and context selection

Source: `.../librus/auth/librus-go-account-auth.js` and `.../librusGo/user-account-librus-go_actions.js`.

The original builds a verifier with `Math.random().toString(36).substr(2)` and computes CryptoJS SHA256. It GETs the Portal instance's relative `access-token/dru/librus-go?&code_challenge=<digest>`, then GETs `response.data.url` with that same instance. The result supplies `loginToken`. It POSTs GO `/auth/contexts/access-tokens` with object `{loginToken,codeVerifier}`. The token response is an array of contexts, not one generic access token. The constructed Axios instance sets a Bearer from `config.accessToken`; the inspected sync caller supplies no such property, so do **not** silently describe the exchange as definitely carrying the Portal token in that header. The challenge representation follows CryptoJS string conversion; do not substitute OAuth S256/base64url without a verified server change.

The source checks application permissions and terms acceptance, completes each returned identity, and distinguishes missing contexts, candidate state, technical break and permission/terms refusal. Context tokens belong to the GO account/context. A recovered official-store eligibility gate is not evidence that a third-party app has permission to bypass that gate.

For new implementation security, generate verifiers with cryptographically secure randomness if the same wire representation is accepted. That would deliberately improve source behavior. Do not reuse the official client's `Math.random` pattern by treating it as a general OAuth recommendation.

## Three helper codecs

### Alternate packaged auth surfaces

The JST branch is not ordinary Portal login. `src/store/modules/user-config/jst/user-account-jst_actions.js:59` constructs `synergiaOauth = https://api.librus.pl/OAuth/TokenJST`. `jst/auth/jst-account-auth.js:16` sends multipart fields `grant_type=implicit_grant`, configured `client_id`, configured `secret`, entered `code`, entered `pin`, `librus_rules_accepted=true`, `librus_mobile_rules_accepted=true`, `librus_long_term_token=1`. Its success consumer retains `access_token`, `refresh_token`, `expires_in`, `account_group` and validates `/Me`. The packaged client configuration is not reproduced as a secret here. Record this branch as a separately gated enrollment capability; its presence does not prove the ordinary mobile build's current navigation enables it or that a third-party registration can use it.

The browser-widget variant creates Portal/personal-schedule Axios clients with `withCredentials:true`, instead of the ordinary Bearer configuration. `widget/auth/personal-schedule-auth.js` GETs OAuth `/authorize` with `client_id`, `redirect_uri`, `response_type=code`,30s timeout and credentials; it can resolve HTTP error responses as part of its callback flow. `widget/user-account-widget.js:refreshGatewayInstance` reads the returned `x-oauth-token` header. Do not replace native widget background sync with this browser-session mechanism merely because both contain the word widget.

Development auth overrides and Huawei/store differences are separately recorded in the platform/feature inventory. Do not ship debug behavior or reuse embedded test/provider secrets in a new implementation. Some original guard expressions around token responses dereference data in an apparently inconsistent `!response.data && response.data.access_token` check. Treat that as source behavior requiring a valid-body decoder, not a schema or an error-handling pattern to copy.

Direct image download is another excluded catalogue boundary: `librus-rest.js:getAvatarImageData` calls global Axios GET on the supplied URL with `responseType:arraybuffer`, then constructs a Blob using response Content-Type and an object URL. Despite its unused `axiosInstance` parameter, it does not automatically use that instance's Authorization. Preserve this distinction and clean up object URLs in a new UI.

`src/api/synergia-rest-core.js` clones config and JSON-stringifies truthy `data` unless `sendFile` is set. `_get` passes method unchanged/default; `_post`, `_put`, `_delete` set the respective method. `src/api/librus-api/librus-rest-core.js` and `src/api/librus-go-api/librus-go-rest-core.js` instead pass object data to Axios unchanged; GO additionally exposes `_patch`.

Keep omitted body, JSON null, empty object, object-to-JSON conversion, raw string and multipart separate. In particular, stringifying an already-stringified payload twice breaks messages. A list response can be `response.data.Messages`, singular `Message`, `data.data`, `data.data[0]`, or a direct value. The operation's response-property reads record the inspected consumer; there is no universal `success/data` envelope for Librus.

The Synergia helper itself does not explicitly force `Content-Type: application/json`; it passes a JSON string to Axios. Exact final wire headers depend on the bundled Axios transform and the chosen adapter. This remains a serialization verification gate rather than an invented header claim. Future fixtures must assert actual emitted bytes and headers for each service. Multipart endpoints explicitly mark `sendFile:true` to avoid JSON-stringifying FormData.

## Expiry, logout, switching and errors

The supplied app relies on request/interceptor recovery in the paths above; a static helper's existence does not establish a universal token lifetime. Siberia's current source has its own hardcoded lifetime assumptions. Keep returned expiry metadata when provided and verify it rather than using one lifetime for Portal, Synergia and GO.

Removing a linked account unregisters change notifications when possible, clears that account's stores, updates active selection and persists. These local lifecycle actions do not prove revocation of every remote session. Version/terms/subscription/broken-account states should retain meaningful offline content and distinguish an unavailable module from a successful empty list.

For a new adapter, bind every request to an immutable auth owner/service, linked account and selection generation. Serialize credential rotation per owner, suppress stale UI publication after account switch, and prevent late refresh completion from repopulating a removed login. Retry safe reads after recovery at most within a bounded policy. A message send, meal cancellation, photo request, change acknowledgement, subscription action or browser payment must not be blindly replayed after an uncertain timeout.

Keep API errors, schema failures, role refusal, technical breaks and connection failures separate. The original sometimes catches errors and substitutes an empty collection. Document that behavior, but do not adopt it as proof that no grades, invoices or meals exist. Redact credentials, callback codes, loginToken, tokens, cookies, signed attachment links and pupil/message data from diagnostics.
