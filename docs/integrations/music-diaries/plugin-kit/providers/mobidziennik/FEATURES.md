# mobiDziennik feature coverage

These50 analyst-defined rows distinguish recovered shell contracts from server-delivered academic behavior. No row is marked implemented/live-tested. Source fact IDs resolve in evidence.json; full acceptance and gap details are in features.json. Read CAPTURE-PLAN.md before enabling route-only academic actions.

| ID | Module / feature | Evidence status | Operation / source |
|---|---|---|---|
| MD-UI-001 | auth: Email/password sign-in | static contract | MD-AUTH-LOGIN / MD-F09 |
| MD-UI-002 | auth: Password reset request | static contract | MD-RESET / MD-F13 |
| MD-UI-003 | auth: Device authorization waiting/retry | static contract | MD-AUTH-DEVICE / MD-F14 |
| MD-UI-004 | auth: Biometric re-entry gate | localcapability | No concrete wire contract / MD-F17 |
| MD-UI-005 | auth: Password unlock fallback | static contract | MD-AUTH-UNLOCK / MD-F16 |
| MD-UI-006 | auth: Mandatory password-change route | remotecontractmissing | No concrete wire contract / MD-F33 |
| MD-UI-007 | account: Linked school account switching | static shell | MD-SYNC / MD-F41 |
| MD-UI-008 | account: School year and main-account context | static shell | MD-SYNC / MD-F47 |
| MD-UI-009 | account: Parent/student/teacher/director/outside roles | static rolecodes | No concrete wire contract / MD-F42 |
| MD-UI-010 | account: Local logout and retained cache | localcapability | MD-PUSH-DISABLE / MD-F48 |
| MD-UI-011 | sync: Initial school bootstrap | static contract | MD-SYNC / MD-F28 |
| MD-UI-012 | sync: Manual refresh with10s throttle | static contract | MD-SYNC / MD-F19 |
| MD-UI-013 | sync: Resume refresh after60minutes | static shell | MD-SYNC / MD-F18 |
| MD-UI-014 | sync: Draft-preserving resume exclusions | static shell | No concrete wire contract / MD-F52 |
| MD-UI-015 | sync: Pending lesson/form synchronization | static contract | MD-SYNC-OUTBOX / MD-F23 |
| MD-UI-016 | sync: Single-flight completion semantics | observed sourcequirk | MD-SYNC / MD-F20 |
| MD-UI-017 | sync: Credential rotation | static contract | MD-SYNC / MD-F25 |
| MD-UI-018 | sync: Businesserror/session/device flags | static contract | MD-SYNC / MD-F26 |
| MD-UI-019 | sync: Reconnect behavior | bounded local | No concrete wire contract / MD-F56 |
| MD-UI-020 | storage: Cached school templates/pages | static storage | No concrete wire contract / MD-F29 |
| MD-UI-021 | storage: Chunked template persistence | static storage | No concrete wire contract / MD-F43 |
| MD-UI-022 | storage: SQLite schema migrations | static storage | No concrete wire contract / MD-F46 |
| MD-UI-023 | storage: Inactive account cleanup | static storage | No concrete wire contract / MD-F49 |
| MD-UI-024 | navigation: Local shell/static pages | localcapability | MD-LOCAL-PAGE / MD-F31 |
| MD-UI-025 | navigation: Remote route query/detail grammar | static shell | No concrete wire contract / MD-F32 |
| MD-UI-026 | navigation: Missing-template recovery/default route | static shell | MD-SYNC / MD-F35 |
| MD-UI-027 | grades: Grade list/detail and semester | route only | No concrete wire contract / MD-F40 |
| MD-UI-028 | grades: Final grade view | route only | No concrete wire contract / MD-F40 |
| MD-UI-029 | stats: Requested grade and attendance statistics | requestedcapabilitynotestablished | No concrete wire contract / MD-F28 |
| MD-UI-030 | attendance: Attendance page | route/panel only | No concrete wire contract / MD-F52 |
| MD-UI-031 | justification: Electronic absence justification | panel only | No concrete wire contract / MD-F52 |
| MD-UI-032 | messages: Inbox/detail via notification | route only | No concrete wire contract / MD-F40 |
| MD-UI-033 | messages: Compose draft | route only | No concrete wire contract / MD-F54 |
| MD-UI-034 | homework: Current homework and answer | route only | No concrete wire contract / MD-F53 |
| MD-UI-035 | homework: Archived homework | route only | No concrete wire contract / MD-F40 |
| MD-UI-036 | tests: Upcoming test/exam page | route only | No concrete wire contract / MD-F40 |
| MD-UI-037 | behavior: Behavior grade and notes | route only | No concrete wire contract / MD-F40 |
| MD-UI-038 | teacher: Lesson editing/unsent lesson guard | teacher shellonly | No concrete wire contract / MD-F22 |
| MD-UI-039 | forms: Generic controller dispatch | static wrapper | MD-FORM / MD-F36 |
| MD-UI-040 | files: Generic blob response transport | static wrapper | MD-FORM-BLOB / MD-F06 |
| MD-UI-041 | files: Native file save/open support | localplugin capability | No concrete wire contract / MD-F51 |
| MD-UI-042 | files: Camera/photo integration | declared pluginonly | No concrete wire contract / MD-F58 |
| MD-UI-043 | push: Permission/token registration | static wrapper | MD-PUSH-REGISTER / MD-F39 |
| MD-UI-044 | push: Global owner notification disable | static contract | MD-PUSH-DISABLE / MD-F38 |
| MD-UI-045 | push: Tapped notification routing | static shell | No concrete wire contract / MD-F40 |
| MD-UI-046 | push: Account-specific device page | route only | No concrete wire contract / MD-F41 |
| MD-UI-047 | preferences: Dark/light/system theme | localcapability | No concrete wire contract / MD-F57 |
| MD-UI-048 | preferences: System text scaling | localcapability | No concrete wire contract / MD-F55 |
| MD-UI-049 | diagnostics: Local logs and errorqueue | localcapability | No concrete wire contract / MD-F08 |
| MD-UI-050 | navigation: Back/menu/history | localcapability | No concrete wire contract / MD-F31 |
