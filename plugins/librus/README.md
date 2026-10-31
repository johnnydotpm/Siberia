# Librus — bundled plugin

Librus implements the same `DiaryPlugin` / `DiarySession` interfaces as the
adapter for downloaded diaries. It is registered locally as `id: librus` by
`DiaryPluginRegistry` and appears in the diary picker even if catalog retrieval
fails.

The entrypoint is
`syberia/lib/src/data/librus/librus_plugin.dart`. Its protocol implementation and
portal/mail sessions remain in `librus_client.dart`, compiled with the app.
There is no separate `.evc`, plugin installation or download at Librus login.
Its version follows the application release.

The repository calls the registered plugin for authentication, child discovery,
full/partial sync, timetable, recipients, sending, sent messages, message details,
attachments and account cleanup. Bundled and downloaded plugins return the same
school DTOs; the app keeps local data and settings per profile.

Existing Librus login keys, Synergia account choices, profile IDs and snapshots
are retained. `LibrusPart` remains a compatibility alias for the shared
`DiaryPart` enum. `usesDownloadedPlugin` describes installation; Librus is a
plugin too.

`catalog.json` lists downloadable releases only. The SDK reserves the Librus ID,
and the registry gives bundled registration priority, so a remote catalog cannot
replace the built-in client or require a download before login.
