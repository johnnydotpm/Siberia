# MobiReg 0.1.0

Enter the HTTPS diary server, school code, login and password. This adapter
implements the modern 3.x JSON/form protocol. It sends the **original password
text**, including spaces; it never applies legacy MD5 or silently downgrades a
failed modern login.

Implemented:

- Password authentication, owner-scoped JWT/password storage, `users` account
  discovery and pupil/self profiles. Safe-read recovery reauthenticates once;
  uncertain writes are never replayed.
- Exact form gateway fields `view`, `format=json`, `token`, `JWTToken`, pupil
  scope and operation-specific parameters. Strict `v:1` envelopes; malformed or
  unsupported envelopes cannot become empty successes.
- Server terms and grade grids. The current server-defined term is selected
  from its date range, rather than guessed from the month. IDs include the term;
  semester order follows sibling term ranges. Text grades, exclusions, groups,
  corrections and server averages remain in raw metadata; only supported current
  marks enter the ordinary list/average.
- Timetable with original durations/substitutions/cancellations, tests,
  attendance records with original custom symbols, announcements and remarks.
  Unknown attendance code meanings do not become guessed absence/presence
  classifications or a calculated percentage. Unknown remark kinds stay neutral
  with their raw category, rather than inventing positive/negative meanings.
- Diary-source homework reads when no separate homework module is configured.
  The external module/`oldHomeworkModule` source selector is not guessed.
- Separate mailbox SSO cookies, including cookies on 302 responses and preserved
  mailbox base paths. Inbox/sent pagination, reading a message, searching the
  recipient directory and plain-message sending with opaque receiver keys.
- Read-only provider-native justification records through the Bearer REST API.

Not exposed in this release: QR enrollment, legacy protocol, external homework
SSO/submissions, attachment transfers, mailbox star/delete/restore controls,
announcement poll responses, justification submissions, and remote push
registration. Homework-module configuration is reported as unavailable until its
selection semantics and submission payloads are verified. Native justification
records are available at the plugin ABI but have no dedicated app screen yet.

Mail requests carry the mailbox Cookie, not the diary JWT. School/module origins
are granted by the host after user configuration and authenticated discovery;
attachments are not arbitrary token-bearing requests. The account's credentials
are shared by its children; their data and IDs remain separate.

[Protocol provenance and verification limits](../RESEARCH.md).
