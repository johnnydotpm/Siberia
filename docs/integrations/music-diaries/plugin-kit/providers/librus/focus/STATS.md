# Statistics: exact recovered behavior and implementation guidance

Scope: shipped Librus8.4.1 Android/iOS application; the algorithms below were traced in iOS8.4.1(6487) source-map `sourcesContent`. Android parity belongs to the package comparison. This is documentation only. No account was logged into, no statistics endpoint was called, and no goals/notifications were created or changed.

Read the accompanying [stats-evidence.json](stats-evidence.json) for source URLs, map entry indexes, SHA256 values, exact line anchors and synthetic arithmetic examples. Original `src/...` names below are paths within shipped source maps, not included vendor source. Distinguish three products: **school-provided averages**, **locally calculated personal analytics**, and **goal/summary state stored through Portal APIs**. They must not be presented as one interchangeable statistic.

## What is established

| Surface | Inputs | Computation / output | Source family |
|---|---|---|---|
| School subject averages | `/Grades/Averages`, optional subject filter | Backend `Semester1`, `Semester2`, `FullYear`; app displays supplied values | Synergia API |
| Overall assessment averages | Student-specific StandardWithAverages API | Backend totals of first/second-semester and annual final grades | Synergia Auth API |
| Grade distribution | Selected standard grade records | Counts and percentages by grade1–6; plus/minus collapsed in chart | Local My Goals |
| Trend | Standard grade records by week/month | Unweighted bucket average and cumulative average line | Local My Goals |
| Potential / subject ranking | Each subject's standard grades in selected semester | Unweighted personal average; highest subjects first | Local My Goals |
| Absence chart | Attendance records/types | Counts of excused/unexcused absence, late, exemption | Local My Goals |
| Unpreparedness | Each subject's grade records | Exact `Grade==='np'` count | Local My Goals |
| Recent grades | Grade records in selected semester | Group by grade Date, newest date first | Local My Goals |
| User goals | Subject ref, target, period, last average | Portal CRUD; comparison against locally calculated current average | Portal mobile-addons API |
| Monthly summaries | Push notification metadata plus grades | App generates percentages/trend datasets locally | Portal trigger + local calculations |

The reviewed My Goals, average, summary and raw-API paths do **not** establish class/cohort percentile, class average distribution, a student's class ranking, teacher ranking or comparison against other pupils. `StandardWithAverages/Students/{id}` is a student endpoint; its `averages.total` is not evidence of a class total. A request for class comparison needs a separately recovered contract and legitimate response scope. This is a bounded negative finding over these paths, not a claim that no Librus product/server has such functionality.

## Original access and input selection

MyGoalsContainer has tabs for periods1and2. MyGoalPeriod initializes only when `user/isCurrentPremiumPlus` is true, refuses kindergarten-family accounts, loads `subjects/getViewModel(period)` plus `grades/getViewModel({login})`, then initializes individual cards. Original screen hides content offline. This is original-client access/display behavior, not a recommendation to require the same purchase for Siberia's independent local calculations.

The getter checks `me.PremiumAddons` contains exact string`MDPlus`. Monthly summary generation additionally checks `me.IsPremium` and excludes broken/nonactive accounts. Do not substitute flags, edit account entitlement data or claim a paid server capability is available without a real server entitlement. A future Siberia local-statistics feature can have its own product policy, clearly distinguished from Portal goal/push features.

`subjects-store.js/findAllSubjects` scopes records by account login, excludes Deleted=true, and filters ordinary Grades by `Semester===period` when period is supplied. My Goals cards therefore receive already-period-filtered subject collections; some cards also repeat semester filtering. Nonpreparedness does not perform its own semester check. Passing an unfiltered all-year array directly to that card would silently change its statistics.

Prefer stable subject IDs in new filters. Original charts often filter by display Name/SubjectName or compare only number of selected subjects against total; equal counts can be treated as all subjects even if identities differ. Namespace filters by account+academic year+period+section, not display label alone.

## Numeric grade eligibility and plus/minus

