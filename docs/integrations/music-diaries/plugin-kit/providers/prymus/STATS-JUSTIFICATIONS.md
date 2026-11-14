# Priority: Prymus statistics and electronic justifications

These contracts belong to Prymus1.2.68. They differ materially from the earlier Librus guide. All observations are static; no class data was fetched and no absence justification sent. Source identities and anchors are in evidence.json; synthetic values below are invented.

## Statistics that actually exist

Prymus returns three complementary data families in the full `pobierzDaneUcznia` snapshot:

1. `Marks`, `MarkAverage`, `MarkFinal`: pupil marks and school-supplied average/final strings.
2. `MarksResults`: aggregate counts used by the selected mark's **Na tle klasy** chart. The UI meaning is corroborated by `MarksViewPagerAdapter.classMarksChartButton` and decoded string resource `classMarksChart_button`=`Na tle klasy`.
3. `AttendanceStatistics`: school-provided month/term/year attendance percentages, as Strings. These are not recomputed from an absence-only list.

There is no separate recovered “stats endpoint” in the17 school HTTP declarations. The broad snapshot supplies the inputs; several charts calculate their presentation locally. Keep transport provenance and calculation method explicit.

## Class comparison schema and grouping

`MarkResults` consumes:

```json
{
  "MarkExternalId": 701,
  "MarkAreaId": "SYNTHETIC-ASSESSMENT-AREA",
  "StudentId": "SYNTHETIC-PUPIL",
  "AllStudentMarks": [
    {"Mark":"3","Count":2},
    {"Mark":"4+","Count":5},
    {"Mark":"5","Count":3}
  ]
}
```

The `StudentId` can be assigned by importer context. Local `id` is not the assessment ID. `DetailsMarkVM` loads pupil+subject+school year+term marks and joins each mark to `MarkResults` by **student ID and MarkExternalId**. The Room query returns the first match, so a future model should additionally retain assessment-area/year identity to avoid relying on globally unique IDs.

`initMarkStatsChartData` reads the first character of each non-null Mark string, parses it to an integer, accepts1–6 and adds Count into that grade's bucket. Thus4+ and4- both contribute to bucket4; the histogram does not weight plus/minus fractions. The six bars are **counts**, with the current pupil's mark bucket highlighted. It is a class-comparison aggregate for the selected mark/assessment context, not a list of classmates, a percentile, a named ranking or proof of exactly which cohort the server included. Do not request other pupils' IDs to reconstruct it.

The displayed class mean for this chart is `sum(gradeBucket * count) / sum(count)`. For the example above, `(3*2 + 4*5 + 5*3)/10 = 4.10`. This deliberately loses the+modifier. A normalized percentage view could show20%,50%,30%, but that would be a Siberia presentation derived from counts, not an observed server percentage field. A zero count sum produces invalid division in the old helper; a new chart should show no-data. Negative counts, empty mark strings and malformed buckets need typed rejection/unknown handling rather than chart crashes.

The pupil's own histogram similarly groups by the first character. Its description can use a supplied `MarkAverage.Mark` when present; otherwise the helper computes the bucket mean. Do not label the local fallback as a school-reported weighted average.

## School-supplied pupil/class averages

`MarkAverage.Mark` is a String. The local DAO selects `Type='S'` for term and `Type='R'` for year, `ClassMark='0'` for pupil and`'1'` for class. SchoolSubject-null records supply overall totals; subject filters supply subject totals. Keep pupil,year,term,subject and class/pupil scope in the cache key. Current values can be decimal strings or null; do not silently turn missing0 into a real score.

The decoded UI describes a yearly average as weighted, but the backend's exact inclusion/rounding policy is not reconstructed by the display reader. Preserve source values and their type/scope instead of deriving them from the chart histogram. A school average, a histogram mean and a local cumulative weighted average can all be different while using the same marks.

## Trend and cumulative weighted curve

