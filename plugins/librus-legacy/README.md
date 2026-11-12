# Librus Legacy

An optional **downloadable** plugin for signing in directly with a numeric
Synergia login and password. It is not bundled, automatically installed or the
default diary. The existing bundled Librus email-account login stays the default.

Choose **Add another diary → Librus Legacy** to install its verified package.
Use the school-issued login, such as `1234567` or `1234567u`, and its password.
The optional `u` suffix is accepted but never used to infer the account role:
`Me.Account.GroupId` establishes student (`8`) or parent (`5`, `6`) access.
Missing or unsupported roles are rejected instead of guessed. One numeric
Synergia account supplies one child profile; add other numeric accounts separately.

Authentication uses `POST https://api.librus.pl/OAuth/Token` with a form-encoded
password grant and the public legacy mobile-client identifier. Refresh-token
grants renew access. Password text is sent unchanged and is not retained in the
saved session. API account and pupil IDs bind the session and each operation to
their owner; email-account sessions and other plugins use separate credentials.
CAPTCHA, password changes or required account confirmations are reported as
account actions to complete in Synergia, not accepted automatically by the plugin.

Implemented REST modules: grades and category weights, timetable, attendance,
homework, tests/events, announcements, remarks and lucky numbers. The mailbox
supports inbox/sent pagination, recipients, reading, composing and deleting.
HTTP permission failures remain module errors; they do not turn into empty
successes. Absence-only records are not presented as a complete attendance rate.
Raw provider metadata is retained, including information without dedicated UI.

Mail uses the REST API. The bundled Librus client's XML/web fallbacks, attachment
downloads/uploads, full correction-history presentation and native
e-Usprawiedliwienia submissions are not part of this plugin. Availability still
depends on the school's API permissions and support for the legacy OAuth client.

Credential refresh before message mutations has a separate saved checkpoint.
Create/delete operations are never replayed automatically after an uncertain
response. Published bytecode and manifests are immutable and verified by the host.

## Development

On `dev`, the catalog and versioned package live in this directory's repository.
Manual Android/iOS builds from the `dev` workflow use that branch's catalog.
For a local development run, pass:

```sh
flutter run --dart-define=DIARY_PLUGIN_SOURCE=https://raw.githubusercontent.com/johnnydotpm/Siberia/dev/plugins/
```

No APK/IPA build is required to package or test the plugin. SDK tests compile and
execute its source against synthetic responses; Flutter integration tests install
and execute the published `.evc`. No real school account was used for validation.

Protocol references: the independently implemented numeric-login transport and
role discovery follow Szkolny.eu's `LibrusLoginApi.kt`, `LibrusFirstLogin.kt` and
message role mapping. Academic and mailbox REST contracts also use the Librus
supplement at `d254261a5a24b86bae92cafa12b7be812b7f241f` on the
[`docs/music-diary-reverse-engineering-2026-10-25`](https://github.com/johnnydotpm/Siberia/tree/docs/music-diary-reverse-engineering-2026-10-25)
branch. Fixtures are fictional and do not establish current server acceptance.
