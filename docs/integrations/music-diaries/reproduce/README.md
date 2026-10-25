# Reproduce the research outputs

The original app packages are user-supplied local inputs and are not in Git. Verify `../evidence/artifacts.json`, then use the working layout in `../evidence/README.md`. Never feed a different app release into a build-specific parser and reuse the old evidence IDs.

These are authored scripts, not recovered vendor application source. They perform local static analysis only. Use separate output directories so reproducing a report cannot replace reviewed evidence accidentally.

## Fryderyk route/source-path extraction

```powershell
python extract_fryderyk_evidence.py --workspace '<original-investigation-workspace>' --output '<new-fryderyk-output>'
```

Requires the extracted Fryderyk iOS App image and Android ARM64 split APK. It verifies both AOT image hashes and reconstructs 34 platform-specific route occurrences. It does not recover HTTP methods or response schemas.

## MobiReg iOS candidate Dart strings

```powershell
python extract_dart_strings.py '<mobireg-ios-App-image>' '<private-full-ios-strings.json>'
```

The class IDs/layout were checked only for this supplied iOS 3.1.7 build. Review false positives and use source identity before applying its output. The complete dump mixes application/framework strings and may include sensitive configuration; retain it locally.

## MobiReg modern platform comparison

```powershell
python compare_modern_snapshot.py --android-carrier '<modern-android-libapp.so>' --ios-full '<private-full-ios-strings.json>' --selected '../mobireg/ios-selected-evidence.json' --output '<new-modern-comparison.json>'
```

This compares selected strings using Android compact length/encoding markers, and independently inventories app-owned source paths and ASCII route candidates. It is a bounded static content comparison, not a Dart decompiler. Expected headline results: 381 exact selected matches, 8 private-symbol variants, 137 source paths on each platform with identical sets. Android revision is `6f4e7b8`; iOS revision is `d20dd8d`.

## Regenerate the analyst-authored MobiReg task/protocol register

```powershell
python build_handoff_data.py --output '<new-register-output>' --source-reports '../mobireg'
```

The generator encodes the curated interpretation of the evidence; it is not an independent verification oracle or an automatic application analyzer. It reads the modern comparison to preserve new platform evidence. Compare its output to reviewed files before accepting changes. It does not regenerate the complete legacy field mapping or SQL schemas; those require inspecting the corresponding APK assets and mapping classes.

## IDA static native probes

Use `ida_static_probe.py <copied-App-image> <new-report.json>` with installed IDA's `idalib` and environment described in the evidence notes. It auto-analyzes a **copy**, inventories functions/segments and probes first-occurrence literal xrefs. It does not execute the diary app, recover Dart wire schemas or establish endpoint reachability. Keep IDA working databases outside this documentation directory.

## Validate the packaged research

```powershell
python validate_research.py --workspace '<original-investigation-workspace>' --docs '..'
```

Checks original archive/native hashes, selected source byte offsets, modern string length markers, feature-register completeness, legacy schema counts, JSON syntax, local Markdown links, allowed file types and common credential patterns. A pass validates evidence integrity and packaging only; it is not a server-contract, app-implementation or runtime-test pass.
