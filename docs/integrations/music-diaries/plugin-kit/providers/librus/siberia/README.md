# Librus findings → existing Siberia implementation

This subdirectory documents **the inspected Siberia source**, the changes a future agent should consider, and acceptance criteria. It does not implement those changes. Read the official-package Android/iOS reports beside this directory before choosing a transport. A request present in Siberia is evidence about Siberia, not proof that the supplied official application makes that request.

Primary inspected application baseline: remote main `fdd022da1759caf254873fbb6d8ffdea7e360b68`, exported read-only for research on2026-10-30. All source paths below are repository-relative. The documentation branch still contains older application code at `c09caaa5f2780a9e1c60aaf94bf9e02e25fe4efc`; do not apply its older architecture plan blindly to current main. Recheck HEAD, repository instructions, file fingerprints and exact anchors before editing. The read-only source export is research input, not an application patch.

Read:

1. [Current behavior](CURRENT-BEHAVIOR.md): existing requests, sessions, synchronization, caches and limitations.
2. [DTO and UI mapping](DTO-MAPPING.md): where source fields fit and where information is lost.
3. [Future implementation runbook](AGENT-RUNBOOK.md): exact file/task ownership, dependencies and meaningful checks.
4. [Source anchors](source-anchors.json): hashes and literal/line locators for the inspected implementation.
5. [Existing request inventory](current-requests.json): explicit observed source requests, effects and scope. Not the official-app endpoint catalogue.
6. [Acceptance scenarios](ACCEPTANCE-SCENARIOS.md): fixtures and race/error cases to verify when implementing.
7. [Official-operation task routing](official-operation-triage.json): every function in the neighboring official catalogue assigned to a host integration review task. This is source-family triage, not proof of wire compatibility or enabled features.
8. [Documentation validation](validation.json): exact scope of the offline source/reference checks.

Siberia already connects Librus through Portal authorization, Synergia API2.0 and two mailbox fallbacks. Extend that implementation where appropriate; do not add a second competing Librus plugin merely because the other diary documentation uses the word plugin. Keep independently scoped service credentials, role/capability policy and normalized DTO boundaries.

These documents preserve uncertainty: official feature presence, a static request builder, third-party API availability and server authorization are separate facts. Do not claim parity with the APK/IPA until their version-scoped feature coverage is mapped to the host and verified appropriately.
