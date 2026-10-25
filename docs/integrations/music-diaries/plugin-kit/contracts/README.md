# Structured request references

[operations.json](operations.json) is a navigational index into the preserved static ledgers and newer provider records using JSON Pointer. It is not an executable request planner. It includes auth/generic transport variants as well as concrete module actions, so its record count must not be reported as a count of unique endpoints or features. Legacy selectors/fields and local operations are documented separately in the MobiReg specification.

The original ledgers are checkpoints. Prefer the latest provider SPEC, field tables and supplemental evidence when an old `remaining` or `limitations` entry has subsequently been resolved. For example, Fryderyk reply/replyAll/forward enum names are now byte-validated in [enum instance evidence](../providers/fryderyk/evidence/enum-instance-values.json), and gateway `users` discovery is now in [MobiReg discovery](../providers/mobireg/discovery-auth.json). Earlier broad uncertainty does not invalidate the later narrower proof.

Each indexed record identifies its original version scope. A GET with a read-state side effect remains an effectful operation even when its method is GET. Every record remains unverified against a live backend.
