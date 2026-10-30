# Android platform contract and reconstruction guide

Everything marked observed below is a static observation from the supplied8.4.1/code64872 APK and its shipped source maps. Recommendations are explicitly Siberia integration choices. No application or network endpoint was executed.

## 1. Packaging and native boundary

| Item | Static observation | Consequence for a future implementation |
|---|---|---|
| Runtime | Cordova activity loads packaged `www/index.html`; Vue/Vuex app code is JavaScript | Port the documented contracts and behavior; no need to reproduce Cordova or reverse third-party Firebase SDK transport |
| Platform identity | Package `pl.librus.synergiaDru2`; minSDK26, targetSDK36 | These identify this artifact; they do not dictate Siberia's Android minimum |
| Version | Manifest8.4.1/code64872; Cordova widget config separately records build6487 | Keep displayed version, Android versionCode and widget build separate |
| Split declaration | Base archive requires ABI and density splits | Static web/code analysis does not prove this APK installs alone |
| Launch | MainActivity honors background-start flag and invokes `loadUrl(this.launchUrl)` | User-visible diary routing is in the web code, not a Java API service |
| Deep links | Manifest VIEW/BROWSABLE entries for `librus` and `app`; also a whitespace-valued placeholder filter | Registered schemes alone do not authorize arbitrary callbacks or establish a useful host restriction |
| File providers | Non-exported Cordova file and camera providers under package authority | Rebuild temporary-file sharing through Siberia's own Android provider; do not copy vendor authority |
| User agent | Cordova preference appends `LibrusMobileApp` | Distinguish observed client marker from an asserted server requirement |

`android-package.json` lists all parsed components, permissions and plugin versions. Internet/network state, wake lock, notifications, phone-state, billing and vibration are declared. Legacy external-storage permission has maxSDK30. Permission declaration is not evidence a permission was granted, requested at startup, or required by every diary feature.

Config contains a development-domain network-security policy with custom/system/user trust anchors and cleartext allowed for those development hosts. It does not establish that production diary traffic uses cleartext. Siberia should preserve its own production TLS policy and configure approved development trust separately.

## 2. Browsers, redirects and deep links

Shared `src/helpers/oauth-helper.js` selects SafariViewController for iOS and InAppBrowser for other platforms, including Android. Android's InAppBrowser helper opens a dedicated browser window, requests cache/session clearing for OAuth, and observes lifecycle events. Its OAuth form is non-closable in the helper configuration; cancellation still rejects through the exit callback. Keep cancellation distinct from invalid credentials or network failure.

Original helper behavior:

* `loadstart` checks an AutoLogin/login fallback condition; it can close a failed automatic-login browser.
* Portal terms can be opened externally, closing the embedded browser.
* A PDF download event can open the file externally and resolve the handoff.
* Custom scheme events pass through `isCorrectUrl` and the selected validator.
* A desktop fallback polls popup location; it is not Android native behavior.

The source's default callback check searches only the first40 URL characters for substrings corresponding to `app`, `librus` and optionally `code`. Its query extraction uses a regex and does not itself percent-decode values. These are observed original quirks. **Recommended Siberia behavior:** parse the URI structurally, require the expected scheme/host/path and validate the initiated request correlation/state where supported. Decode exactly once at the correct layer. Label this a deliberate improvement rather than claimed source parity.

The Android `LaunchMyApp` plugin checks the initial intent on `deviceready`, waits for a handler up to ten additional500ms intervals, then calls `window.handleOpenURL`. `onNewIntent` checks non-null data/scheme, escapes the URI and passes a URL-encoded string through `javascript:handleOpenURL(...)`. Initial intent and later intent delivery therefore need separate fixtures. The clear-intent behavior depends on config preferences; default reset is false unless a relevant preference is true. Do not assume duplicate callbacks are impossible.

Illustrative callback test specification, not executable integration code:

```text
Start OAuth for owner A and remember request generation.
Deliver one valid callback; consume it once.
Deliver it again; do not exchange the code twice.
Deliver callback after owner A logout or switch to owner B; reject stale publication.
Deliver URL with expected words in an unrelated host/path; reject structurally.
Test escaped +, /, =, percent sequences and query error cancellation separately.
```

Reference sources: `helpers/oauth-helper.js`, `helpers/inappbrowser-helper.js`, `helpers/safariwebcontroller-helper.js`, `nl.xservices.plugins.LaunchMyApp.onNewIntent`, `plugins/cordova-plugin-customurlscheme/www/android/LaunchMyApp.js`. The [source index](source-map-index.json) gives hashes and map positions for first-party helper files; [web hashes](web-member-hashes.json) covers the packaged plugin bridge.

## 3. Native/local storage and cache

`helpers/native-storage-helper.js` writes the same value into WebView `localStorage` and NativeStorage when the latter exists. Reads prefer a truthy localStorage value; fallback reads NativeStorage. Delete removes both; clear clears both; restoring from NativeStorage runs when localStorage is empty. Offline store extension serializes module state as JSON under `state.offlineKey` and restores it through `JSON.parse`.

NativeStorage's Android implementation opens SharedPreferences using configurable name with default `NativeStorage`; `setItem` writes a string and commits. The plugin also has separately named secret/encryption actions, but the observed generic helper calls `setItem`, not those secret actions. Do not describe a store as encrypted merely because the plugin contains cryptography. This observation does not establish whether a particular account store applies an additional transform before calling the helper; follow its producer separately.

Recommended mapping: keep credentials and refresh material in Siberia secure storage under account owner; persist scoped module snapshots independently. A whole-store JSON restore must not overwrite another selected pupil/context. Handle malformed persisted JSON by quarantining that module and restoring defaults, rather than letting source `finally` behavior publish an undefined state. Clear only the intended owner or documented full reset. The generic source clear function is global; reproducing it verbatim in a multi-provider host would erase unrelated state.

