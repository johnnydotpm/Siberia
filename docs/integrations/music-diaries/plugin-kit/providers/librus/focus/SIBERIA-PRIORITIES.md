# Focused future-agent work order

All changes below are proposed. The inspected current-main source is `fdd022da1759caf254873fbb6d8ffdea7e360b68`; the documentation branch's application tree is older. Recheck repository instructions and source drift before implementing. The adjacent JSON evidence retains current-source hashes and anchors. No application patch is included.

## What Siberia already has

`syberia/lib/src/ui/shell/grades.dart:_GradesOverview` already shows a calculated average, grade count and1–6 distribution, with per-profile averages in the together view. `domain/models.dart:GradeAverageSettings` already supports configurable plus/minus modifiers and weighted/unweighted averages. Defaults are plus0.5, minus0.25, unweighted. It skips grades with weight<=0 and values it cannot parse. A null result represents no usable grades.

The existing grade distribution calls `valueOf`, then rounds/clamps to1–6. Thus `4+` with default modifiers becomes4.5 and falls into bucket5. The official Moje cele histogram instead strips the sign and counts it in bucket4. These are different chart definitions, not automatically an implementation defect. A future feature should choose and label the intended definition; do not silently change Siberia's existing histogram under the assumption that all grade charts use the same arithmetic.

`ui/shell/attendance.dart:_AttendanceState` already filters first/second/full-year attendance and offers chart styles plus subject detail. Its input is normalized `AttendanceRecord`; the existing `AttendanceKindDetails.countsAsPresent` policy includes late, late-excused, released and other as present-like values. That must not be silently reused as the official Moje cele denominator/category policy. Unknown source types and omitted records can materially change the displayed percentage.

The inspected Librus client does not expose a justification list/submit flow, and the host domain has no corresponding typed justification entity. A string containing “uspraw” in attendance normalization only detects already excused attendance; it does not implement e‑Usprawiedliwienia.

## P1 — Preserve the source data and distinguish calculation kinds

Files: `data/librus/librus_client.dart`, `domain/models.dart`, `data/snapshot_cache.dart`, `data/app_repository.dart`.

Add provider-preserving grade/attendance metadata before implementing charts that need currently discarded distinctions. Keep source category/type IDs, source family, inclusion flags, weight availability, original grade string, official versus local timestamps and source period. Do not infer a source restriction from a normalized display name. Keep raw/source metadata scoped to the existing profile owner; do not introduce a second global Librus login.

Represent at least three average origins: school-reported result, Siberia user-configured estimate, and optional official-app-methodology local statistic. Preserve null/missing and the exact server property identity for first-semester/second-semester/annual final-grade averages. A convenient `average:double` without origin or period is insufficient.

Acceptance: descriptive/point/unknown grades do not turn into standard marks; empty/missing results remain unavailable; plus/minus settings affect only the explicitly selected local policy; a record excluded from one average can remain visible in the appropriate distribution if that chart's definition permits it.

## P2 — Extend statistics using a pure aggregation layer

Files: `domain/models.dart` or a new dedicated statistics domain module; `ui/shell/grades.dart`; `ui/shell/attendance.dart`; `state/app_controller.dart`; localized resources.

Keep calculation functions independent of UI and transport. Inputs should include captured profile/school year, date interval, source records, grade family, aggregation policy and completeness metadata. Outputs should include values, denominator/count, period, method/origin and unavailable/error state. The UI can then expose grade distribution, trend/weekly or monthly summaries, attendance breakdown and non-preparedness data without making each widget recalculate a different policy.

Use the exact algorithms in STATS when reproducing an original chart, and explicitly document deliberate improvements such as year-aware week keys, zero-denominator handling, bounded series and corrected date filtering. A locally generated summary can be a Siberia feature without depending on the official push-history service. Label it as local; do not claim receipt of an official monthly report.

Acceptance cases: `4+` histogram grouping versus numeric averaging; a zero-weight grade; all invalid/descriptive grades; empty date interval; a grade exactly at the end bound; December/January week collisions; sparse weeks; no attendance denominator; custom attendance type mapped to a standard type; cached data incomplete/stale; changing active profile while calculation/fetch completes; together view never combines pupils into one unexplained average.

