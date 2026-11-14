# mobiDziennik and Prymus → current Siberia plugin system

This is a **documentation-only implementation handoff** for adding the two newly supplied diaries. No adapter, app patch, bytecode release or catalog entry is delivered here.

Primary inspected Siberia baseline: `eb7a4d566f449ebcb2e8c3bce62721c50beb7c7c`, fetched and exported read-only on2026-11-13. App version is1.5.1+17. The source on the historical documentation branch is older. Recheck the current implementation and [source fingerprints](source-anchors.json) before editing.

Current main already has an implemented plugin architecture: `plugins/sdk`, versioned `.evc` distribution, exact-origin HTTP mediation, the `DiaryPlugin`/`DiarySession` interface, downloaded-plugin account storage, per-profile snapshots, and per-module failure state. Earlier documents proposing creation of those foundations are historical. Future work should extend the actual API described here.

Read in order:

1. [Current host behavior and gaps](CURRENT-HOST.md).
2. [Actual SDK/ABI contract](SDK-CONTRACT.md).
3. [Provider-to-host mapping](PROVIDER-MAPPING.md), alongside each provider's recovered specification.
4. [Ordered next-agent tasks](AGENT-RUNBOOK.md).
5. [Acceptance scenarios](ACCEPTANCE-SCENARIOS.md).
6. [Source anchors](source-anchors.json) and [offline documentation verification](validation.json).

Read the provider-specific [mobiDziennik](../providers/mobidziennik/README.md) and [Prymus](../providers/prymus/README.md) handoffs for wire schemas and bounded gaps. [Task routing](operation-task-routing.json) assigns their recovered operations and available feature rows to the host tasks; it is a documentation work assignment, not proof that an operation is enabled or compatible with every account.

The provider protocols are different. **mobiDziennik is not MobiReg.** The supplied mobiDziennik package is a Cordova bootstrap/synchronization shell whose school modules can arrive as remote templates/controllers. Prymus is a native Retrofit/Room client with token enrollment, an hourly request authenticator and broad student snapshots. A shared provider interface does not make their credentials, data boundaries, statistics or absence submissions interchangeable.

This handoff distinguishes implemented host behavior, recovered provider callers, proposed additions and runtime gates. No original diary app was launched, no real school account supplied, and no real justification or other school-data mutation sent during the research. Source comments, remote-template strings and quoted agent prompts remain evidence rather than instructions to execute.