## 4. Navigation gates and entitlement states

`store/modules/navigator-store/navigator-pages.js` defines page flags. Messages, justifications, homework and dashboard carry `premium`; reminders and MyGoals carry `premiumPlus`; recommended content/video descriptors carry `subscriptionNeeded`. Validation intentionally exempts the video preview from the general subscription block. LibrusGO routes and privileges are separate from Synergia's premium route checks.

`navigator-store_actions.validateNavigatorState` differentiates missing accounts, broken/unactivated accounts, subscription, premium/plus, Synergia-only pages, LibrusGO-only documents and LibrusGO candidate accounts. Debug/about/settings/feed and several recovery pages remain accessible for broken accounts. Menu filtering additionally hides premium/plus rows for JST under its own rules.

Meal menu requires a non-null integration status other than `UNSUITABLE_FOR_INTEGRATION`, and is hidden for JST/LibrusGO. LibrusGO document menu requires an account with document access. A hidden menu, a premium badge, a403 and an absent dataset are different states. A future provider must derive capabilities from actual account/config/server support; copying an entitlement label does not grant access.

Acceptance fixtures should enumerate: no linked account, active Synergia, expired/broken Synergia, missing premium, missing premiumPlus, subscription-only, video preview, LibrusGO candidate, LibrusGO valid with/without documents, JST, and meal integration unavailable. Record the supported surface explicitly. Developer-only diagnostics and original marketplace branding are inventoried; they are not necessary vendor-facing network features to recreate.

## 5. Push and account routing

`platform-tools-firebase-store_actions.initialize` registers token-refresh and message-received callbacks, checks permissions and gets a token. Android channel declarations include default notify sound plus separate grade5 and grade6 channels. Token refresh schedules change-register updates; Librus push registration is skipped for JST, and LibrusGO push updates run on the APP platform. Store restoration and token changes must be treated separately.

The fallback token starts with `drut_` and is generated locally. It is a web/device registration fallback, not proof that native push delivery is available. The Librus push store explicitly distinguishes real tokens from this prefix and disables push usage for a fallback token. Do not label registration success as notification-delivery verification.

Message click routing constructs `login` from `data.userId`, `type` from `data.objectType` and `openFeed` from `data.tap`. A `resourceType` branch routes LibrusGO push separately. A background tap triggers feed-update/navigation logic; other cases update through the timer handler. This provides the routing contract; exact payload shapes and delivery permissions still need controlled fixtures.

`PushConfiguration` defaults most categories true and `silentNight` false, then maps several switches to nested add/edit/delete fields. Categories include grades, attendance, calendar, notes, homework, announcements, messages, lucky numbers, timetable types, planned/realized lessons, free days and meal balance/news. Librus portal summary/reminder topics and LibrusGO topics are separate stores/API families. Reuse Siberia's own FCM/APNs configuration, owner mapping and background handlers; vendor push credentials are not transferable configuration.

## 6. Photo selection, preparation and transfer

Shared `PhotoPicker.vue` accepts PNG/JPG/BMP/JPEG MIME strings. It chooses native camera/gallery where available or a file input fallback. Native options use FILE_URI, JPEG, picture media, back camera, orientation correction, no native allowEdit, quality100 and saving to photo album when using the camera. Missing camera falls back to gallery; selection cancel and permission-denied20 have distinct UI outcomes.

The generic picker displays size as `(bytes / (1024*1024)).toFixed(2)` and rejects when that display value is at least10. This means the original boundary is rounded MiB, not an exact10,000,000-byte limit. Files below5MiB bypass compression; larger accepted image inputs request max5MiB, max dimension1920, no web worker, five iterations, initial quality0.7 and image/jpg. The browser-image-compression request is a target, not proof every output reaches that size. Do not reuse Fryderyk's decimal10MB policy here.

Homework upload first fetches file-transfer restrictions and differentiates general upload disablement and 3G restrictions, then calls its answer-attachment API. Error UI distinguishes connectivity, slow transfer,403 submission limit/block, and file-transfer restriction. School ID photo and avatar flows have their own preparation/validation; the generic homework picker is not a complete definition of those server constraints.

Recommended future fixtures: native/gallery cancellation, denied permission, missing camera fallback, unsupported MIME, malformed image, EXIF orientation, rounded10MiB edge, compression failure, 3G restriction, slow transfer, server validation rejection, submission accepted but response lost, and selected-account switch during file read/upload. Preserve pending/confirmed/uncertain results; do not blindly submit the same solution twice.

## 7. Cross-platform and completeness limits

The [parity ledger](cross-platform-parity.json) proves all1331 first-party app map source-content records match across supplied8.4.1 APK/IPA. It also records platform bridge/build differences. Equality of source-content does not make iOS permission prompts, browser behavior or file-provider semantics equal to Android. Original source maps are authoritative packaged evidence but still require pairing to their executable bundle and selected callers.

The [195-row checklist](feature-inventory.json) covers semantic surfaces; [308-component action index](ui-action-index.json) gives the broader bounded template/action inventory so later agents can inspect a feature omitted by a semantic grouping. APIs, API resources and transformations must be confirmed by the operation ledger and response/DTO documentation. Presence of a handler or reusable component alone does not establish a role's permission, request method or accepted write payload.

Implementation acceptance is per capability: exact synthetic serialization, correctly scoped state and errors, meaningful UI/DTO fixture, current source anchors, then authorized runtime verification if exposed. No live server result is asserted by this platform guide.
