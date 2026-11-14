# Protocol differences that affect implementation

This is a navigation aid. Exact contracts, source anchors, default branches and remaining uncertainties are in the provider reports. All observations are scoped to the supplied releases; no live backend behavior was verified.

| Dimension | mobiDziennik12.13 | Prymus1.2.68 |
|---|---|---|
| Client architecture | Cordova, readable packaged bootstrap; module UI/controllers downloaded later | Native Android Java/Kotlin, Retrofit and typed response/database models |
| Product/package identity | `pl.mobidziennik.web`, distinct from MobiReg | `pl.bialystok.zeto.prymus` |
| Enrollment | Central form login at packaged `/logowanieapp`; returns user/school context | Manually entered or QR enrollment token; exact parser and server discovery in provider guide |
| School origin | Returned `user.sync_url`, not necessarily login origin | Selected/configured school service; verify the provider's exact base construction |
| Credential representation | Raw `haslo` at login; `hash:true` is a request flag. Returned `password_hash` is opaque; no client MD5 transformation was recovered | Raw token plus derived hourly `securityToken`; SHA256 construction and app configuration are separate from pupil selection |
| Per-request auth | Form fields including login/email/haslo_hash/ciasteczko_autoryzacji, device metadata; optional raw password in selected paths | `token`, `securityToken` and operation-specific form/query fields; not a universal JWT Bearer decorator |
| Date dependency | Per-field local formats and server-returned account/school year | Authentication hour uses fixed GMT+01:00, not automatically Europe/Warsaw's seasonal offset |
| Read transport | Form POST sync also carries pending local changes in some paths | GET full pupil data plus numerous form POST operations; methods are in the Retrofit ledger |
| Dynamic dispatch | `functionName` passed to `core.exec` is debug context. It does not automatically add a wire `akcja` parameter | Declared route plus operation `type` where applicable; integers require caller proof |
| Mutation body | `formularze` is a JSON string containing recovered generic name/kontroler/get/post records. Concrete academic controller values are absent from the bootstrap | Form `wyslijDane` type101 justification includes an inner JSON map; other action types remain operation-specific |
| Justification selection | Concrete school-controller contract not recovered from the package | Attendance external IDs in `frekw_id`, itself a JSON-array string inside the inner JSON; do not substitute Librus lesson numbers |
| Statistics | School-delivered templates determine actual datasets and formulas; bootstrap does not prove them | Class-comparison grade histogram, local grade-trend calculations and school-reported attendance-percentage models; preserve each method and period |
| Files | Generic multipart/blob helpers and local save flow exist; missing controller/URL/payload ownership can still block a concrete action | Form/base64/list fields can differ from binary downloads; resolve each caller rather than assuming all uploads use multipart |
| Persistence | SQLite/WebSQL stores users, opaque queued data/forms and template HTML/JS; local login namespace has limitations | Typed local entities and server snapshot fields; retain account/tenant/token ownership separately |
| Retry | Queued forms can be retried; original push/pull/error behavior has duplicate/loss risks | Response/business-status rules and idempotency are operation-specific; do not blindly replay user actions |

## Keep request layers explicit

Examples of distinct nested encodings:

```text
mobiDziennik:
  URL-encoded form
    formularze = JSON string
      <form name> -> [{name, kontroler, get, post}]

Prymus justification:
  URL-encoded form
    type = 101
    json = JSON string
      {id_ucznia, data_wyslania, data_nb, godz_lekc,
       frekw_id: JSON array string, uspr}
```

Do not flatten these layers, JSON-encode the entire outer form, or double-encode a field because it already contains JSON-looking text. Let each serializer own one layer and verify the final decoded map plus inner value types. Exact user-field types and date grammars belong to the provider's request examples, not this abbreviated sketch.

`ciasteczko_autoryzacji` is the observed mobiDziennik form-field name. It does not establish an HTTP Cookie header. Likewise, a Prymus token is not automatically a JWT, and a field called `password_hash` is not automatically an MD5 digest. Choose the transform from its producer chain rather than its label.

## Use current host constraints

The current downloaded-plugin bridge has concrete request, response, time, payload and execution limits. Some file operations and additional write types require host capability work even when the remote protocol is known. Read the SDK plan's exact limit direction and affected API. A generic form body may fit existing string HTTP support; a binary response or unsupported session operation may not.

Prymus's class-comparison label is corroborated by the UI string `Na tle klasy` and its mark-chart caller, not inferred from a field name alone. It is a distribution for the selected mark/category, not a ranked list of pupils. Its trend implementation includes a true linear regression over indexed valid marks; this differs from the cumulative-average line recovered in Librus. The provider's focused statistics guide gives the exact transformations and caveats.

Do not persist an entire sensitive full-pupil response in the secure credential state merely to work around one invocation's lifetime. Use owner-scoped credentials, a deliberately designed shared/module snapshot mechanism, and explicit coverage/freshness. Keep SDK changes small and justified by the recovered wire contract.
