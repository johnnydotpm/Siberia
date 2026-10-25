# MobiReg music editions: integration dossier

The supplied Android 2.1.79, additional Android 3.1.7 XAPK and iOS 3.1.7 packages have the same application identifier, `pl.mobireg.eparent.music`, but use substantially different client generations. Android2.1.79 is a native Java/Kotlin application with a relational SQLite cache and a legacy `njson.php` protocol. Both 3.1.7 releases are newer Flutter/Dart applications (`package:rodzic`) with JWT authentication, module sessions, mail and homework APIs, and many more candidate features.

Implementing only the legacy Android2.1.79 protocol does **not** establish support for all functionality of either supplied3.1.7 application. Preserve two protocol profiles and an explicit capability map. Do not assume that a school supports either profile until its version/response is verified.

## Deliverables

- `features.json` / `feature-matrix.csv`: 61 feature records covering accounts, academic data, writes, media, offline state, notifications, settings and vendor support behavior. Each has version, evidence reference, side effect, contract status and a validation task. A feature being listed is not evidence that its contract is ready.
- `protocol.json`: recovered legacy contracts and clearly marked modern candidates.
- `android-protocol.md`: legacy transport, authentication, sync and data semantics.
- `ios-modern-contract.md`: modern feature and session inventory, candidates and unresolved contracts.
- `android-field-mapping.json`: all 34 legacy import tables and 13 shared-library export mappings, including JSON-to-cache aliases and data types.
- `android-cache-schema.json`: 37 packaged local cache table schemas, including local-only tables. This is not a wire schema.
- `ios-selected-evidence.json`: 393 selected Dart object/string observations with offsets, source identity and limitations. No raw Firebase settings or token values.
- `modern-android.md` / `modern-platform-comparison.json`: additional Android3.1.7 identity, snapshot evidence, exact candidate literal cross-check and platform/build differences.
- `source-identities.json`: hashes and sizes of the primary compiled evidence carriers.
- `extract_dart_strings.py`: read-only reproducible candidate Dart object/string scanner for supplied iOS build.
- `compare_modern_snapshot.py`: length-marker cross-check for selected iOS literals in the supplied Android3.1.7 snapshot.
- `build_handoff_data.py`: emits feature/protocol JSON and CSV, preserving modern Android evidence when the comparison JSON is present.

The complete local `jadx/` output and raw string dumps are analyst scratch evidence and should not be copied into Siberia or published as an implementation. Build independent adapters from the documented behavior.

## Evidence ledger

`MR-A*` identifiers are analyst references to the supplied APK, decoded by JADX 1.5.6. The APK SHA-256 is `6cf44e486c7d8d6560aa5e5b1e946c46c1b86cbe545c6882db9bc7b70d4476e8`. All class paths below are inside the decompiled `sources/` directory. They remain locatable by fully qualified class and method when output line numbers differ.

