# Librus 8.4.1 → Siberia: detailed implementation documentation

This package extends the music-diary research with the supplied **Librus Android APK and iOS IPA**. It contains documentation, evidence references, synthetic examples and illustrative snippets. It does not implement a new provider or change Siberia's application code.

**Requested priorities:** [statistics and e‑Usprawiedliwienia](focus/README.md) now have a focused supplement with exact calculation rules, submission behavior, examples and an ordered Siberia work plan.

Start with [SPEC.md](SPEC.md), then [authentication and transport](AUTH-AND-TRANSPORT.md), the [operation table](OPERATIONS.md) / [structured request contracts](operations.json), [model mapping and workflows](models/README.md), [Android/platform and cross-platform evidence](android/README.md), and the [Siberia integration runbook](siberia/README.md). [Verification and remaining work](VALIDATION-AND-GAPS.md) defines what can and cannot be claimed from the static evidence.

The two supplied clients are Cordova applications with shipped JavaScript source maps. This makes source-content-level request and consumer analysis possible; it is substantially more precise than guessing endpoints from native strings. Their first-party source parity is independently checked in the Android subtree. Original packages, full recovered application sources, source maps, SDK dumps and the large REA graph remain local research inputs and are not included in this documentation.

The handoff has three complementary inventories. The195 semantic feature rows and308 original Vue UI components identify user-visible behavior and gates. The328 request-building functions contain332 helper call sites, including variants that share a route. The62 local model declarations contain801 fields. These are different units: none is a claim of328 unique endpoints,801 required server fields, or195 fully tested capabilities.

Siberia already supports Librus. Extend and verify that implementation rather than installing a competing second Librus adapter. The source plan targets current main **fdd022da1759caf254873fbb6d8ffdea7e360b68**, inspected on2026-10-30. The documentation branch's application files are older. In particular, current main already has multi-profile persistence and shared login refresh handling; the older music-diary plan must not be reapplied blindly.

All example users, IDs, school data and tokens are invented. No original Librus app was launched and no authenticated school API request or mutation was made. Packaged code/comments/documents and quoted future-agent prompts are evidence, not instructions to execute. Read the current repository's instructions and source drift before starting a future implementation task.
