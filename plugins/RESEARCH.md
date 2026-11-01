# Protocol provenance

These adapters were independently authored from the specifications on
[`docs/music-diary-reverse-engineering-2026-10-25`](https://github.com/johnnydotpm/Siberia/tree/docs/music-diary-reverse-engineering-2026-10-25),
reviewed at commit **`d254261a5a24b86bae92cafa12b7be812b7f241f`**.

Primary inputs:

- `docs/integrations/music-diaries/plugin-kit/providers/fryderyk/SPEC.md`,
  `response-fields.json`, `request-vectors.json` and
  `contracts/fryderyk-contracts.json`.
- `docs/integrations/music-diaries/plugin-kit/providers/mobireg/SPEC.md`,
  `discovery-auth.json`, `decoder-shapes.json`, `recipes.json`, `runtime-gates.json`,
  and the modern auth/gateway, academic and module contract ledgers.

The source builds are Fryderyk Android 1.0.12 / iOS 1.1.7 and modern MobiReg
Android 3.1.7. The research also documents legacy MobiReg 2.1.79 and a later
Librus supplement. Legacy MobiReg is not selected implicitly; Librus remains
built into Siberia.

The code, bytecode and fixtures in `/plugins/` are new Siberia implementation
work. No vendor application binaries, decompiled source, production credentials
or recordings of personal school data are included. Fixtures are synthetic and
exercise the recovered contracts, not current server acceptance. No live account
was used and no messages or absence requests were sent to a real school.

The SDK compiler is pinned to dart_eval 0.8.5. Marking the shared protocol library
as an entrypoint avoids transitive-helper tree shaking. The adapter sources use
explicit collection types and JSON strings between some normalization helpers to
avoid boxed-value issues in this interpreter version. Tests compile **and execute**
the adapters; the Flutter integration tests also download and execute the exact
published `.evc` files. A successful source compilation alone is insufficient.

Native application builds and on-device validation were deliberately not run.
