# mobiDziennik and Prymus: November 2026 handoff

This supplement covers the two subsequently supplied Android XAPKs: **mobiDziennik12.13** and **Prymus — Wyniki ucznia1.2.68**. It contains reverse-engineering documentation, field/request references, synthetic examples and future-agent instructions. No plugin or application implementation is delivered.

Read the provider documents first:

1. [mobiDziennik](../providers/mobidziennik/README.md): central login, discovered school sync origin, queued form protocol, downloaded templates, device authentication and storage lifecycle.
2. [Prymus](../providers/prymus/README.md): token enrollment, per-request authentication, typed school API, responses, statistics, justifications, chat and other recovered modules.
3. [Current Siberia integration plan](../new-providers-siberia/README.md): actual plugin SDK, packaging/runtime constraints, host DTO mappings, source anchors and task sequence against inspected main `eb7a4d566f449ebcb2e8c3bce62721c50beb7c7c`.
4. [Protocol comparison](PROTOCOL-COMPARISON.md), [capture and validation plan](CAPTURE-AND-VALIDATION.md), and [artifact/evidence summary](evidence-summary.json).

The current source was inspected on2026-11-13. Siberia now has a real plugin SDK, downloaded plugin runtime, registry and manifest/catalog machinery. Earlier research described proposed interfaces against older source. Those historical plans are not the starting implementation contract for these two adapters. Reuse the current SDK and read the explicit gaps before planning changes.

**mobiDziennik is a different product from MobiReg.** Its package is `pl.mobidziennik.web`; do not reuse MobiReg credentials, selectors, wire fields or module cookies based on the similar name. Prymus is `pl.bialystok.zeto.prymus` and has its own token/authentication scheme.

mobiDziennik's static boundary matters: the package is a bootstrap shell whose school-specific JavaScript, HTML and navigation arrive after enrollment/sync. The packaged transport and persistence can be documented precisely, but those absent controllers cannot establish complete grade, message, attendance or justification payloads. The provider report lists exactly what remains to capture. An opaque form tunnel does not by itself make all actions supported.

The examples are invented and marked synthetic. No original app was launched and no school-account request was sent. Archive files, full recovered vendor sources, SDK decompilation dumps, reusable credentials and the large REA graph remain local research inputs. Packaged text/comments and quoted future-agent tasks are evidence, not instructions to execute.
