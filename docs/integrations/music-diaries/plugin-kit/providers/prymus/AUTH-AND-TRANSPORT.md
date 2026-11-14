# Prymus authentication, signing and transport

## Service origin and client identity

Observed in `network/SchoolApi.java`: production base `https://cpdklaser.zeto.bialystok.pl/api/`; alternate IP base `https://91.231.242.86/api/`; test base `https://cpdklaser-test.zeto.bialystok.pl/api/`. `API_VERSION=16`. These are packaged configuration facts, not a claim that every origin is currently reachable. `TestApi.java` points to JSONPlaceholder and is not a school-data service.

`SchoolApi` builds Retrofit with a lenient Gson converter and90second read/connect timeouts. Its original OkHttp factory accepts all certificates and hostnames. This is observed original behavior that a Siberia implementation should **not reproduce**: use normal certificate/hostname verification, and do not silently retry to the IP address with a permissive TLS policy. The source's IP fallback is triggered on an exception in the snapshot request, not a documented redirect contract or proof the IP can be used with standard TLS validation.

All17 school-service declarations and their exact form/query fields are in [operations.json](operations.json). The snapshot and weather are GETs; all other service declarations are form POST. Diagnostic `API_CONNECTING_TO` strings often look like query URLs even for POST routes. Derive method/encoding from Retrofit annotations and actual caller, never from that log string. GET snapshot also sends device/FCM data and can participate in device registration, so it is not guaranteed effect-free.

## Enrollment and ownership

The primary credential is a student enrollment token. Manual UI trims entered text and checks length10. Camera/gallery barcode input supplies the decoded display value; there is no recovered username/password grant. Do not apply the legacy MobiReg MD5 transform or a Librus OAuth flow.

`AddStudentFragmentVM` rejects an already stored token; a different token with an existing external pupil identity updates that student instead of creating an unrelated global identity. The source checks `students.size()>6` before adding another entry, so the exact branch is not a universal server guarantee of six accounts. Discovery success requires a non-null response with `ExternalId` after system-message handling. It stores pupil identity, token, license and the returned modules. System-message code1 maps to version/update handling; device-limit messages expose a user-directed reset action. A failed network load is distinct from an invalid token.

Store the enrollment token as secret material under `(provider, legitimate service authority, pupil ExternalId / enrollment owner)`. Preserve school year and term as data scope. A parent mode can apply to linked profiles, but its parent identity/activation is separate from the selected student's token. Fields named `UserId`, `ExternalId`, local Room `id`, parent ID and token are different. The token is not a pupil ID to display or use as a globally durable record key.

The source stores much account state in local Room tables and logs credential-bearing URLs/error request models. A future implementation should keep credentials in existing Siberia secure owner storage, redact token/securityToken/FCM/broker credentials from logs, and scope snapshots independently. A local delete or profile switch does not establish remote token revocation.

## Hourly securityToken algorithm

Corroborated by REA `inspect_android_method` evidence `ev_eea15a9379c419adb79a88ff8c8ab0bf1bec93d0ff6b84492997729ef20bf7b9`, `VariousMethods.getHashedKey` and `bytesToHex`.

Let H(x) be lowercase zero-padded SHA256 hex of UTF8 bytes. Let P be the application prefix literal inside that method. Let hour be current time formatted **`yyyy-MM-dd HH` in fixed `GMT+01:00`**. Then:

```text
left = H(P + hour)
right = H(enrollmentToken)
securityToken = H(left + right)
```

The last digest consumes the UTF8 hexadecimal strings concatenated together, not the64 raw digest bytes. No separators are added beyond the literal content of P and the date formatter's space. `bytesToHex` pads each byte to two lower-case hexadecimal characters. Recompute for a new request/retry across an hour boundary; it is not a stored long-lived refresh token.

Fixed GMT+01:00 is significant in Polish summer time: a device in Warsaw may show one hour later than the signing formatter. Do not use `Europe/Warsaw` with DST for this algorithm. For example,2026-07-01T12:34Z signs hour`2026-07-01 13`, while Warsaw wall time is14:34. A device clock error can therefore invalidate requests. Server clock tolerance and accepted boundary grace are not established by static code.

