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

## Not checked

- The API addresses of the module. Names such as `Justifications` are
  guesses until a parent's phone answers them.

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