`chart-helpers.js/gradesWhiteList` contains exactly string values`1`through`6`, each with optional trailing`+`or`-`. These18 exact strings drive goal averages, trend and monthly summary eligibility. Numeric JSON5 does not pass the same `indexOf` test as string`'5'`. Values`np`,decimal`'4.5'`,text grades,behaviour points and values outside the list are excluded. `6+` becomes6.5 and`1-` becomes0.75; no clamp to1–6 occurs in these parsing helpers.

The personal-average conversion is:

```text
value("n")  = integer n
value("n+") = n + 0.50
value("n-") = n - 0.25
average = sum(converted eligible values) / number of eligible records
```

It is an **unweighted arithmetic mean**. The inspected goal, potential, trend and summary-average functions do not multiply by category Weight, do not filter CountToTheAverage and do not independently remove final/proposed/semestral assessments. Eligibility is the received ordinary Grades relation plus whitelist and upstream scope. Resits remain as supplied by that relation; the calculator does not deduplicate an improvement chain.

This can differ substantially from a school's official average. Preserve a `methodology` label in Siberia such as `personal_unweighted_plus050_minus025`, separate from `school_reported`. A proposed weighted calculator must use separately verified school configuration and input rules; it should not be described as the original My Goals algorithm.

Worked synthetic example: eligible`['5+','4-','3']` converts to`[5.5,3.75,3]`, sum12.25, count3, mean4.083333…. Add raw`np` and it remains4.083333…. Add numeric JSON5 and the exact-whitelist implementation still excludes that numeric record. With records5(weight1,includedtrue) and2(weight4,includedfalse), original personal mean is3.5; weighted average over both would be2.6 and included-only would be5. These are three different methodologies, not rounding differences.

`my-goal-calculator.js` optionally filters by **AddDate** same-or-before a cutoff day. Trend/distribution instead group/filter by **Date**. Keep both dates in the DTO. A date cutoff can remove all previously eligible rows after the early empty check, yielding division0/0 in the original helper; a new implementation should return explicit no-data rather than NaN.

## Grade distribution: counts, percentages and detail variants

YourGradesChart takes ordinary Grades for the selected semester. It stringifies each grade, removes one plus and one minus, and accepts a base key1–6. This is slightly broader than the strict whitelist used by trend: its input path performs String conversion. It counts the resulting base grade for the six-bar chart, and separately counts exact original grade strings for its detail list.

For filtered records G with N>0:

```text
baseCount[k] = number of selected grade records whose stripped base is k
basePercent[k] = 100 * baseCount[k] / N
detailPercent[exactGrade] = 100 * exactCount[exactGrade] / N
```

Plus/minus do not contribute fractions to histogram counts. Synthetic`['5+','5','4-','np']` yields N3, grade5count2→66.6667%,grade4count1→33.3333%; detail rows`5+`,`5`,`4-` each33.3333%. This is a distribution of assessment **records**, not percentage of school subjects, not average score and not count of pupils. The GUI formats percentages to2decimal places; retain full precision until display.

Detail seed includes ordinary1–6 plus1+,2±,3±,4±,5±,6-, but omits1-and6+. The chart can accept those omitted variants after base stripping, whereas incrementing an absent detail key yields NaN. Treat this as an original edge-case defect; a new implementation should generate detail keys from accepted inputs rather than reproduce the invalid arithmetic.

Date options are current week,current month,current period. Week/month start uses Moment `startOf('week'/'month')`, with interval **start-inclusive through now-inclusive**, tested against grade Date. Period option relies on prior semester scope and adds no date bounds. It is not a rolling7days or30days filter. Local week start is locale-sensitive; verify Monday/Sunday explicitly instead of assuming ISO behavior.

## Trend: per-bucket bar and cumulative line

GradeTrendChart selects subject containers, flattens their Grades, then applies the exact string whitelist. Weekly grouping uses `new Date(g.Date).getWeek()`; monthly grouping uses `getMonth()` (zero-based). It then walks the emitted bucket sequence in order:

1. Bar = arithmetic mean of eligible records in that bucket.
2. Cumulative line = arithmetic mean of all records in this and earlier emitted buckets.
3. Empty bucket emits`'N/A'`bar and carries the previous cumulative line; before any data the line is`'N/A'`.

