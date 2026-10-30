# Worked wire examples and code fragments

All values are synthetic. Hosts under `.invalid` are intentionally unusable. These examples describe serialization and acceptance tests; they are not an implemented client, recorded traffic or permission to send school-account actions. See [models/synthetic-cases.json](models/synthetic-cases.json) for32 additional module cases and [WORKFLOWS](models/WORKFLOWS.md) for exact caller rules.

## URI join and token ownership

Original Axios configuration keeps the `/3.0` prefix for its `/Messages` route. A literal `Uri.resolve('/Messages')` against `https://api.example.invalid/3.0` would instead discard that prefix. Use a tested join policy such as this illustrative Dart fragment:

```dart
// Illustration only: restrict callers to documented relative API routes.
Uri apiRoute(Uri base, String route) {
  final left = base.toString().replaceFirst(RegExp(r'/+$'), '');
  final right = route.replaceFirst(RegExp(r'^/+'), '');
  return Uri.parse('$left/$right');
}
```

This fragment does not authorize arbitrary absolute URLs, validate origins, encode path parameters, or safely construct user-entered query data. A real adapter should reject unexpected absolute routes and build path/query components explicitly. For a fixture, joining base`https://academic.example.invalid/3.0` with `/Messages` must produce `/3.0/Messages`. The same route on the Portal API is a different service contract and must not accidentally reuse a Synergia token.

## Multipart OAuth exchange

Illustrative field specification; let the HTTP library generate boundary bytes:

```text
POST https://portal.example.invalid/oauth2/access_token
multipart:
  grant_type = authorization_code
  client_id = SYNTHETIC_REGISTERED_CLIENT
  redirect_uri = app://librus
  code = SYNTHETIC_ONE_TIME_CODE
```

Refresh changes the grant and fields to `grant_type=refresh_token`, same client ID, `refresh_token=SYNTHETIC_REFRESH`. It omits code/redirect fields in that recovered refresh path. Tests should assert these exact field sets and absence of the wrong service's token. A simultaneous refresh test needs two linked pupil profiles under one Portal owner and an unrelated owner.

## Synergia folder pagination

First synthetic inbox-family request:

```http
GET /3.0/Messages?alternativeBody=true&changeNewLine=1&afterId=1&limit=300&getAllTypes=1&page=1 HTTP/1.1
Host: academic.example.invalid
Accept: application/json
Authorization: Bearer SYNTHETIC_SYNERGIA_TOKEN
```

If300 items are returned, request page2 with the same filter/afterId. If page2 has2items, stop after302 accumulated items. Next incremental sync can use the stored highest ID for that account/folder. An empty delta does not erase prior mail and must not index array element0. Sent uses exact `inSended` spelling; trash adds the appropriate caller's `inTrash` filter. GO uses a different100limit/offset/total protocol.

## Compose versus reply

New Synergia compose body, serialized exactly once by the helper:

```json
{"subject":"Synthetic message","body":"First line\nSecond line","receivers":["101","102"]}
```

Reply body:

```json
{"subject":"Re: Synthetic message","body":"Synthetic response","originalMessageId":"9001"}
```

Assert that reply omits `receivers`, and that plain body text is not pre-JSON-encoded. Response `Subject`/`Body` are JSON-parsed by the original builder; response casing and representation do not define send casing. Content-Type emitted by the Synergia JSON-string helper remains an adapter-verification item described in the transport guide.

For pinning, use PUT `/Messages/9001` with `{ "action":"pin" }`; unpin changes the action. Delete uses the same PUT route with `{ "action":"delete" }`. Do not replay a timed-out create/delete just because no response arrived. Distinguish created-but-refresh-failed from not created.

## Homework business acknowledgement

```text
POST https://academic.example.invalid/3.0/HomeWorkAssignments/MarkAsDone
body: {"homework":"7001"}
```

The business response must satisfy the operation's `Status==='OK'` consumer before the server-confirmed local state changes. HTTP200 with `Status:"ERROR"` is a failure. Local `IsNew=false` has no such server request. Siberia's current local done toggle should remain distinguishable from confirmed remote done.

Upload fixture:

```text
POST https://academic.example.invalid/3.0/HomeWorkAssignments/AnswerAttachment/7001
multipart part: attachedFile
filename: practice-example.pdf
bytes: synthetic fixture bytes
sendFile: true  (original helper flag; not a wire field)
```

Assert no JSON wrapper around the bytes, and no literal `sendFile` form field. Keep student role, due date, answer count, `SendFilePossible`, file restrictions and device policy as separate gates. If upload succeeds but the subsequent detail fetch fails, record confirmed upload with stale detail instead of creating a second upload automatically.

## Justification lesson numbers

```json
{"messageFromParent":"Synthetic absence reason","lessons":[1,2],"dateFrom":"2026-11-02","dateTo":"2026-11-02","sendNotify":false}
```

This illustrates selected lesson numbers; it must not be populated with lesson IDs such as900012. Whole-day selection may use an empty lessons list according to the compose caller. Compute sendNotify using the exact date/user flag rule in workflows. No timezone suffix belongs on these date-only strings. A confirmed proposal still is not proof that the teacher changed official attendance.

## GO compose and read

GO POST `/messages/outbox` uses another body family:

```json
{"subject":"Synthetic subject","content":"First line<br>Second line","recipients":[{"id":"example-recipient","type":"example-type"}]}
```

`example-type` is deliberately not a claimed valid server enum; use a type returned by recipient discovery. The original caller HTML-escapes content and converts newlines. Do not send Synergia `body`/`receivers` keys. Mark read is a separate PATCH `/messages/inbox/{id}/read`. Attachment URL acquisition is POST and the returned signed URL must not be logged or treated as a universal cookie destination.

## Crash-safe change acknowledgement

Illustrative orchestration, not production code:

```text
changes = poll(selectedAccount.pushDevice)
for bounded batch of changes:
    fetch required changed entities and dependencies
    persist scoped entities and processed-change identities atomically
    acknowledge only the committed change IDs
```

The original dispatcher batches change acknowledgements in groups of30. A future retry should reconcile already-applied entities without duplicate notifications. If persistence fails, do not acknowledge. If acknowledgement fails after persistence, retain the deduplication record and retry that acknowledgement, not a user mutation represented by the change.

## Browser handoff and payment outcome

Opening meal ordering/payment or GO payments may yield an autologin URL and return to the app. A `back-to-app` command or browser close triggers a refresh, not `paid=true`. An invoice can require asynchronous generation/status polling followed by a signed download. Fixtures should cover cancel, incomplete, confirmed, refresh timeout and expired URL independently.
