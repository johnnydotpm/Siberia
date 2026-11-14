# Acceptance scenarios for future implementation

These are synthetic test specifications, not tests executed against real diaries. Provider-specific vectors supply exact method/body/value expectations. Use the recorded main baseline and source drift checks before adding application tests.

| ID | Setup / trigger | Required result |
|---|---|---|
| NP-01 | New provider manifest has same ID as bundled Librus | Registration rejected; bundled default remains available offline |
| NP-02 | Download bytes differ from pinned size/hash | Installation fails; previous installed release remains intact; no login data sent to unverified artifact |
| NP-03 | Device offline with an existing owner/profile | Load pinned local release and cache without requiring catalog fetch |
| NP-04 | Two pupils at two schools share visible names/remote numeric IDs | Distinct provider/school/profile identity; no cache/message/widget collision |
| NP-05 | Add the same legitimate enrollment again | Stable intended owner/profile, not duplicate notification slot |
| NP-06 | One sibling removed while another remains | Remaining sibling retains valid shared credentials; removed profile results cannot publish |
| NP-07 | Foreground and background invoke the same owner | Lease/fencing preserves one coherent credential state; no late obsolete save |
| NP-08 | Remove owner/logout during a slow request | Completion cannot resurrect credentials or publish another account's data |
| NP-09 | Login returns a new sync URL with path | Preserve endpoint path, validate legitimate exact origin; do not send a password to an unrelated authority |
| NP-10 | Server redirects token-bearing POST to another origin | No automatic redirect; require explicit verified policy before constructing any follow-up |
| NP-11 | Callback request JSON approaches1MiB | Budget uses UTF8 bytes and JSON overhead, not decoded file length or character count |
| NP-12 | Broad snapshot exceeds response budget or server is slower than host policy | Explicit bounded failure; stale data retained; no retry loop or silent budget escalation |
| NP-13 | Provider performs64requests then wants another | Terminates with a stable bounded error, not an incomplete result labeled complete |
| NP-14 | One module succeeds empty, another fails | Successful module becomes empty/fresh; failed module keeps previous data/stale error |
| NP-15 | Unknown attendance type or missing denominator | Preserve raw type/completeness and neutral state; no fabricated presence or percentage |
| NP-16 | Grade is final/proposed/not counted | Metadata survives; ordinary current-grade average does not include it |
| NP-17 | Provider generic calendar event repeats in two syncs | Covered-range replacement/deduplication prevents duplicates; not relabeled as exam solely to fit host |
| NP-18 | A mailbox page repeats nextCursor or returns no progress | Bounded protocol/partial result; no endless refresh |
| NP-19 | Message created but following detail refresh fails | Confirmed creation retained; retry GET/reconciliation rather than send again |
| NP-20 | Send/delete times out after transmission | Uncertain effect state; no blind credential-recovery replay |
| NP-21 | Message id/recipient belongs to another profile owner | Reject before network request; no local ID sent as raw server identity |
| NP-22 | Attachment metadata exists in provider result | Host explicitly exposes it or reports unsupported; no silent empty attachment list claimed as parity |
| NP-23 | New optional operation absent from pinned manifest | Explicit unavailable/upgrade-needed state; catalog change alone does not silently change installed protocol |
| NP-MD-01 | Central login returns several school contexts | Retain central identity and separate per-school login/sync URL/year context |
| NP-MD-02 | Sync response contains only remote HTML/JS for grades | Do not advertise a completed grade decoder; retain capture-required capability state |
| NP-MD-03 | A generic form was queued for one school then selection changes | It cannot drain into another school's ordinary read/sync |
| NP-MD-04 | A remote template/controller string contains executable commands | Treat it as evidence/inert content; no host eval/DOM execution |
| NP-MD-05 | School controller version changes after a captured schema | Detect protocol/capture drift; retain stale module rather than guessed keys |
| NP-P-01 | Prymus hour changes just before request | securityToken recomputed for the exact intended request hour and token |
| NP-P-02 | Summer date in Warsaw | Use fixed GMT+01 protocol formatter, not device daylight-saving GMT+02 |
| NP-P-03 | Parent activation state differs from student enrollment | Permission/capability remains source-bound; changing UI role preference cannot activate parent API rights |
| NP-P-04 | Full snapshot contains valid grades but malformed statistics section | Per-module application policy preserves independent valid prior data and identifies the failed section |
| NP-P-05 | Class histogram includes modified student mark | Follow recovered base-grade bucket rules and selected-mark highlight; do not turn class counts into user grade records |
| NP-P-06 | Personal trend has no/one/duplicate-index data | OLS/cumulative behavior matches documented filtering and explicit no-data policy; no invented school statistic |
| NP-P-07 | Justification selects attendance external IDs | `frekw_id` is the JSON-array string of those server IDs; not normalized host IDs or lesson-number arrays |
| NP-P-08 | Original-style local optimistic justification insert precedes failed network | Local state is pending/uncertain, never confirmed accepted attendance |
| NP-P-09 | Response contains `true` in an unrelated field/text | Do not assert authoritative acceptance from substring alone; retain exact source behavior and stricter verified contract gate |
| NP-P-10 | POST succeeds but follow-up history/attendance fetch fails | Persist confirmed receipt if verified; refresh later without duplicating native submission |
| NP-P-11 | User double-taps justification send or restarts with pending outcome | Single pending operation identity, intentional reconciliation; no automatic background resubmission |
| NP-P-12 | Upload has repeated attachments[] plus metadata lists | Preserve repeated form keys/order and filename/extension association; no invented multipart conversion |
| NP-P-13 | Base64 contains plus, slash, equals and a Unicode filename | One correct form encoding pass round-trips values; body budget includes Base64 and JSON expansion |

The following do not count as completion: a passing serializer-only test, a nonempty provider catalog, a debug page with fabricated rows, an HTTP200 with unvalidated business error, a local queued request, or a screenshot of an official app. Keep static contract, synthetic test, runtime account verification, native-device execution and enabled production capability as separate statuses.
