# Librus models, mapping and module behavior

This subtree is documentation for future independent implementation. It contains no client/plugin implementation and no real account fixtures.

Read [DTO-MAPPING.md](DTO-MAPPING.md), [WORKFLOWS.md](WORKFLOWS.md), and [synthetic cases](synthetic-cases.json). The complete [model field table](MODEL-FIELDS.md) has62 local model declarations and801 fields, also available as [JSON](model-fields.json) and [CSV](model-fields.csv). [Builder consumer index](builder-consumer-index.json) locates functions, dependencies and property reads across52 builder modules.

Evidence is shipped iOS Librus8.4.1 build6487 source-map `sourcesContent`. The Android documentation independently establishes which mapped modules match its8.4.1 build64872. A model declaration and its default describe the original client's local Vuex-ORM representation. They are **not** a complete wire schema and do not prove that a server field is nullable, mandatory or a particular JSON primitive. A raw builder read proves consumption, not universal server emission. Runtime acceptance, school permissions and edge response types remain separate checks.

Each field record gives original source path, source-map entry index, content SHA256 and line. Original source files remain local research inputs and are not reproduced here. `source_content_sha256` hashes the UTF8 source-map string before filesystem newline conversion. Paths such as `src/viewmodels/grades.js` are provenance locators inside that original map, not relative links to code bundled with this documentation.

Recommended three-stage decoder: validate an operation's raw response; retain a provider DTO with raw IDs/enums/optional fields; then build a normalized Siberia projection. Retain fields that the current Siberia model cannot express. Do not use the vendor's presentation strings as durable IDs or silently inherit its error-to-empty fallbacks.
