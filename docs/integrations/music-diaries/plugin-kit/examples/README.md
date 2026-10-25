# Worked integration exercises

All values below are invented. These exercises are specifications for future tests and agent work, not executed integrations. Provider directories contain the detailed request vectors and decoder shapes.

## One parent, two pupils, one rotating session

Input: MobiReg parent account A at `mobireg.pl/example-school`, pupils42and43. Login produces tokenT1. Discovery selects pupil42. Start `marks` for42, then switch to43 while the request is in flight. Start `marks` for43. Receive43 first and42 second.

Expected: screen shows43; each response is stored only under its own data scope. Credentials remain under one account owner. Switching back to42 may use its own cached result. A refresh rotates T1→T2 once for this owner even when both child syncs request recovery. An unrelated account B must not wait on or receive account A's token.

Useful future fixture assertion pseudocode:

```text
assert activeScope.pupil == "43"
assert visibleMarks == responseFor43
assert cache[scope42].marks == responseFor42
assert secureStore[ownerA].token == T2
assert secureStore[ownerB].token != T2
```

## Partial mail send

Input: create a message with two attachments. Server confirms message ID901. First upload succeeds; second times out after bytes were sent.

Expected: outcome records message901 as created, attachment1 confirmed, attachment2 uncertain. The UI offers reconciliation/retry for attachment2. It does not submit the message body again. On folder refresh, deduplicate901 by provider-scoped identity. Logs contain operation IDs and statuses, not subject/body/tokens.

## Fryderyk DTO type preservation

Input: a grade object has `numeric_value:"4.5"`, a descriptive name and null optional comment. The recovered Android constructor requires the numeric value as a String.

Expected: source DTO preserves the string. Normalization may parse a decimal for a Siberia calculation in a separate optional field; it must preserve the original representation and descriptive text. A JSON number substituted for the string is a deliberately distinct invalid/type-compatibility fixture until a proven decoder branch allows it.

## Fresh empty versus failed module

Initial cache: grades and homework from yesterday. New grades request succeeds with zero records; homework request fails with expired module session.

Expected: grades become an empty successful collection with new freshness metadata. Homework remains yesterday's data marked stale with a session error. Whole-account sync is partial, not globally successful and not a destructive empty replacement.

## Exact form override

Input: JWT `jwt-example`, FCM token `push+token/with=chars`, no pupil requirement. Build `register-fcm` by creating shared gateway fields, then merging extras.

Expected decoded form map: `view=register-fcm`, `format=json`, `token=push+token/with=chars`, `JWTToken=jwt-example`; no invented pupil. The literal plus in the token must round-trip as plus, not space. Assert parsed field equality rather than comparing a guessed form-field order.

## Local date and sync cursor

Input: school-local2026-10-25 around DST; legacy server cursor uses an ISO-like response time while request formatting requires a space. A transaction fails halfway through import.

Expected: retain original server cursor data, serialize using the recovered request formatter, and never advance the durable cursor on a failed import. Date-only requests keep the intended school date without a UTC conversion. The precise live school timezone remains a runtime gate.

## Future implementation agent prompt

> Read the integration documentation README, provider SPEC, evidence vocabulary, and Siberia source plan. Work on only the assigned transport/module. Recheck source anchors against the current branch. Implement provider DTOs without discarding source fields, exact request serialization, owner/scope isolation and module-specific errors. Use the synthetic vectors as synthetic fixtures. Do not claim live verification. Leave role/server unknowns explicitly gated. Report changed files, meaningful checks, unsupported cases and any required controlled-account verification.

Split implementation work according to the task dependency order in the Siberia runbook. A successful feature means the visible UI, storage, background behavior and error handling work together; an endpoint wrapper by itself is incomplete.