This cumulative line is not a statistical regression, moving average, prediction or slope fit. A better current bar need not immediately cause the line to exceed its old high. Synthetic weeks:week1grades2,4→bar3,line3;week2grade6→bar6,line4;week3empty→barN/A,line4;week4grade3→bar3,line3.75. Multiple selected subjects pool all individual records, so a heavily assessed subject contributes more than a subject with one mark. There is no equal-per-subject reweighting.

Bucket calendars are hardcoded by chart helper:period1September–January,period2February–June. Extended period1 helper option starts July, but normal chart uses nonextended months. Emission stops at today when applicable; if current month is not found in the helper's period array, monthly helper can return the entire array. Weekly ranges depend on current school-year start and locale week calculation. These are different from arbitrary school-specific semester boundaries.

Only week numbers/month numbers are grouping keys; year is not part of the key. Week labels are built with `moment().week(number)` in the current year, and weekly chart labels only every fourth week. The `Date.getWeek` extension was located in the shipped `vue-cal` dependency at source line6344: it takes the local calendar date, constructs a UTC date, moves to Thursday and calculates the ISO-style week number. It returns no week-year. The dependency initializes this prototype conditionally when Date exists and `Date.prototype.addDays` is absent (line6377); initialization order was not observed at runtime. This grouping must not be assumed equivalent to Moment's locale week labels. Boundary fixtures must cover December/January, week1/53, DST, historical academic years and June–September. Prefer explicit `(schoolYear, weekStartDate)` keys in a deliberate corrected design. Dependency hash and source-map location are in the evidence ledger.

## Absence counts: there is no attendance-percentage denominator here

AttendanceChart loads account attendance rows and type definitions, filters Semester, then subject/date selection. It maps custom TypeId through StandardTypeId when the type definition's Standard is exact string`'false'`. The underlying attendance builder also normalizes and suppresses present-type100 rows. The chart counts only:

| Standard TypeId | Chart count |
|---|---|
|1|Unexcused absence|
|2|Lateness|
|3|Excused absence|
|4|Exemption|

Counts are numbers of matching attendance records;0categories are hidden. Synthetic1,1,2,3,4,custom→3 gives unexcused2,late1,excused2,exempted1. It does not become a percentage merely because displayed in a chart. Event-feed attendance summaries use the same four counts for the current semester.

No denominator of all planned/realized lessons or recorded present+absent states is computed by this chart. It cannot establish school attendance percentage, because ordinary attendance presentation can omit presence100. Do not divide absences by list length, count planned cancelled lessons, count both custom and normalized records, or treat missing data as presence. If Siberia adds a percentage, specify separate eligibility, denominator source, cancelled/unrecorded/exempted/late rules, school timezone and date scope; verify against a known school's report. For example2absences alone does not establish80% attendance—there may be10,20or an unknown number of eligible lessons.

## Unpreparedness, recent grades and potential

UnpreparednessCard counts exact lowercase`'np'` records in each provided subject's Grades, descending by count, initially showing3subjects with expand. It does not match`NP`,`np.`,`nb` or the category name. It does not implement an allowance/remaining quota: shield count is number already reported, not number still permitted. Synthetic subjectAgradesnp,np,5→count2;subjectBNP,4→count0. Upstream semester/deletion filtering is essential.

LastGradesCard separately filters Semester, groups by Date and orders date keys descending; it accepts ordinary Grades and BehaviourGradesPoints from containers. It is a recent activity display, not identical to whitelist-only analytics. YourPotentialCard averages standard whitelisted grades per selected semester, removes0/no-data averages, sorts descending and initially renders4subjects. This is a ranking of **this user's subjects**, not a class ranking or aptitude prediction.

## School-reported subject and overall averages

Subject routes use Synergia bearer context:

```text
GET /Grades/Averages                  -> response.data.Averages
GET /Grades/Averages?subject={id}     -> Averages or [Average]
GET /Grades/Averages/{id}             -> Average
```

The subject filter helper returns undefined if only disabled status is supplied, deliberately distinguishing school-disabled averages from numeric0. Builder maps server Semester1,Semester2,FullYear into local Averages with Period1,2,and full-year flag. Do not recreate them by the unweighted goal formula when disabled or missing.

Overall assessment average flow:

