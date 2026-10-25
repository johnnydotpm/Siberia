# Deeper legacy MobiReg contracts: caller-chain corrections

These findings apply to the original Android2.1.79 music APK, SHA-256 `6cf44e486c7d8d6560aa5e5b1e946c46c1b86cbe545c6882db9bc7b70d4476e8`. They were recovered by following request parameters back to their producers. They must not be applied to either modern3.1.7 application without independent proof. No school API was called.

## The parent password field carries an MD5 digest

The previous dossier called `parent_pass` the user's diary password without specifying the transformation. The actual form-to-request chain is:

1. `EditAccountActivity.onCreate` installs a password focus-change listener. When the password input loses focus and is nonempty, the listener stores `Tools.computeMd5(input)` through `AccountModel.setPassword` and clears the visible input. Empty input preserves the existing stored value.
2. `EditAccountActivity.updateItemFromView` requests focus on the URL input before storing account name/URL. This causes the password input to lose focus under normal Android UI behavior; that lifecycle consequence is inferred from the explicit listener/focus code, not an observed UI run.
3. `AccountModel.getPassword` returns the stored registry account value unchanged.
4. `SyncHelperEparent.getSyncParameters` assigns that value directly to `SyncParameters.parentPassword`.
5. `SyncParameters.addCredentials` sends it as `parent_pass` unchanged.

`Tools.computeMd5` computes MD5 over `String.getBytes()` and formats every byte as two lowercase hexadecimal digits. The source uses the platform's default charset rather than an explicit charset argument. On Android the intended text encoding is UTF-8; verify non-ASCII behavior in the compatibility test rather than using a host platform's default charset accidentally. A Unicode-normalization pass, trim, uppercase conversion or second hash would change the credential. The raw text and the already-hashed stored representation are different states.

This producer chain is shared by pupil discovery, settings, full/delta synchronization, FCM registration and message-read acknowledgement. Each uses the same `SyncParameters` or its fields. **A new adapter must not send the newly entered raw password as legacy `parent_pass`, nor hash the stored digest a second time.** The digest is a reusable password-equivalent credential and belongs in secure account storage.

Canonical REA evidence retained locally:

- `rea-md5.json`: `ev_279d652a06d44441fb0ffe1d37508fb1c53a5c22bac2d2b069a2abfd3adfda72`, `pl.mobireg.eparent.utilities.Tools.computeMd5`.
- `rea-account-oncreate.json`: `ev_fcfcc3509797c055ffd5a30da1ae233f1dcd80065dfb6f8f3e887b73e2e4ec66`, `pl.mobireg.eparent.activities.EditAccountActivity.onCreate` including the listener body.
- Existing `analysis/rea-mobireg-sync-parameters.json` and `analysis/rea-mobireg-delta-method.json` retain the destination request builder. `AccountModel`, `SyncHelperEparent` and `updateItemFromView` are in the full local JADX output.

The synthetic password vectors in `legacy-contract-details.json` validate the intended adapter encoding. They are analyst-generated MD5 examples, not observed school accounts or backend fixtures.

## Pupil and account ownership are different

`UploadTokenWorkScheduler` can take an account name. `UploadTokenWork.doWork` obtains all stored accounts and filters by **login name alone** when a filter is supplied; with no filter it includes all accounts. For each selected account it builds that account's own school URL and digest-backed credentials. If two schools use the same login name, the old scheduler can select both. Siberia should route by its tenant-qualified account identity rather than copy the ambiguous login-only selector.

The worker calls `/modules/api/njson.php` with `view=ParentStudents` and `token=<FCM token>` in addition to the common form fields. It does not add a pupil ID in that call. `SyncOneStudentUseCase.syncOneStudent(account,pupil)` schedules that account token upload before starting pupil synchronization, but the upload remains an account operation.

`MarkMessageAsReadWorkScheduler` stores local account/pupil/message IDs in WorkManager input. The worker uses them to find the current local account and child, then constructs `/modules/api/messages.php` with account credentials and `action=read`, `message_id=<server message ID>`. It sends no pupil field. `MessageDatabaseAdapter.getMessagesForStudent(int)` does not use its argument as an SQL predicate; isolation comes from the selected database. Scope normalized mail identity by provider/account/message ID, and retain the child's display/context link separately when necessary. Do not treat a local pupil row ID as a wire identifier.

## Response date and cursor details

`DateTimeDeserializer` uses `SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss")` for Gson-mapped server dates, then builds a date4j value from local date/time components. It supplies neither an explicit timezone nor a locale. This is a local wall-clock interpretation, not evidence of UTC. It does not establish timezone support for every table's raw date fields.

By contrast, delta request `lmt` uses date4j formatting `YYYY-MM-DD hh:mm:ss` with a space. The server settings `time` is decoded by the Gson deserializer and becomes `lastSyncTime`, so the conversion crosses two textual grammars. The new adapter needs distinct response-decoding and request-encoding code, with explicit school timezone handling and fixtures near midnight/DST boundaries. Do not serialize the response ISO-like `T` string back unchanged and assume it is the required `lmt` representation.

`SettingDBModel` initializes date cursors to2010-01-01 and local validity false; its database identity starts empty and permission support0. `DataSyncImportTask` allows delta only with a valid local cache and matching server settings ID, then uses the server's settings timestamp as the next cursor. Client wall-clock “now” is not the cursor.

## Request decoding and local acknowledgement edge cases

`CommunicationManager.isErrorAnswer` recognizes an object containing `errno`, optionally wrapped in a one-element array. However, `getStudentList` and `getServerSettings` first call `.getAsJsonObject()` on the parsed root. A root array therefore fails before their error check despite the generic helper's wider support. Do not infer universal array-wrapper support from the helper in isolation. Pupil success expects `ParentStudents` array; settings success expects `Settings[0]`.

`RegApiReader.nextTable` was recovered with the focused JADX `simple` pass. It reads the JSON token stream until a name immediately precedes an array, returns that name while leaving the array token for `nextObject`, and skips other structural/scalar tokens. If it reaches end-of-document without ever finding a table, it reconstructs the traversed JSON and tries to decode it as an `errno/message` error. This is not a tolerant arbitrary REST envelope parser. Nested arrays or unknown schemas require captured fixtures before asserting support.

`MessageDatabaseAdapter.markAsRead` writes a local timestamp and `record_status=1` immediately. Its badge counts `read_time IS NULL`. The separate network worker converts an `IOException` into `Result.success()`, so a disappeared local badge does not prove server acknowledgement. A new adapter should retain acknowledgement state and reconcile rather than presenting that source-client behavior as a server guarantee.

The source permission utility ignores grant time in `Permission.isValidTime` and checks expiry only. A valid row with null quantitative limit immediately returns0; otherwise it sums positive limits. These are observed client decisions, not a reliable entitlement schema definition. Preserve server errors200/201 and verify permission meanings rather than assuming null means unlimited or copying a possible client quirk.

## Implementation changes required by these findings

- Separate `rawEnteredPassword` from `legacyPasswordDigest`; make the one-time boundary transformation explicit and test non-ASCII vectors. Never apply it globally to the modern auth provider.
- Reuse one secure credential/session owner per tenant-qualified account. Link children to it; keep child/range/term data scopes separate.
- Treat legacy FCM token registration and message acknowledgement as account-level commands even when invoked from child UI.
- Decode server settings wall time independently from delta `lmt` encoding. Advance the cursor only after a successful committed import.
- Keep local message read state distinguishable from pending/failed/confirmed remote acknowledgement.