## P3 — Add school-reported totals as a separate read capability

Files: `librus_client.dart`, `app_repository.dart`, cache/model mapping, grade period summary UI.

Use the linked Synergia account's own API token. The recovered chain resolves `/Auth/TokenInfo` when an account identifier is missing, converts a parent identifier through `/Auth/UserInfo/{parentId}` when needed, then POSTs `/Auth/Grades/StandardWithAverages/Students/{studentId}` with `{limit:1}` and reads `data.averages.total`. The original caller recognizes student group `'student'` or numeric8. A login string is not automatically the student identifier.

Keep this3.0 capability independent of Siberia's existing2.0 fallback. Verify that the selected token and third-party access work against the service before enabling it. Store returned `firstSemesterFinalGrades`, `secondSemesterFinalGrades`, `annualFinalGrades` without substituting a local mean of all partial marks. No class-wide distribution endpoint is established by this chain.

Acceptance: parent→pupil resolution, student direct path, missing identifier,403/401/technical break, missing total fields, real zero versus missing, stale totals preserved on optional failure and semester/year separation.

## P4 — Add read-only justification history before compose

Files: `librus_client.dart`, `domain/models.dart`, `snapshot_cache.dart`, `app_repository.dart`, `state/app_controller.dart`, attendance UI and a typed detail page.

Introduce a provider DTO and normalized justification model with source ID, selected owner/profile, date range, lesson numbers, parent message, post timestamp, raw status, attachment metadata, count of justified absences and teacher notifications. The focused protocol document gives exact wire keys and consumer rules. Preserve unknown status; do not inherit the original UI's “everything else is rejected” fallback.

Fetch list for a bounded school-year range and single details as needed. Treat module403 as unavailable/denied, transport failure as failed/stale, and valid empty history as empty success. Do not infer availability by searching a localized exception message for403. The old module-global availability promise should become owner-scoped or use the existing profile orchestration.

Acceptance: list/detail and raw DTO fixtures; submitted versus accepted; an unknown future status; date-only formatting; a record with an attachment flag but no recovered upload/download operation; active profile change; reload from old cache without justification fields; denied module retaining previous data with a clear state.

## P5 — Add compose as an explicit mutation workflow

Files: repository/controller operation methods, a new justification compose UI, localized feedback and pending-operation state.

Capture the target profile at compose start. Follow role/date/lesson-number/sendNotify rules from E-USPRAWIEDLIWIENIA; serialize the exact parent-message/date/lessons map. Present the selected child, dates and lessons for review before the user's send action. Do not send during draft changes or app startup.

On a confirmed ID, persist the submission identity before fetching detail. If detail refresh fails, show “submitted; details pending” rather than offer a second POST. If sending times out after transmission, mark outcome uncertain and reconcile list/history before allowing a duplicate attempt. There is no recovered idempotency key to make replay safe.

Refresh justifications and affected attendance after school acceptance/change events. Keep the request's status and official attendance separate: submission alone must not locally excuse every selected lesson. Do not expose edit/delete/attachment actions whose network contract has not been recovered.

Acceptance: today/past/future and exact end-of-day boundary, whole-day versus selected lesson numbers, ineligible role,403, business/protocol failure, confirmed submission plus failed detail fetch, uncertain timeout, double-tap, account removed during send and later official acceptance.

## Focused future-agent prompt

> Read the focused statistics and e‑Usprawiedliwienia protocol documents, current-source anchors and H-LIB service/session rules. Implement only the assigned P1–P5 task on current main. Reuse existing multi-profile ownership, optional-result handling and chart settings where appropriate. Preserve raw fields and separate school-reported values from local calculations. Add meaningful serialization/calculation/race fixtures with synthetic provenance. Do not claim live support without authorized account verification. Return changed files, exact checks and remaining capability gates.

Documentation approval is not authorization to submit a justification for a real pupil. Future runtime verification should use a controlled test account and an explicitly chosen test action.