1. Start with accountIdentifier; if absent GET`/Auth/TokenInfo` and read`UserIdentifier`.
2. If role is neither string`student`nor numeric8, GET`/Auth/UserInfo/{parentId}`, read`IdentifierOfStudentAssignedWithUser`.
3. POST`/Auth/Grades/StandardWithAverages/Students/{studentId}` with JSON`{"limit":1}`.
4. Read`response.data.data.averages.total`. Display keys`firstSemesterFinalGrades`,`secondSemesterFinalGrades`,`annualFinalGrades` in the corresponding period.

`limit:1` minimizes returned rows because only totals are consumed; it does not mean calculate a total from one grade. The server's detailed formula, included subjects and weighting cannot be reconstructed from the consumer alone. UI shows first-semester final mean in period1; period2shows second-semester final and annual final means. Truthiness hides missing/0values in that UI. Cache is keyed by login; a future integration should also invalidate on school year, connected account/child and relevant grade updates. Local overall average from subject estimates is not an equivalent substitute.

## Goal persistence and monthly summaries

Goal values are stored through Portal `/mobile-addons/goal` GET/POST, PUT/DELETE`/{id}`. Creating/editing passes subject refId string,name,target goal,type`average`,period string,synergiaAccountId and properties.lastAverage. The goal's current value is recalculated locally. Store may write back properties.lastAverage and lastTrend when computed value changes; even viewing/update orchestration can therefore involve mutations. Exact regress constant in helper is misspelled`REFRESS`; retain compatibility if consuming that field, without exposing the typo as product text.

Monthly summaries are not fetched as precomputed grade statistics. Portal GET`/push/notifications/{bindingId}` provides trigger metadata: `data.librus_type` equals`monthly_grades_summary`or`monthly_trends_summary`, plus summary_start_date,summary_end_date,timeline_event_uuid. The app loads grades for eligible accounts and generates datasets itself. Distribution summary uses `[start,end)` on Date. Weekly trend summary groups accumulated grades by week numbers then emits weeks from requested start through end; its grouping does not itself filter every grade to exact start/end before week lookup. A week crossing a boundary can therefore include outside-range records. Do not erase that difference in a purported exact clone.

The store deduplicates notification IDs, caps old summary retrieval at500rows, and may delete the binding's notification history after generation when no accounts are broken. This delete is an effectful acknowledgement, not a read prerequisite. Do not invoke official push registration/history deletion merely to offer local stats. Siberia's Firebase project cannot be assumed to receive vendor-issued topics/tokens. A notification-triggered local summary can be implemented independently with a clearly stated source/schedule after authorization.

## Future-agent tasks and acceptance

1. **ST-01 DTO inputs.** Preserve account/period, Date and AddDate, exact grade string, family, deleted state, category metadata, resit links and raw attendance type refs. Add immutable stats snapshots with explicit freshness and methodology. Reuse current Siberia provider scope rather than creating a second global login context.
2. **ST-02 pure local calculators.** Implement histogram, unweighted plus/minus mean, bucket/cumulative trend, np counts and personal-subject ranking separately. Use the synthetic cases in stats-evidence. Freeze time/timezone/locale in tests. Keep null/no-data separate from0.
3. **ST-03 school averages.** Add exact subject and student-total API readers with parent→student mapping, disabled handling, source label and scoped invalidation. Test unauthorized/disabled/missing total keys without replacing data with a local estimate.
4. **ST-04 date policy.** Decide exact compatibility versus corrected school-calendar behavior. Document changes to hardcoded months/week-number bugs; do not silently call a corrected result identical to original. Test academic-year transitions, dates added later than occurrence, empty buckets, duplicate resits, types string/number and historical year.
5. **ST-05 UI.** Show filters, totals, source/methodology and stale state; preserve independent account selections. Do not label subject ranking as class comparison or call absence counts attendance percent. Expand works for3np/4potential default rows without losing the full data set.
6. **ST-06 external features.** Keep goal CRUD, summary push history and any class/cohort comparison separately gated until contract/authorization/current server acceptance is verified. Read-only stats implementation need not wait for those writes.

Acceptance: the worked arithmetic matches to full precision before display rounding; school-reported4.70and personal4.083333can coexist without overwrite; a failed attendance fetch produces stale/error, not0absence; zero eligible grades never divide by0; changing pupil or year cannot publish another context's chart. Static derivation and synthetic tests remain distinct from runtime server verification.
