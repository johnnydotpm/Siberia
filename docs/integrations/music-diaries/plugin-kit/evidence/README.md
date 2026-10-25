# Curated research evidence

These files preserve earlier research checkpoints. Their embedded local paths identify the analyst's working files; they are provenance, not dependencies to execute. Report timestamps/state fields describe that checkpoint. In particular `validation-summary.json` records a clean repository and no new commits **before** the final documentation commit; it is not a claim about the repository after publication.

Use the provider SPEC and field tables for the latest consolidated interpretation. `MOBIREG-LEGACY-CORRECTIONS.md` and `mobireg-legacy.json` may say the modern password transform was unresolved at that earlier point. It was subsequently resolved in [modern auth recovery](MOBIREG-AUTH-RECOVERY.md): modern password login sends the selected original text, while legacy sends the MD5 digest. Do not merge the two credential formats.

The reports contain analyst-written summaries and code locations, not full vendor implementation. Native validation files in the Fryderyk subtree retain bounded instruction/reference checks. A passed reference check establishes consistency with the supplied artifact, not current service acceptance. To reproduce static research, obtain the exact original input identified by SHA256 and the tool versions in the provenance file; a different release requires a new evidence ledger.

Most useful reports:

* [Fryderyk auth, core and newer mail](FRYDERYK-RECOVERY.md)
* [MobiReg modern auth and gateway](MOBIREG-AUTH-RECOVERY.md)
* [MobiReg academic operations](MOBIREG-ACADEMIC-RECOVERY.md)
* [MobiReg mail and homework](MOBIREG-MODULE-RECOVERY.md)
* [Legacy corrections](MOBIREG-LEGACY-CORRECTIONS.md)

For remaining uncertainties, prefer the per-field/per-operation flags and runtime gates in the provider documentation over an old report's generic conclusion.
