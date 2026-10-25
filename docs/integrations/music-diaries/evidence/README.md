# Evidence, tools and reproducibility

## Evidence vocabulary

- **Observed static:** bytes, parsed package identity, manifest declarations, decoded strings/resources, readable decompiled request builders and SQL mappings. These do not prove live execution or server acceptance.
- **Derived/inferred:** proposed feature meaning, cross-version comparison, proposed model grouping and architecture recommendations. A route literal does not determine HTTP method; adjacent strings do not establish JSON field ownership.
- **Unresolved:** runtime permissions, roles, server versions, dynamic origin discovery, Flutter request/response contracts, mutation semantics and undocumented server features not established by available evidence.

`rea-index.json` is a **provenance index**, not a portable authenticated REA Evidence bundle. It includes exact REA-issued IDs and artifact hashes plus selected summaries; omitted raw records cannot be reconstructed from this index alone. `FRY-*`, `FSTR-*` and MobiReg analyst IDs are not REA IDs. App-specific JSON files retain selected literal offsets, code paths and field mappings. Recheck bytes against the exact source hashes before reusing offsets.

## Analysis performed

1. SHA-256 and format-aware ZIP member inventory for all five original packages; contained APK and native image identities retained separately. Safe local extraction rejected paths escaping the selected extraction root. Originals were not modified.
2. REA `open_binary` / `inspect_artifact` on legacy MobiReg APK, both IPAs, Fryderyk base APK and modern MobiReg base APK. Native archive sessions were closed when finished. Archive inventory reports are complete within their reported substeps, which is not the same as complete semantic analysis of nested code.
3. REA Android provider initially lacked JADX. The pinned provider JAR was downloaded and hash-verified, then REA CLI `inspect-android-package` succeeded for all three Android base packages. `inspect-android-class` and `inspect-android-method` preserved MobiReg SyncParameters metadata and incremental-request decompilation evidence. REA 6.3.0 CLI was used because a running MCP server cannot inherit newly set shell environment variables.
4. JADX CLI 1.5.6 decompiled MobiReg Android. See its report for the exact failure count, fallback methods and coverage limits. Wrapper/framework code in Flutter Android packages is insufficient to recover Dart networking.
5. Python parsed iOS plists and extracted bounded Flutter AOT string objects using class-ID/length/header checks against the supplied images. Exact-layout assumptions and Unicode/search limits are documented in each provider report. Fryderyk Android serialized snapshot ASCII evidence is less complete than its iOS string evidence. Modern MobiReg Android3.1.7 was compared independently against selected iOS literals using compact length/encoding markers and a broader app-owned source-path inventory; equal version/build numbers have different source-revision stamps. These are static content comparisons, not runtime parity.
6. Installed **IDA Pro 9.3, build 260421** was used via `idalib` on separate copies of both iOS `App.framework/App` images. Auto-analysis completed: **27,972** functions for MobiReg; **32,006** for Fryderyk. Endpoint probes at payload/header/tagged-object positions returned no ordinary incoming native xrefs. That does not establish unused code, validate request contracts, or decode Dart object-pool references. The probe reports explicitly bound their first-occurrence search.
7. Siberia ordinary source was inspected at the pinned baseline. REA was not used to infer architecture already visible in complete source.

No original diary application or backend was executed/contacted. No authenticated runtime, push delivery, upload, message send, vote or justification was tested. The work did not implement support or run Flutter application tests; the changed repository files are research documentation and authored analysis scripts only.

## Installed local tools

Tools were installed only under the investigation workspace's `analysis/tools/`; system REA/MCP/IDA configuration was not changed. Java and IDA already existed.

