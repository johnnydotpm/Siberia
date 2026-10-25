# Apply the diary plugin kit to SiberiaGB

This subtree is an **integration kit**, not an installed plugin or a completed connector. SiberiaGB currently has no plugin framework: `AppRepository` constructs a concrete `LibrusClient`, and the shell rejects other providers. The first implementation task is to install the provider boundary described here while preserving Librus behavior.

The inspected checkout is `e628216e01dc36786581f9a392f1bc7d946d5be8`; the application source remains the earlier `c09caaa5f2780a9e1c60aaf94bf9e02e25fe4efc` baseline. This kit does not modify the application, commit, or push. `source-anchors.json` records exact file hashes and matched anchors so another agent can detect source drift before editing.

Read in this order:

1. [Source patch plan](SOURCE-PATCH-PLAN.md): per-file edits, integration boundaries, migration algorithm and races.
2. [DTO mapping](DTO-MAPPING.md): field-level mapping, mandatory additive models and known losses.
3. [Agent runbook](AGENT-RUNBOOK.md): task dependencies, concrete inputs/outputs and checks.
4. [Feature application map](feature-application-map.json): all **94** original feature IDs assigned to implementation/UI tasks, with explicit blocked/vendor-only dispositions.
5. [Acceptance scenarios](ACCEPTANCE-SCENARIOS.md): deterministic regressions and authorized runtime gates.

Use the parent kit's [DESIGN.md](../DESIGN.md) as the canonical **proposed** interface reference for `ProviderId` (`librus`, `fryderyk`, `mobireg`), `AuthOwner`, `DataScope`, typed module outcomes, transport/request planning and operation catalog. This subtree specifies where those concepts would connect to Siberia; it does not define a competing framework. Names proposed for new app-facing classes are design names, not existing classes. No plugin source, executable scaffold or application patch is delivered here.

Before implementing, compare the referenced files with `source-anchors.json`, and compare the 94 feature IDs against the source coverage register. Check source fingerprints and anchor presence before editing. This documentation does not claim Flutter integration or backend correctness. Future app changes should intentionally update the source manifest after reviewing their diff.

Deep contracts supersede initial route guesses. Read [Fryderyk recovery](../evidence/FRYDERYK-RECOVERY.md), [MobiReg auth](../evidence/MOBIREG-AUTH-RECOVERY.md), [MobiReg modules](../evidence/MOBIREG-MODULE-RECOVERY.md), [MobiReg academics](../evidence/MOBIREG-ACADEMIC-RECOVERY.md), and [legacy corrections](../evidence/MOBIREG-LEGACY-CORRECTIONS.md), plus the [operation catalog](../contracts/operations.json). In particular, Fryderyk `/login` is an app deep-link path, `/validate` is a version operation, and logout is locally observed; modern MobiReg password JSON differs from the legacy MD5-backed form credential. Static recovered operations are implementation inputs, not proof of current server policy or successful user-account tests.