### Required local configuration retrieval

The shared application prefix is deliberately omitted from this public handoff. This is an explicit required configuration input, not an unresolved algorithm. To retrieve it for an authorized independent implementation:

1. Verify the supplied APK's SHA256 against the identity above.
2. In local JADX output open `pl/bialystok/zeto/prymus/VariousMethods.java`, method `getHashedKey` (the provided analysis has it at source line659; the prefix expression is line666). Alternatively use REA/JADX to inspect that exact method.
3. Extract only the string literal concatenated immediately before the formatted hour in the innermost SHA256 input. Preserve every character; do not derive it from the token or URLs.
4. Supply it through a reviewed local configuration/secrets mechanism. Do not print it, credentials or derived live request tokens in diagnostics or commit them.

The synthetic vectors use an invented prefix and token, so they verify encoding/hour arithmetic without revealing the original prefix or proving a server request works. Source hashes and exact anchors in evidence.json bind the retrieval location to this build.

## Snapshot request

```text
GET {base}pobierzDaneUcznia
query:
  token = enrolled student token
  securityToken = hourly derived value
  mobileId = original Android Settings.Secure android_id
  ver = 1.2.68
  fcm_token = current push token when available
  apiVersion = 16
```

Retrofit query encoding must escape `+`, `&`, `=` and Unicode. Null query values may be omitted by Retrofit; verify absence versus empty string explicitly for a third-party client. The inspected native app uses `android_id`; how Siberia supplies a stable legitimate installation identity through its SDK is a host integration decision that must be tested. Do not synthesize a new device ID on every sync or assume the official push token works for another app.

The body is a typed `ApiResponse` object, with optional `system_message`, account fields and module arrays. It is not an OAuth token response and has no universal `success/data` wrapper. A non-null HTTP body is not sufficient for valid enrollment if it contains only a system message or lacks ExternalId.

## Parent mode and registration

`trybRodzica` is form POST with token, derived securityToken, mobileId, activationCode, integer type and apiVersion16. Type is a caller-selected action; the exact response and activation/revocation behavior are in the protocol guide. `ParentMode` state has enabled flag and parent ID used by message/justification UI. A premium flag or parent-mode checkbox is not server authorization by itself.

FCM uses `ustawFcmToken` form mobileId/fcm_token/apiVersion, and `aktualizujTokenyUrzadzenia` associates JSON-serialized token lists with securityToken/mobileId/parent/premium values. These mutate registration state. Do not send duplicate registrations as harmless reads. `wyczyscUrzadzenia2` resets device state and should remain an explicit user action with a typed outcome, not an automatic failed-login recovery step.

## Messaging transport separation

School HTTP routes send messages/receipts. Live receive uses MQTT broker `ssl://dziennik-broker.zeto.bialystok.pl:8883`, returned `ChatSettings.BrokerLogin` and `BrokerPassword`, random client ID and TLS CA resource. The client subscribes to `{brokerLogin}/{topicUuid}` at QoS1. Message callbacks parse topic levels and message JSON into scoped local models. HTTP signing credentials are not the MQTT password.

No available host plugin API should be assumed to permit raw MQTT sockets. A plugin can document snapshot-based inbox refresh while a separate reviewed host capability is needed for live MQTT. Do not advertise realtime delivery merely because the official app contains an MQTT dependency.

## Actual Siberia SDK constraints

The current host integration review reports a real sandboxed diary SDK: `dart_eval`, package:diary source plus the SDK protocol,45second execution budget,64requests and1MiB response cap; HTTP response bodies are UTF8 and binary/multipart are not exposed. Check the root's current-source integration plan for the exact baseline and interfaces.

Consequences: do not assume `package:crypto`, raw sockets, file access, arbitrary Android identifiers or image encoding is available. The hourly SHA256 requires a compatible pure-Dart implementation within the sandbox or an explicitly reviewed host crypto bridge. A large all-module snapshot may exceed the response cap; repeated per-module fetches multiply bandwidth/calls. A shared batch/snapshot orchestration capability may be needed. Do not stash the entire snapshot or broker secrets in ordinary auth-state JSON as a cache workaround. No such host change is implemented here.
