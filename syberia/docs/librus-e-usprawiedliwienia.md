# Librus: e-Usprawiedliwienia, what is known

What the app needs to send an excuse note through the e-Usprawiedliwienia
module of Librus itself, instead of a message to the class teacher.

## Checked

- 2026-11-02, portal.librus.pl, a public page without signing in: the
  offer of the paid "Mobilne dodatki" for the official Librus app lists
  "Wysyłanie e-Usprawiedliwień" as one of the features. In the official
  mobile app the module may therefore be paid; whether the API behind it
  is limited the same way is not known.
- The module itself lives in Synergia (synergia.librus.pl), behind a
  sign-in. Its pages, addresses and form fields cannot be read without a
  parent's account, and the app does not sign in to anyone's account from
  outside the phone.

- 2026-11-04, the debug check on a parent's phone (keys only):
  - `Me` 200: the check works;
  - `Justifications` 200 with a wrapper `{status, message, data}`; each
    note in `data` has `id, messageFromParent, postDate,
    justificationStatus, lessons[], attachment, dateFrom, dateTo,
    justifiedAbsences, notifiedTeachers[]`;
  - `Attendances/Justifications` and `AttendanceTypes` 404.
  So the module answers this school's parent accounts through API 2.0,
  the one the app already uses, and the app now reads the notes into its
  history.
- Third-party libraries (librus-sdk, librus-python-api, librus-synergia)
  only read the notes; none sends one.
- 2026-11-05, the check v2 on the same phone:
  - `justificationStatus` was `accept` on both notes;
  - `postDate` reads `dddd-dd-dd dd:dd:dd`, `dateFrom` and `dateTo`
    `dddd-dd-dd`;
  - a notified teacher is `{name}`; `lessons` was empty on both notes;
  - `Justifications/<id>` answers one note in the same shape;
  - `OPTIONS Justifications` 405 with `Allow: POST, GET`;
  - one empty `POST Justifications`: 400, `Code: InvalidRequest`,
    `Message: Nie wprowadzono daty.`; nothing was kept.
  So a note is sent by POST to the same address, and a date comes first.

## Not checked

- The names of the fields a note is sent with. "Librus: check field
  names (no dates)" sends a few notes whose dates read "x", which Librus
  cannot keep, under different names; the name Librus reads is the one
  whose answer is not "Nie wprowadzono daty".
- The words `justificationStatus` takes besides `accept`.

## How to check

The hidden debug menu has "Librus: e-Usprawiedliwienia". On a parent's
profile it asks the API, read only, for:

- `Me`: shows the check itself works;
- `Justifications`;
- `Attendances/Justifications`;
- `AttendanceTypes`.

For each it shows the status and the shape of the answer: its keys, list
sizes and kinds of values, never a value. The result is copied, ready to
send. Stage 6b builds on what it shows.

For `Justifications` it also shows the status words, the shape of the
dates (digits as `d`), the keys of a notified teacher and of a lesson,
one note on its own (`Justifications/<id>`) and `OPTIONS`.

"Librus: test sending (empty request)" asks first, then sends one empty
`POST Justifications` and shows the status and the error messages. Never
retried.
