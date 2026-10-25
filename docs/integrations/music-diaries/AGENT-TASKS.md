# Next-agent task sequence

> Historical first-pass handoff. Prefer the [detailed specification and agent runbook](plugin-kit/siberia/AGENT-RUNBOOK.md) for recovered endpoint/auth contracts, field schemas, examples and remaining gates. In a conflict, the newer version-scoped caller evidence takes precedence.


## Working rules

Read the repository's current `AGENTS.md`/instructions and compare HEAD with baseline `c09caaa5f2780a9e1c60aaf94bf9e02e25fe4efc`. Source paths below refer to the real `syberia/` app directory. Read the architecture handoff before modifying code.

Use `coverage.json` as the acceptance register. Keep its app feature IDs stable, record implementation paths and test evidence, and retain unresolved questions. A static feature observation is not a passing end-to-end test. Mark each dimension separately: contract, implementation, fixtures, runtime, role/server/version scope.

Do not recover or publish student data unnecessarily. Future authenticated investigation requires a supplied/authorized test session. Use local mock fixtures until then; create real messages, justifications, homework answers or votes only within an authorized test operation. Do not treat this research request as permission to send messages to school staff.

## Task 1 — provider foundation and backward compatibility

**Prompt:** Implement the provider foundation described in `siberia/ARCHITECTURE-AND-INTEGRATION.md`. Extract a Librus adapter without changing its behavior. Add stable provider IDs, an injectable registry, generic sync parts, per-context capability states and module outcomes. Introduce an auth-session owner identity and a separate selected provider/server/account/student/year data context, plus session-generation guards. Share rotating auth tokens across children only when the verified contract defines that ownership; never clone one refresh token into independently refreshed child/year records. Replace every Librus display-string gate in account loading, AppShell, controller, sent mail, background sync, notifications and home widgets. Migrate existing Librus snapshot/credentials/preferences atomically and idempotently. New empty provider adapters must explicitly report unverified capabilities instead of returning false-success refreshes.

**Acceptance:** Existing Librus tests pass; old signed-in installs load and preserve data; colliding IDs across providers/schools/children cannot mix data; stale responses after switch/logout are ignored; partial module failures preserve cached data; the background isolate uses the same registry; demo stays offline. Add meaningful migration/race/capability tests. From `syberia/`, run `flutter pub get --enforce-lockfile`, `dart format --output=none --set-exit-if-changed lib test`, `flutter analyze --fatal-infos`, and relevant `flutter test` suites, following the current repository CI.

## Task 2 — finish contract recovery before each adapter operation

**Prompt:** Use REA and the curated evidence to complete the route/model contract register for Fryderyk and each MobiReg protocol generation. Start with original artifact SHA verification. Prefer readable MobiReg Android request builders, sync parser and mapping classes; use Dart-aware ARM64 snapshot/object-pool reconstruction or authorized original-app captures for Flutter. Follow the exact high-priority gaps in the app reports. Record origin discovery, verb, path arguments, query/body/multipart names and types, authentication, response shape, error codes, date semantics, pagination and mutation confirmation for each operation. Preserve provenance and redacted structural fixtures. Do not infer ownership of a JSON key from string proximity.

**Acceptance:** Every enabled operation has a request-construction source/call site or a matching capture, typed structural fixture, error fixture and known role/version scope. Pure string candidates remain `unverified`, never upgraded through a guessed implementation. Clarify whether legacy MobiReg endpoints remain supported before selecting them as the default adapter.

This task can progress independently of foundation work. Its evidence gates apply separately to each feature; verified read operations need not wait for unrelated mutation contracts.

## Task 3 — Fryderyk enrollment and read functionality

**Prompt:** Implement only contract-verified Fryderyk operations. Add mobile-access onboarding, manual/QR/deep-link enrollment, origin discovery, secure token lifecycle, revocation/reconnect, profile/linked-child and semester selection. Preserve the original warning about regenerating mobile access after logout if verified for the selected protocol. Map current/next lesson, day timetable, music-specific lesson detail, substitutions, grade list/overview, predicted/final grades, attendance totals/lesson absences/request status, homework content/files/status. Account keys must include the provider context; do not reuse Librus auth or numeric ID assumptions.

**Acceptance:** Fulfill relevant `FRY-*` rows, with fixtures for text grades, unknown enums, accompaniment/exam/individual/remote/cancelled lessons, month/year attendance, semester boundaries, empty days, multiple children, expired tokens, offline cache, malformed QR/deep links and credential-origin isolation. Dates use verified school wall-time semantics. Homework display status is distinct from a local done checkbox and from actual server submission.