| Tool | Provenance | SHA-256 |
|---|---|---|
| `jadx-headless-mcp-0.7.1-all.jar` | [upstream release](https://github.com/1013503897/jadx-headless-mcp/releases/tag/v0.7.1) | `6e5eacf500b64292bfb73c49797c1958f6ee44646e43e868039ae7feb573ff75` |
| `jadx-1.5.6.zip` | [upstream release](https://github.com/skylot/jadx/releases/tag/v1.5.6) | `545ea2be9c242511bc145755cf4bda2485ade42966e096f8b4d3da2a230e8974` |

Use [REA Android provider instructions](https://github.com/morluto/rea/blob/main/docs/android-analysis.md) for the pinned provider and full JDK requirements. The investigation used REA package **6.3.0**, JDK **25.0.4.1** and Python **3.12**. Future releases may have different requirements; do not silently change the analysis engine and report identical provenance.

## Reproduce and extend

The authored scripts in `../reproduce/` contain no original diary executable or vendor implementation. The original local working layout was:

```text
workspace/
  dzienniki music/                 original 5 archives, hashes in artifacts.json
  analysis/extracted/
    fryderyk-android/              XAPK members, base/ for extracted main APK
    fryderyk-ios/Payload/Runner.app/...
    mobireg-android/               extracted legacy APK
    mobireg-android-modern/        XAPK members and individually extracted splits
    mobireg-ios/Payload/Runner.app/...
  analysis/fryderyk/               extraction outputs
  analysis/mobireg/                extraction/decompile outputs
  analysis/tools/                  local tools
  analysis/ida/                    copied inputs and private analysis outputs
```

The portable Fryderyk extractor accepts `--workspace <workspace> --output <new-output-dir>`. The MobiReg string scanner and IDA probe take explicit input/output paths. The MobiReg register generator accepts `--output` and `--source-reports`; the modern comparator accepts explicit carrier/evidence/output paths. See the [reproduction README](../reproduce/README.md) for exact commands. Retain all hash checks. JSON offsets are file offsets, not automatically virtual addresses. For Fryderyk, the original AOT `libapp.so` is inside the XAPK's ARM64 configuration APK, **not** the base APK. Extract the split as a separate provenance-bearing step.

Typical REA CLI invocation, with the REA dispatcher path selected from the installed package:

```powershell
$env:REA_JADX_MCP_JAR = (Resolve-Path 'analysis/tools/jadx-headless-mcp-0.7.1-all.jar').Path
$env:JAVA_HOME = 'C:\Program Files\Eclipse Adoptium\jdk-25.0.4.101-hotspot'
node '<rea-package>/scripts/rea.mjs' inspect-android-package '<absolute-apk-path>' --json
node '<rea-package>/scripts/rea.mjs' inspect-android-class '<absolute-apk-path>' 'pl.mobireg.mobireglib.sync.SyncParameters' --json
node '<rea-package>/scripts/rea.mjs' inspect-android-method '<absolute-apk-path>' 'pl.mobireg.mobireglib.sync.SyncParameters' 'getDiffImportRequestParameters' --json
```

The actual Windows sandbox account could read ordinary files, but REA's native Windows path controls and IDA library startup required an unsandboxed approved invocation. That was a host access boundary, not a property of the apps. Do not disable REA path protections or patch tools to work around them.

For standalone JADX on this non-ASCII workspace path, use direct Java classpath invocation if the Windows batch launcher misquotes its path:

```powershell
& "$env:JAVA_HOME/bin/java.exe" -Xmx2g -cp 'analysis/tools/jadx-1.5.6/lib/jadx-1.5.6-all.jar' jadx.cli.JadxCLI -d '<output>' '<input.apk>'
```

For the authored native probe, set `IDADIR` and `PYTHONPATH` to the installed IDA root and its `idalib/python`, then run `ida_static_probe.py <copied-App-image> <report.json>`. It never launches the diary application. IDA working files may be created beside its copied input; keep all of them outside the documentation branch.

Future authenticated captures should record app version, role, server/school, action, timestamp and redaction method. Preserve structural fixtures without real credentials, cookies, tokens, QR enrollment secrets, child names, messages or homework contents. Record which exact action was authorized before any test mutation. Do not automatically contact every domain found in an `.env` or binary.

## Verification result

[validation.json](validation.json) records evidence-integrity, packaging and reproducibility checks. The published extraction/register/comparison scripts reproduced their curated outputs. These checks do not close the documented network-contract or live-runtime gaps.