Marks are fetched by pupil+subject+year+term in `ReceivedDate ASC, ExternalId ASC` order. The x-axis is the sequential index of accepted marks, **not elapsed days**. The local parser behaves as follows:

* One-character mark: parse integer.
* Two-character mark: parse first character; add0.5 if second is+, otherwise subtract0.25.
* Other length/unparseable input:0, and a zero value is omitted by chart builders.

This source implementation is permissive: it does not generally validate grade1–6 or require the second character to be a minus. A future implementation should explicitly choose compatible parsing versus a corrected strict grading policy. Do not silently accept`4?`as a meaningful3.75 or`10`as0.75 simply because the original helper would.

`prepareChartDataSet` creates `(index,value)` points. `findTrendLine` performs **ordinary least-squares regression**, unweighted, over those points:

```text
slope = (n*sum(x*y) - sum(x)*sum(y)) / (n*sum(x*x) - sum(x)^2)
offset = (sum(y) - slope*sum(x)) / n
line(x) = slope*x + offset
```

This is not the cumulative average line documented for Librus. For values2,4,3 at indices0,1,2 the slope is0.5 and offset2.5, yielding fitted2.5,3.0,3.5. The old helper returns null for exactly zero slope; insufficient/invalid points can produce NaN. The detail UI requires at least3 raw chart points before showing its trend. Guard finite values, constant series and small samples in a future adapter.

`prepareChartDataSetByAvg` separately builds cumulative **weighted** average: maintain sum(value*Weight) and sum(Weight), append their quotient for each accepted grade. With5+(weight2),4-(weight1),3(weight1), points are5.5,4.9166667,4.4375. This differs from the regression line and from the server's MarkAverage. Zero/negative weights need explicit handling; do not publish division-by-zero as a0average.

Chart eligibility is also UI-gated: early-school/descriptive marks with text length>2 hide charts, and the original premium condition combines maximum stored student license and app-version mode. A sibling's local maximum license is not proof of another pupil's server entitlement. Preserve feature gates without copying commercial identity/receipt behavior into independent calculations.

## Attendance percentages and counts

`AttendanceStatistic` has nullable Integer ExternalId plus String fields `PercentageMonthPresence`,`PercentageTermPresence`,`PercentageSchoolYearPresence`,`StudentId`,`SchoolYear`,`TermShortcut`. `ViewAttendanceVM` selects the current pupil's actual year and term. `ViewAttendanceFragment` parses each String using BigDecimal and rounds **HALF_UP to one decimal** for display. It uses0 when a field is null; a new UI should instead distinguish missing/unavailable from a genuine0% result.

Example: server string`95.25` displays95.3; preserve the original string and optional decimal value in the DTO. A value containing `%` or comma is not proven accepted by the BigDecimal constructor; do not guess locale normalization. The server's denominator/exemptions/late policy is not inferable from these fields alone.

Separate local count queries classify `LatenessStatus=1` as late, `ExcusedAbsenceStatus=1` and LatenessStatus0 as excused absence, and both flags0 as unexcused absence. Source numeric enum30–35 in AttendanceType is UI routing, not the wire meaning of these byte flags. Unknown flag values remain raw. Do not recalculate the supplied attendance percentage from only those three absence/late counts.

## Electronic absence justification: exact identity and payload

The detail screen joins timetable rows and attendance on a selected absence date, allows selection of concrete absence rows and submits **attendance ExternalIds**. In particular, do not reuse Librus's `lessons:[lessonNumbers]` shape.

Observed UI gate: premium access, enabled ParentMode, selected absence mode not already excused. The check uses the old maximum-license/app-mode logic; school authorization still must be verified. The checkbox adapter only collects rows whose external ID is nonzero. The UI refuses an empty selection before opening the reason dialog. The VM itself sorts the list and trims the trailing comma from concatenated time intervals, so a programmatic empty list would fail; enforce the invariant at the request boundary too.

Outer form POST to `wyslijDane`:

```text
token = SYNTHETIC10
securityToken = <derived hourly hash>
type = 101
json = <JSON string below, form encoded once>
```

Inner synthetic JSON:

```json
{
  "id_ucznia":"SYNTHETIC-CHAT-USER-ID",
  "data_wyslania":"13.11.2026 10:15",
  "data_nb":"12-11-2026 (Czwartek)",
  "godz_lekc":"08:00-08:45, 08:55-09:40",
  "frekw_id":"[1101,1102]",
  "uspr":"Synthetic absence reason"
}
```

Field rules:

| Key | Exact producer |
|---|---|
|`id_ucznia`|`student.getChatId()` from snapshot UserId; **not** ApiResponse.ExternalId or local DB id |
|`data_wyslania`|`VariousMethods.getDateAndTimeNow`: local`dd.MM.yyyy HH:mm` |
|`data_nb`|absence ISO-date input reformatted`dd-MM-yyyy` plus Polish weekday in parentheses; getDayNameFromDate returns capitalized Polish weekday names |
|`godz_lekc`|Sorted selected rows' `timeFrom-timeTo`, joined with comma+space, trailing delimiter removed |
|`frekw_id`|Gson string of selected integer ExternalIds, serialized **as a string within the outer JSON object** |
|`uspr`|Reason from TextAreaDialog; no extra trim/minimum/nonempty rule was established in its send callback |

None of these fields is an ISO timestamp or UTC instant. The signing timezone is a separate fixedGMT+01 rule; the composer formatter uses device-local time. An implementation needs both formatters and controlled date fixtures. Preserve selected student ownership through every await.

There is no justification attachment field in this DTO and no dedicated justification upload method in the17 routes. Generic TextAreaDialog has attachment capabilities for other contexts, but that does not establish a justification attachment contract. Do not attach mail/task files through an invented justification route. No separate edit/delete/cancel/teacher-accept endpoint was recovered in this selected call chain.

## Local insertion, result semantics and uncertain state

The original VM inserts a `JustifiedAttendances` local record **before** the network POST. It stores the JSON ID list, send timestamp, reason, pupil and absence date. The detail screen later displays `* - wysłano prośbę...` markers from this local table. These markers are not proof that the backend accepted the request or that a teacher excused it.

For the HTTP response the VM requires successful status, reads raw response body and tests `.contains("true")`. It posts success/failure to an observer; an exception logs but does not uniformly post a failure observer. A future client should model at least draft→sending→confirmed/uncertain/failed. Persist pending metadata if needed, then mark confirmed only under a verified success contract. Do not copy the preinserted record into official attendance as accepted.

If a request reached the server but its response was lost, retain uncertain outcome and reconcile snapshot/known records before retry. There is no recovered idempotency key. A literal substring check could accept an unrelated message containing “true”; current server response shape needs a controlled fixture. A follow-up refresh should update official ExcusedAbsenceStatus independently. No source path here authorizes locally rewriting every chosen absence to excused.

## Focused next-agent tasks

1. Preserve MarkResults,MarkAverage and AttendanceStatistics in provider DTOs with source IDs/year/term. Expose class aggregate counts separately from local pupil grade distributions.
2. Add pure calculators for histogram mean, OLS line and cumulative weighted average with named methodology. Verify the synthetic examples and empty/constant/invalid/zero-weight cases.
3. Implement a read-only attendance/justification detail that can display server percentages and locally pending/uncertain request markers without conflating them.
4. Implement type101 only after hourly signing, parent-mode identity and host HTTP budgets are supported. Assert the nested string encoding and chat ID/attendance-ID distinction.
5. Add controlled runtime fixtures for module permission, date formats, same-day selection, device clock/hour boundary, raw response success and duplicate handling. Keep attachments/teacher decision APIs unavailable until separately recovered.

For the current SDK, cryptographic signing and broad-snapshot limits are host prerequisites. Model tables and examples establish implementation inputs; they do not establish current third-party service acceptance.