| ID | Evidence locator | Finding and limitation |
|---|---|---|
| MR-A01 | `resources/AndroidManifest.xml`; `pl.mobireg.eparent.BuildConfig`; IPA `Info.plist` | Music application IDs and platform versions. Declared activities/permissions do not prove executed behavior. |
| MR-A02 | `mobireglib/sync/SyncParameters`; `eparent/sync/SyncHelperEparent`; `eparent/logic/UserAccountForm`; `mobireglib/sync/SyncHelper.getStudentList`; `mobireglib/db/model/StudentModel` | Credentials, endpoint construction, pupil discovery, IDs and date windows. |
| MR-A03 | `mobireglib/net/BasicHttpAdapter`; `NetServicesFactory`; `CommunicationManager`; `mobireglib/sync/SyncHelper`; `ServerSettingModel` | POST encoding, compression, timeouts, errors and protocol version. |
| MR-A04 | `mobireglib/sync/config/MappingConfig`; `FieldMapping`; `DataSyncImportTask` | Complete import/export field definitions and delta semantics. Shared library export declarations alone do not grant teacher functionality. |
| MR-A05 | APK `assets/database.sql` and `assets/create_settings_db.sql` | Cache schemas and relationships. Local SQLite columns are not automatically API fields. |
| MR-A06 | `mobireglib/db/model/MarkType`; `marks/MarkGroup`, `MarkHolder`, `NumericMark`, `ScaleMark`; `eparent/activities/marks/*`; `MarkDetailActivity` | Four grading types, weights, visibility, corrections and detail views. |
| MR-A07 | `eparent/providers/OverallDataProvider`, `AttendanceProvider`, `ScheduleProvider`; `mobireglib/db/AttendanceDatabaseAdapter`, `ScheduleDatabaseAdapter`; `AttendanceTypeModel`; corresponding activities | New-item counters, calendar/day views, attendance and timetable joins. |
| MR-A08 | `eparent/providers/MessageProvider.markAsRead`; `feature/messages/MarkMessageAsReadWork.doWork`; `network/UploadFcmTokenService` | Local message read plus POST server acknowledgement. |
| MR-A09 | `eparent/fcm/FcmService`, `RemoteNotificationKind`, `NotificationRenderer`, `UploadTokenWork`; `network/UploadFcmTokenService` | FCM payload fields, routing kinds and registration call (including focused `UploadTokenWork.simple.java`). Vendor Firebase registration compatibility with Siberia is not verified. |
| MR-A10 | `eparent/activities/ConfigurationActivity`, `DatabaseManagementActivity`, `WelcomeActivity`, `AccountListActivity`, `EditAccountActivity`; `MainSettings`; string/layout resources | Account/configuration/help, database reset, OS settings, rotation, updates and support. Some legacy beta-update classes are library residue rather than current UI. |
| MR-A11 | `eparent/activities/EdziennikActivity.refreshSyncLimit`, `setFreeFeaturesEnabled`, `setPaidFeaturesEnabled`; `utilities/PermissionUtils`; `mobireglib/db/model/Permission`; `sync/SyncException` | Subscription/sync limits, expiry, error codes and source UI gating. |
| MR-M01 | Android3.1.7 `config.arm64_v8a/lib/arm64-v8a/libapp.so`; `modern-platform-comparison.json` | 381/393 selected iOS literals found with compact length/encoding marker; eight private-symbol variants; source revision6f4e7b8 differs from iOSd20dd8d. No behavior/call-flow equivalence claimed. |
| MR-I01 | IPA `Payload/Runner.app/Frameworks/App.framework/App`, hash in `source-identities.json`; `ios-selected-evidence.json` | Candidate Dart strings/models/screens and schema text. Existence of a literal or class name does not prove reachability, endpoint method, payload association, execution or current server support. |

Class paths in MR-A02–MR-A11 begin with `pl/mobireg/`. Raw decompiler output is evidence and may contain artifacts or incorrect control flow; it is not source to transplant.

## Coverage and remaining work

Legacy Android2.1.79 package/resources and all app namespace classes were decompiled; JADX reported 84 errors across the whole dependency tree. Core request construction, import mappings, importer, error mapping and the message-read worker are readable. `RegApiReader.nextTable` and `UploadTokenWork.doWork` were recovered with a focused JADX `simple` pass after the default pass failed. Their unstructured control flow should still be checked against fixtures. No emulator, login, live server, message send, upload or notification registration was performed.

iOS `App.framework/App` candidate Dart objects were scanned structurally using class IDs 94/95, 8-byte alignment and Smi string length. This recovered 39,293 valid candidate strings, including 4,728 UTF-16 strings with Polish UI/log text. These data establish a much broader candidate feature surface. The additional Android3.1.7 carrier corroborates the modern candidate surface: 381 of393 selected literals match with length/encoding markers; eight private-symbol suffix variants are recorded. It has revision6f4e7b8 rather than iOSd20dd8d. Exact modern request and mutation contracts remain unresolved until native call-flow analysis or an authorized runtime capture supplies them. The framework's compiled code must not be described as fully decompiled.

No bounded search found a separate practice diary, repertoire catalog, tuner, metronome, booking workflow or payment integration in MobiReg's app-specific models/screens. Do not infer such capabilities from generic MIME strings, audio plugins or the word “music.” This is a bounded negative finding, not proof that the vendor has no such web modules.

## Implementation gates

1. Use a provider/profile-specific session and tenant-qualified IDs. Account identity includes provider, school origin/path and login; pupil IDs alone are insufficient.
2. Implement and fixture-test the recovered legacy read protocol, pupil discovery, full/delta importer and message-read command independently of modern modules.
3. Resolve the modern auth/session/envelope contract, then each operation listed in `features.json`. Retain raw payloads for unmapped fields and model kinds.
4. Add modern functionality only when its contract and account role are verified. A visible button with an invented endpoint is not integration support.
5. Gate every write behind its documented feature capability; commands require explicit method/body, error handling and reconciliation. Fixtures must cover partial file failure and stale auth retries.
6. Preserve offline data on network/protocol failures. Show last successful sync and per-module status; never overwrite valid cache with a failed request's empty list.
7. Finish with runtime verification of all 61 checklist records. Mark unsupported, vendor-only, library-only and unresolved items explicitly; do not silently drop them or claim full parity.

Release acceptance requires synthetic fixtures plus consenting role-appropriate test accounts for password login, QR login, multi-account/multi-child switches, message sending/read states, justifications, polls, homework submissions, attachments and notification handling. Redact student data, passwords, session cookies, QR contents and tokens from retained captures.
