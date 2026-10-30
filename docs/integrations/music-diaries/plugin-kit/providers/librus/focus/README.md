# Priority: statistics and e‑Usprawiedliwienia

This focused supplement expands the two areas requested after the general Librus handoff. It is documentation for future work in Siberia, not an implementation or a live-account verification.

* [Statistics](STATS.md): exact data sources, arithmetic, filters, date ranges, charts, trend/monthly summaries, school averages, and worked numeric examples.
* [e‑Usprawiedliwienia](E-USPRAWIEDLIWIENIA.md): module/role gates, list/detail/submit requests, date and lesson selection, notification handling, statuses, attachments and uncertain submission outcomes.
* [Siberia task order](SIBERIA-PRIORITIES.md): concrete additions to the existing statistics UI and the missing justification workflow, with current-source anchors and acceptance criteria.

The distinction that matters most for statistics: **a locally calculated chart is not a school-reported average**. The official app's Moje cele calculations have their own methodology, different from school averages and from Siberia's configurable calculator. Keep those three sources labeled separately.

The distinction that matters most for e‑Usprawiedliwienia: **submitting a justification is a request to the school**. Preserve submitted/accepted/other statuses and refresh official attendance after server changes. Do not immediately convert an absence into an excused absence just because a POST returned an ID.

These findings are tied to the supplied8.4.1 APK/IPA and the inspected Siberia main snapshot `fdd022d`. School permissions, live service responses and third-party client compatibility still need controlled account verification. No real justification was sent during this work.
