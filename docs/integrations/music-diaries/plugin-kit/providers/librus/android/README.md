# Librus Android package, platform behavior and feature coverage

This subtree is documentation for the supplied `pl.librus.synergiaDru2.apk`, version **8.4.1 / code64872**. It contains no adapter, runnable diary client or original vendor source bodies. Its SHA256 is `b99a5d84b57947ccb78637038abe7c47b04f3c294e3d9f3383fc3f0d66b1609b`.

The application is a **Cordova web app**, not a Flutter snapshot or a primarily Java diary client. `pl.librus.synergiaDru2.MainActivity.onCreate` delegates to Cordova, honors `cdvStartInBackground`, and loads the configured launch URL. Most Java classes are Cordova/SDK infrastructure. Diary behavior resides in packaged JavaScript, Vue components, API wrappers, view builders and Vuex stores. The shipped maps include original `sourcesContent`; this allows field/caller analysis without guessing from native SDK strings.

Read:

1. [Platform and reconstruction guide](PLATFORM.md): permissions, browser callbacks, storage, push, files/photos and required integration checks.
2. [Readable feature coverage](FEATURES.md):195 analyst-defined semantic rows across account, diary, LibrusGO, meals, content, subscription and platform surfaces.
3. [Feature inventory JSON](feature-inventory.json) / [CSV](feature-inventory.csv): stable IDs, version scope, source locators, gates and acceptance requirements.
4. [UI action index](ui-action-index.json): all308 original Vue single-file components in the first-party extracted source set, with template event bindings, literal store targets and method/computed names.
5. [Cross-platform parity](cross-platform-parity.json): original member hashes and source-content comparisons for supplied APK/IPA.
6. [Package declarations](android-package.json), [web member hashes](web-member-hashes.json), [map/source locators](source-map-index.json), [verification](validation.json).

These counts serve different purposes.195 rows are a semantic checklist,308 are components including reusable dialogs/cards, and a component may support several features. None is a unique endpoint count or a statement that every account can access the feature. Network methods, bodies, response fields and authorization must come from the provider's transport contract documentation, not inferred from these names.

## Source evidence and attribution

REA package inventory evidence: `ev_1a0a194cff866b904259633374f27e3047749bcee22362128451fe6a8558d2eb`. Focused entrypoint evidence: `ev_6e4231e14576a08494245480cd942e4d963a8710eb84a19d485f5fffb3006b33`. Focused new-intent bridge evidence: `ev_19607e4b56f26a4a04412baf596a36f75bb8fed87463a63fecb527960186acd6`. Original APK digest binds all three. Local raw evidence remains under `analysis/librus/android/`; this documentation retains identities and bounded conclusions rather than full decompiled methods.

The APK app map is `assets/www/static/js/app.4f2632438e1de389e6b3.js.map`, SHA256 `8b853e1f2492ffcccae46f137c7c73a0c805fc243f74a65b0d5c658d53e9a22d`. It has1332 total sources and1331 first-party source records. Additional first-party entries occur in separately shipped maps. Original Vue URLs `webpack://librus/src/...` are distinct from generated wrappers `webpack://librus/./src/...` and generated render URLs with query suffixes. The source index preserves map member, exact source URL, index and UTF8 `sourcesContent` hash; it does not merge these representations.

Bulk JADX1.5.6 reported107 errors across the full Java output. That is an explicit boundary, not107 confirmed product defects. The selected entrypoint/new-intent methods were independently requested through REA/JADX headless. Native plugin behavior not individually corroborated should retain its decompiler qualification.

The supplied base APK declares required ABI/density splits. Packaged web resources are available for static analysis, but standalone installation or runtime completeness was not tested. The application was never launched, and no school-account endpoint was called.

## Cross-platform result

Both archives contain1094 web files. Of1085 equal relative paths,1082 have identical original bytes; three differ (`cordova.js`, `cordova_plugins.js`, `index.html`). Each side has nine platform/build-specific filenames. App bundle/map names differ, while all **1331 shared first-party app map source URLs have identical source-content hashes**. Thus the shared source descriptions can be reused across these two supplied versions, with platform branches and native bridges still analyzed separately. This does not establish source-map-to-bundle execution equivalence, equal installed permissions or current server behavior.
