# Fryderyk 0.1.0

Use **Dostęp mobilny → Wygeneruj dane logowania** in the school portal. Enter
those mobile credentials, not ordinary website credentials. Siberia identifies
the device as `SiberiaGB`; `App-Version: 1.1.7` is an explicit compatibility
choice matching the newer recovered client protocol.

Implemented:

- Enrollment at the token service's `/identify`; academic requests use the
  validated school URL it returns. Refresh uses `/reIdentify` with `u` and `t`,
  rotating both tokens in one checkpoint. User/guardian and child discovery.
- Grades overview with semester boundaries, textual grade values and separate
  raw predicted/final assessments. Stable content identities handle grades
  without a server ID and preserve duplicates.
- A dated timetable with real durations, cancellations, substitutions,
  accompaniment sessions and embedded exams. No fixed 45-minute assumptions.
- Absence records, raw year/month server attendance summaries and absence-request
  history. The app does not calculate a misleading percentage from an
  absence-only list.
- Read-only homework and its due dates/content.
- Inbox/sent pages, recipient directory with opaque keys, opening/marking read,
  and sending a plain message. Sending uses the documented To/CC/BCC/body keys;
  it is never retried automatically after an uncertain outcome.

Not exposed in this release: attachment downloads/uploads, CC/BCC compose UI,
reply-all/forward/delete controls, native absence submissions, remote push
registration, and final/proposed-grade presentation as separate UI sections.
Raw academic metadata is retained for later presentation, not mixed into current
marks or inferred permissions. No unsupported announcement/remark endpoint is
invented; those modules show their unavailable state.

The initial message page defaults to `1` and is a Siberia pagination policy that
still needs confirmation with an authorized current backend fixture. Pages carry
an explicit next cursor and the app bounds a refresh to 50 pages. Times without
an offset follow Dart's local interpretation, as the recovered client does;
actual school-zone behavior still needs a device/account fixture.

[Protocol provenance and verification limits](../RESEARCH.md).