## Task 4 — MobiReg enrollment, sync and read functionality

**Prompt:** Select the verified protocol by discovered server capabilities, not by assuming all MobiReg servers share the supplied Android or iOS contract. Implement multi-school/account/child selection and secure auth. For the native legacy sync, implement the recovered form fields, protocol/table mapping, full/delta ranges, insert/update/delete actions and tombstones with transactional cursor advancement. Use the supplied Android and iOS 3.1.7 comparison for modern Flutter modules, and isolate API auth, mailbox SSO/cookies and homework module sessions. Version equality does not establish identical source revision or platform behavior. Cover grades/averages, timetable/substitutions/teachers/groups, attendance, announcements/polls, notices/reprimands, homework and profile/settings features listed in `mobireg/features.json`.

**Acceptance:** Fulfill applicable MobiReg feature rows. Delta/full sync tests include deletions, duplicate IDs, changed date ranges, unknown table/columns, interrupted imports, malformed rows and no cursor advancement on failure. Feature-denied/expired module sessions cannot sign out unrelated accounts. Keep music-specific lessons, school years and parent/student identities intact.

## Task 5 — messages and attachments

**Prompt:** Implement each brand's independently verified mailbox contract behind capability interfaces. Support observed folders, search/paging, unread counts, content/read state, sent messages and recipient discovery. Add compose/reply/reply-all/forward and Fryderyk CC/BCC only where evidenced. Model recipients as provider-qualified opaque strings. Build authenticated attachment streaming/download and temporary-file lifecycle; implement upload/draft removal/limits only from recovered policy. Verify delete/trash/restore semantics separately; do not fabricate restore from a Trash tab.

**Acceptance:** Folder paging terminates; concurrent reads reconcile counts; opaque IDs survive; BCC is not exposed to unauthorized recipients; quoted HTML and attachments render safely; validated file policy is enforced; auth does not leak through external redirect/resource URLs; partial upload and expired module session are handled. Sends and deletes reflect server confirmation and never auto-repeat an ambiguous mutation. Tests cover draft/attachment cleanup and account switches during download/send.

## Task 6 — provider-specific mutations

**Prompt:** Implement absence-change/justification requests, homework answers/uploads, announcement voting and any other evidenced write operations one capability at a time. Use the per-provider feature/gap files. Preserve pending/approved/rejected and teacher feedback states. Distinguish request submission from directly editing official attendance. Show the exact affected child/lessons/homework/poll before a user submits. Keep unverified operations disabled.

**Acceptance:** Controlled authorized test writes plus fixtures establish eligibility, permissions, validation, confirmation, uncertain outcomes, duplicate prevention and refresh reconciliation. Fryderyk homework submission remains unimplemented unless new evidence establishes its own write path; a submission-status field or message upload route is insufficient. Preserve role-specific and school-specific denials.

## Task 7 — full UI/platform parity and release review

**Prompt:** Finish every applicable feature row, including onboarding/help/profile, language/theme/preferences, offline/error states and supported update-required behavior. Make tabs/actions depend on current account capabilities. Add notification diffing, reminders and background refresh through the registry; distinguish provider push from local polling. Update Android/iOS next-lesson widgets and all five localizations. Do not use the original apps' Firebase project. Verify desktop file flows and QR fallback. Follow the exact platform limitations already in Siberia.

**Acceptance:** No Librus-only guard silently excludes new providers; platform widgets clear on logout/switch; notification deduplication is scoped to provider/server/account/student; background writes cannot replace newer foreground data; no unverified upstream-push claim; existing Librus/demo/migration tests pass. Run locked dependency resolution, format verification, full `flutter analyze --fatal-infos` and `flutter test`, then target builds in the project's existing CI. Original-app comparison covers every registered feature with the tested role/server/version noted.

## Final reviewer checklist

- Every feature in the register is `implemented_verified`, explicitly `unsupported` for a stated scope, or still openly incomplete. Do not silently drop rows to obtain a green status.
- New contract assertions cite evidence; design recommendations are labeled as design.
- No original binary, copied proprietary implementation, full string dump, credential, token, private fixture or student record enters Git.
- Profile load, provider switch, child/year switch, restart, offline mode, token expiry, logout and background/foreground races are tested.
- Real data and mutations are verified only with an authorized account and operation. Local fixture tests cannot be reported as live success.
- Release notes state remaining gaps and tested scope. Documentation must not claim all features supported while an applicable row remains unresolved.
