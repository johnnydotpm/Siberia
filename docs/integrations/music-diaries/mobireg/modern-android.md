# MobiReg Android 3.1.7: additional modern target

The additional `MobiReg_3.1.7_APKPure.xapk` is the modern **music** Android app, package `pl.mobireg.eparent.music`, version3.1.7/build116. It is distinct from the original Android2.1.79 APK. Its original XAPK SHA-256 is `a8ab26b4101507ce7e80f067ee135dc7632571facb26358042da02487b5010e7`.

The XAPK declares minimum Android SDK24 and target36. Its base APK and ARM64/config/language splits are separate packages. The Flutter app's AOT carrier is `config.arm64_v8a/lib/arm64-v8a/libapp.so` (10,421,128 bytes); hash and evidence offsets are in `modern-platform-comparison.json` (`MR-M01`). The base Flutter assets have the same small application asset surface as the supplied modern iOS app: manifests, Material/Cupertino fonts, shaders and plugin web workers/scripts. There is no packaged readable Dart source tree.

Android stores its Dart strings in a compact serialized snapshot rather than the iOS aligned heap-object layout. Reusing the iOS scanner would miss strings or misinterpret metadata. `compare_modern_snapshot.py` checks each selected iOS literal against the Android bytes **with its compact length/encoding marker**, which avoids reporting `/api/messages` merely because `/api/messages/trash` contains that prefix. It also records differing numeric private-symbol suffixes. This is a partial format-aware content comparison, not a full snapshot decoder or decompilation.

The modern Android stamp is `Wersja 3.1.7 (build 116, 6f4e7b8)` at file offset `0x47c9d`. The iOS stamp instead has revision `d20dd8d`. Equal version/build numbers therefore do not establish equal source revisions, feature reachability, API calls or runtime behavior. All shared feature records retain their unresolved contract status.

## Modern functionality cross-check

Length-marker matches establish the same app-specific `package:rodzic` models/repositories/screens for grades/terms/subjects, attendance, dashboard, timetable/events/exams, homework and solution files, announcements/voting/pending polls, reprimands, justifications, mail/compose/recipients, accounts/auth/QR, notifications and cache. They also confirm credential/QR/refresh/session log text and the advanced local settings/media/cache candidates documented in `ios-modern-contract.md`. See the exact match/missing lists rather than assuming every private symbol is identical.

These modern candidate capabilities may now be attributed to **both supplied3.1.7 platforms at the static content level**, with evidence `MR-I01` and `MR-M01`. Legacy2.1.79-only sync/entitlement/read contracts stay separately sourced; do not overwrite the legacy profile or silently carry `njson.php`1.6.0 rules into the new client.

Independent byte searches found the iOS literal `sendAnnouncement` absent from the Android AOT carrier. The voting widgets, answer and pending-poll evidence remain present. Do not interpret that single missing symbol as proof that Android cannot answer a poll, nor assume an iOS-only send operation is exposed; recover the actual call path. Several private `@number` suffixes and iOS-specific picker/camera symbols also differ as expected across builds/platforms.

An **independent complete app-owned source-path scan**, rather than only the selected positive cross-check, recovered137 unique `package:rodzic/...dart` paths on each platform. The sets are identical: no Android-only or iOS-only app-owned source-path literal was found within that boundary. This supports the same candidate module inventory, not equivalent implementations.

The independent ASCII path-literal scan recovered62 Android candidates and61 iOS candidates,60 shared. The only Android-only strings were `/J` and `/Q`, two very short candidate matches that may be accidental binary matches; neither establishes an extra feature or endpoint. The only iOS-only path was the Foundation system framework location. No Android-only API/app-route candidate was found by this bounded scan. Full lists, offsets, regex boundary and differences are retained in `modern-platform-comparison.json`; URLs with spaces, dynamic construction, encoded paths or unrecognized string representation remain outside this scan.

## Exact endpoint/path content

`modern-platform-comparison.json` contains the exact standalone-literal Android offsets for these shared candidates:

- `/modules/api/auth.php`, `/modules/api/refresh.php`, `/modules/api/qrlogin.php`, `/modules/api/app.php`.
- `/account/ssov2/`, `/account/ssov2/<token>`, `/sso`.
- `/api/messages`, `/api/messages/`, `/api/messages/inbox`, `/api/messages/sent`, `/api/messages/important`, `/api/messages/trash`, `/api/messages/read/`, `/api/messages/receivers`, `/api/messages/receivers/search`, `/api/unreadMessages`.
- `/api/homeworks/datatable`, `/api/homeworks/`.
- Gateway/suffix candidates such as `announcement-answer`, `announcements-pending`, `register-fcm`, `unregister-fcm`, `notif-settings`, `attendance-stats`, `justification-events`, `homework-status`, `homework-module`, `homeworks-module`, `/stared`, `/restore`, `/archive`, `/files` where listed as exact matches.

The first group identifies authentication/gateway candidates; mail/homework groups identify possible module APIs. Their HTTP verbs, body association, authorization scheme, response envelope and execution order **remain unresolved**. App routes such as `/justifications`, `/timetable` and `/homeworks` are not automatically backend APIs.

## Next-agent handoff

Use this Android AOT binary as a platform-appropriate follow-up target for native call-flow analysis or a consented emulator/device capture. Recover auth, gateway and SSO first, then each read/mutation contract in `features.json`. Android may be easier to run than the supplied iOS app, but no Android runtime was executed in this investigation. Capture no real student data in public fixtures; use synthetic records and redact credentials/session/QR/push values. A complete3.1.7 integration still requires contract verification rather than literal-based endpoint guesses.

To reproduce the full comparison after extraction, generate the complete iOS string JSON with `extract_dart_strings.py`, then run `compare_modern_snapshot.py --android-carrier <libapp.so> --ios-full <full-ios-strings.json> --selected <ios-selected-evidence.json> --output <comparison.json>`. The full iOS dump is a local intermediate, not a file to publish wholesale.
