"""Generate compact analyst-authored, sanitized MobiReg handoff data."""
import csv
import json
import pathlib

import argparse
parser=argparse.ArgumentParser()
parser.add_argument("--output",type=pathlib.Path,required=True)
parser.add_argument("--source-reports",type=pathlib.Path,required=True)
args=parser.parse_args()
OUT=args.output.resolve()
OUT.mkdir(parents=True,exist_ok=True)
features = []


def feature(module, name, version, evidence, effect="read", contract="candidate", validate="Capture an authorized account response and verify shape, role visibility, empty/error states."):
    features.append({"id": f"MR-F{len(features)+1:03}", "module": module, "feature": name,
        "version": version, "evidence_refs": evidence, "effect": effect,
        "contract_status": contract, "next_validation": validate,
        "evidence_type": "decompiled-static" if evidence[0].startswith("MR-A") else "shipped-string-and-resource-static",
        "runtime_observed": False})


both = "Android 2.1.79 / iOS 3.1.7"
ios = "iOS 3.1.7"
android = "Android 2.1.79"
feature("accounts", "Add/edit/remove multiple school accounts and choose child", both, ["MR-A01", "MR-A02", "MR-I01"], "local-write", "partial")
feature("accounts", "School diary URL / school-code normalization", both, ["MR-A02", "MR-I01"], "local-write", "partial", "Verify accepted full school URL, bare code, trailing slash, subpath and validation errors; isolate host+school+login identities.")
feature("accounts", "Credential validation and ParentStudents discovery", android, ["MR-A02", "MR-A03"], "read", "recovered-static")
feature("accounts", "Password login storing JWT in secure storage", ios, ["MR-I01"], "session-write", "candidate", "Trace AuthService call flow or capture auth.php request, response envelope, token expiry and secure-storage behavior.")
feature("accounts", "QR-code login using code from web app", ios, ["MR-I01"], "session-write", "candidate", "Determine exact QR format and qrlogin.php body; verify expiration and reject malformed/external URLs.")
feature("accounts", "QR access+refresh sessions without saved password", ios, ["MR-I01"], "session-write", "candidate", "Verify account authType, access/refresh storage keys, refresh rotation, password-account QR update and revoked sessions.")
feature("accounts", "Silent refresh, unauthorized recovery and logout", ios, ["MR-I01"], "session-write", "candidate", "Recover refresh.php body, retry limit and response; verify no infinite 401 loop or duplicate mutation on auth retry.")
feature("accounts", "Remove account locally with its children, credentials and cache", ios, ["MR-I01"], "local-write", "partial", "Verify local removal versus logout; original diary account must remain. Verify cleanup for QR and password accounts.")
feature("accounts", "Student login includes self as pupil; rebuild pupil lists", ios, ["MR-I01"], "local-write", "candidate")
feature("dashboard", "Mixed dated feed of grades/exams/homework/reprimands/announcements/absences", ios, ["MR-I01"], "read")
feature("dashboard", "New/unread counters for grades, absences, reprimands and messages", android, ["MR-A07"], "read", "recovered-static")
feature("grades", "Subjects, term selection and grade details", both, ["MR-A06", "MR-I01"], "read", "partial")
feature("grades", "Current grades versus term/year/proposed/final grades", ios, ["MR-I01"], "read", "candidate", "Capture marks/terms app.php operations; map term hierarchy and proposed/final flags without flattening to ordinary grades.")
feature("grades", "Scale, numeric points, percentages and descriptive grading", android, ["MR-A06"], "read", "recovered-static", "Test server examples for types1/2/3/4, nonnumeric labels, min/max/precision and custom scales.")
feature("grades", "Grade categories, weights, comments, teacher, dates and styles", both, ["MR-A04", "MR-A06", "MR-I01"], "read", "partial")
feature("grades", "Grade parent/child correction chains and role visibility", android, ["MR-A06"], "read", "recovered-static", "Verify linked marks ordering, parent-only visibility2 and student-visible0; use only data authorized for current role.")
feature("grades", "Average-count exclusions and configurable numeric scales", android, ["MR-A04", "MR-A05"], "read", "partial", "Verify MarkScales.no_count_to_average and grade/group/category weight precedence before calculating averages.")
feature("grades", "Local new-grade indicator cleared by opening details", android, ["MR-A06", "MR-A07"], "local-write", "recovered-static")
feature("attendance", "Calendar/day list and per-event attendance details", both, ["MR-A07", "MR-I01"], "read", "partial")
feature("attendance", "Present/absent/late/custom classifications and statistics", both, ["MR-A07", "MR-I01"], "read", "partial", "Legacy count_as P/A/L wins; fallback IDs1/5/2 only if count_as missing. Verify modern absence code and stats schema.")
feature("attendance", "Filter absence-only or absence+late feed", ios, ["MR-I01"], "local-write", "partial")
feature("justifications", "Browse records and eligible events by week", ios, ["MR-I01"], "read")
feature("justifications", "Create/update/delete justification with event selection and reason", ios, ["MR-I01"], "server-write", "candidate", "Recover endpoint and HTTP method per action, event_ids/body/status schema, role permission and edit/delete windows before implementing writes.")
feature("timetable", "Day/calendar navigation across school-year range", both, ["MR-A07", "MR-I01"], "read", "partial")
feature("timetable", "Lesson time, number, subject, teachers, groups, rooms and topic details", both, ["MR-A04", "MR-A07", "MR-I01"], "read", "partial")
feature("timetable", "Substitution/original lesson relationship and changed plan", both, ["MR-A07", "MR-I01"], "read", "partial", "Legacy EventEvents relates original/replacement; verify Events.status/type/attr meaning with examples, school-wide plan changes and multi-teacher lessons.")
feature("timetable", "Timetable event and embedded exam details", ios, ["MR-I01"], "read")
feature("exams", "Exam list and detail with dates, subject and teacher", ios, ["MR-I01"], "read")
feature("homework", "Diary and module homework source compatibility", ios, ["MR-I01"], "read", "candidate", "Resolve HomeworkSource, getDiaryHomeworks/getModuleHomeworks and oldHomeworkModule negotiation; preserve source-specific IDs and sessions.")
feature("homework", "Homework list/detail/status/deadline and teacher comments", ios, ["MR-I01"], "read")
feature("homework", "Homework solution text and file submission", ios, ["MR-I01"], "server-write", "candidate", "Recover sendAnswer/uploadSolutionFile body, multipart field names, file limits, idempotency, answer readiness and partial success states.")
feature("homework", "Archive homework and restore archived homework", ios, ["MR-I01"], "server-write", "candidate", "Trace setArchived/toggleArchive; capture archive/restore endpoints and visibility; do not assume local-only archive.")
feature("announcements", "List/detail and delayed full-body fetch", ios, ["MR-I01"], "read")
feature("announcements", "Voting/answer submission and existing-answer state", ios, ["MR-I01"], "server-write", "candidate", "Recover announcement-answer operation, answer choices, userAnswer/canAnswer and server enforcement of closed poll.")
feature("announcements", "Pending poll gate and post-answer navigation", ios, ["MR-I01"], "read", "candidate", "Trace PendingPollGate/announcements-pending, required response order and cancellation; do not bypass an unanswered required poll.")
feature("reprimands", "Reprimands/praise list and detail with teacher/date/content", both, ["MR-A04", "MR-A07", "MR-I01"], "read", "partial")
feature("mail", "Message inbox/detail and local/server read acknowledgement", both, ["MR-A08", "MR-I01"], "server-write", "partial", "Legacy messages.php action=read,message_id recovered; modern /api/messages/read/ suffix HTTP verb/body unknown. Verify unread totals after acknowledgement.")
feature("mail", "Inbox/sent/important/trash folders and message search", ios, ["MR-I01"], "read")
feature("mail", "Compose/reply with recipient directory and search", ios, ["MR-I01"], "server-write", "candidate", "Recover receiver ID format, pagination/search, send/reply body, thread IDs, authorization and failed-send state.")
feature("mail", "Star/important state, move to trash and restore", ios, ["MR-I01"], "server-write", "candidate", "Literal spelling /stared is shipped; trace exact suffix/verb/body. Verify trash, restore and optimistic rollback.")
feature("mail", "Message attachments and upload partial-success reporting", ios, ["MR-I01"], "server-write", "candidate", "Recover upload endpoints/fields and per-file result; message sent without files must not be presented as complete success.")
feature("sessions", "Mail SSO and separate module/homework cookie sessions", ios, ["MR-I01"], "session-write", "candidate", "Trace /account/ssov2/, /sso, ModuleSession and MailSession. Scope cookies per account+host+module; handle missing-cookie responses.")
feature("media", "Pick attachments from files, camera and gallery", ios, ["MR-I01"], "local-write", "partial", "Verify allowed extensions/count/size, camera/gallery permissions, cancel and retry; generic MIME strings alone do not prove supported formats.")
feature("media", "Open/download/share attachments; renew expired homework URLs", ios, ["MR-I01"], "read", "candidate", "Verify signed-URL expiry, authorized URL refresh, redirects and sharing. Do not persist temporary URLs as durable IDs.")
feature("media", "Render HTML, links, images, video/audio and YouTube embeds", ios, ["MR-I01"], "read", "candidate", "AppHtmlFactory/YoutubeEmbed and composed HTML factories support renderer inference; verify actual sample content, sanitization, allowed URL schemes and playback behavior.")
feature("notifications", "FCM register/token refresh and per-account token registration", both, ["MR-A09", "MR-I01"], "server-write", "partial", "Legacy UploadTokenWork invokes njson.php with view=ParentStudents and token=<FCM token>. Modern register-fcm/unregister-fcm operation bodies unknown; use own Firebase project or polling until registration proven compatible.")
feature("notifications", "Message/grade/absence/reprimand/timetable notification kinds", both, ["MR-A09", "MR-I01"], "read", "partial")
feature("notifications", "Deep-link into correct account/child and invalidate relevant cache", both, ["MR-A09", "MR-I01"], "local-write", "partial", "Verify schoolCode,userId,accountName,noSync legacy fields; ignore notifications for absent accounts; don't route by unscoped numeric IDs.")
feature("notifications", "Notification center/preferences and server preference sync", ios, ["MR-I01"], "server-write", "candidate", "Recover notif-settings operation and preference granularity; respect OS permission separately from per-kind server flags.")
feature("sync", "Full/delta njson synchronization with rollback and server cursor", android, ["MR-A03", "MR-A04"], "local-write", "recovered-static", "Replay full/delta I/U/D, database-ID reset, malformed records, transaction rollback and server-time cursor behavior.")
feature("cache", "Per-child offline cache with freshness/retention/protocol metadata", ios, ["MR-I01"], "local-write", "partial", "Observe fresh/stale/offline/empty distinctions; segregate account and pupil in keys; deduplicate requests and reject late responses after child switch.")
feature("cache", "Manual clear cache and account-removal cleanup", both, ["MR-A10", "MR-I01"], "local-write", "partial")
feature("entitlements", "Server subscription/license expiry and sync-limit status", android, ["MR-A11"], "read", "recovered-static", "Map errno200/201 and MOBILE_SYNC permissions with grant/expiry; report entitlement restrictions without bypassing them.")
feature("settings", "App help/onboarding, support contact, version and store update", both, ["MR-A10", "MR-I01"], "local-write", "partial")
feature("settings", "Rotation and OS Wi-Fi/notification settings links", android, ["MR-A10"], "local-write", "recovered-static")
feature("settings", "Color skins, font size and high-contrast/WCAG mode", ios, ["MR-I01"], "local-write", "partial")
feature("settings", "Dashboard lookback weeks and attendance display preference", ios, ["MR-I01"], "local-write", "partial")
feature("compatibility", "Required app update on unsupported API protocol", ios, ["MR-I01"], "read", "candidate", "Recover supported protocol_v value/range and envelope handling; fail explicitly rather than parsing incompatible payloads.")
feature("support", "Legacy banner/help and subscription-limit explanation screens", android, ["MR-A10", "MR-A11"], "read", "partial", "Treat banner/update infrastructure as vendor support behavior, not diary data. Reuse Siberia support UX; preserve entitlement explanations.")
feature("development", "Developer-mode cache TTL controls and diagnostic build stamp", ios, ["MR-I01"], "local-write", "candidate", "Shipped developer strings establish candidate debug controls only; determine user reachability before recreating. Do not expose diagnostic data or raw tokens.")
feature("library-only", "Teacher-oriented grade/attendance/event export classes", android, ["MR-A04"], "server-write", "not-exposed", "Shared library contains13 export table mappings; no parent UI permission/call path establishes teacher writes. Do not enable these based on library presence.")

# The modern Android comparison is an evidence input, not an assumed version alias.
modern_comparison = args.source_reports / "modern-platform-comparison.json"
if modern_comparison.exists():
    comparison = json.loads(modern_comparison.read_text(encoding="utf8"))
    assert comparison["evidence_id"] == "MR-M01"
    for record in features:
        if "MR-I01" in record["evidence_refs"]:
            record["evidence_refs"].append("MR-M01")
            record["version"] = record["version"].replace("iOS 3.1.7", "Android 3.1.7 / iOS 3.1.7")
            record["platform_comparison_status"] = "Shared candidate surface corroborated by selected Android snapshot strings; no runtime parity asserted"
        else:
            record["platform_comparison_status"] = "Legacy-only contract or library boundary; not ported to modern profile"

(OUT / "features.json").write_text(json.dumps(features, ensure_ascii=False, indent=2), encoding="utf8")
with (OUT / "feature-matrix.csv").open("w", newline="", encoding="utf8") as f:
    writer = csv.DictWriter(f, fieldnames=list(features[0]))
    writer.writeheader()
    for row in features:
        writer.writerow({k: "; ".join(v) if isinstance(v, list) else v for k,v in row.items()})

protocol = {
    "schema_version": 1,
    "scope": "Supplied MobiReg music Android2.1.79, Android3.1.7 and iOS3.1.7; static analysis only",
    "legacy": {
        "evidence_refs": ["MR-A02", "MR-A03", "MR-A04", "MR-A08"],
        "base": "User's school diary URL with one trailing slash removed",
        "transport": {"method": "POST", "encoding": "application/x-www-form-urlencoded; UTF-8", "accepted_status": 200,
            "accept_encoding": "gzip,deflate", "gzip_response": True, "user_agent_pattern": "Andreg <device_id>", "client_timeout_ms": 120000},
        "common_fields": {"login": "app-level compatibility credential; inspect local SyncParameters constructor", "pass": "app-level compatibility credential; inspect local SyncParameters constructor", "device_id": "client device identifier", "app_version": "source client version code79", "parent_login": "user's diary login", "parent_pass": "user's diary password"},
        "endpoints": [
            {"path": "/modules/api/njson.php", "operation": "discover pupils", "fields": {"view": "ParentStudents"}, "response": {"ParentStudents": "array; id,name,surname,sex,phone from StudentModel"}, "status": "recovered-static"},
            {"path": "/modules/api/njson.php", "operation": "server settings", "fields": {"view": "Settings"}, "response": {"Settings": [{"id":"database identity", "protocol":"1.6.0", "time":"server cursor timestamp", "version":"server version", "permissions":"optional integer1 enables permission checks"}]}, "status":"recovered-static"},
            {"path": "/modules/api/njson.php", "operation": "full sync", "fields": {"start_date":"YYYY-MM-DD", "end_date":"YYYY-MM-DD", "get_all_mark_groups":"1", "student_id":"optional diary pupil ID"}, "response": "named table arrays; see android-field-mapping.json", "status":"recovered-static"},
            {"path": "/modules/api/njson.php", "operation": "delta sync", "fields": {"start_date":"YYYY-MM-DD", "end_date":"YYYY-MM-DD", "last_end_date":"previous range end YYYY-MM-DD", "lmt":"server lastSyncTime YYYY-MM-DD hh:mm:ss", "get_all_mark_groups":"1", "student_id":"optional diary pupil ID"}, "response":"named table arrays with action I/U/D", "status":"recovered-static"},
            {"path": "/modules/api/messages.php", "operation": "mark message read", "fields":{"action":"read", "message_id":"integer ID"}, "response":"Retrofit Unit; status/body semantics beyond transport unverified", "status":"recovered-static"},
            {"path": "/modules/api/njson.php", "operation": "register FCM token", "fields":{"view":"ParentStudents", "token":"FCM token"}, "status":"recovered-static"},
            {"path": "/modules/api/schedules.php", "operation":"subject DB version", "fields":{"get_version":""}, "status":"shared-library declaration; user reachability not established"}
        ],
        "error_envelope": {"object":"{errno: integer, message: string}", "also_seen_static":"CommunicationManager accepts single-element array wrapping an error object", "login_codes":[101,102,105,106,107], "license_expired":200,"sync_limit":201},
        "sync_rules": ["Require settings protocol exactly1.6.0 for this legacy decoder", "Delta allowed only when local cache valid and server settings id equals lastSyncID", "Full-sync source window is now minus100 through plus100 days", "Atomic transaction applies tables then updates cursor from server Settings.time", "Default action I; I replaces existing ID, U updates or inserts missing ID, D removes if present", "Server id maps to local _id in import mappings", "Keep source payload; unknown tables must be consumed/skipped safely", "Do not upload shared-library export tables through parent read-only feature adapters"]
    },
    "modern": {
        "evidence_refs":["MR-I01"], "status":"literal/model/screen evidence; HTTP verbs, headers, body shapes and call graph not yet recovered",
        "auth_paths":["/modules/api/auth.php","/modules/api/refresh.php","/modules/api/qrlogin.php"],
        "operation_gateway":"/modules/api/app.php",
        "gateway_operation_candidates":["register-fcm","unregister-fcm","notif-settings","announcements-pending","announcement-answer","attendance-stats","justification-events","homework-status","timetable-events","homework-module","homeworks-module"],
        "mail_path_literals":["/api/messages","/api/messages/inbox","/api/messages/sent","/api/messages/important","/api/messages/trash","/api/messages/","/api/messages/read/","/api/messages/receivers","/api/messages/receivers/search","/api/unreadMessages"],
        "suffix_literals_unbound":["/stared","/restore","/archive","/files"],
        "homework_path_literals":["/api/homeworks/datatable","/api/homeworks/"],
        "sso_path_literals":["/account/ssov2/","/sso"],
        "routing_literals_not_api_proof":["/justifications","/justifications/","/justifications?pupil_id=","/homeworks","/homeworks/","/timetable","/timetable/details","/announcements","/exams","/reprimands"],
        "candidate_transport_keys":["Authorization","authorization","JWTToken","token","messages_token","pupil_id","event_ids","schoolCode","api_page_address","messaging_url","protocol_v"],
        "session_design_observations":["JWT credential store", "password and QR authentication types", "access+refresh described in shipped log", "MailSession cookie and separate ModuleSession/homeworkSession cookies", "account-specific FCM registration"],
        "unknowns":["Exact login/refresh/QR form or JSON bodies", "JWT scheme/expiry/refresh rotation", "Gateway operation selector field and envelopes", "Supported protocol_v values", "Mail/module SSO host selection/cookie names/redirect lifecycle", "All mutation HTTP methods and payloads", "Pagination/filtering/sorting", "Attachment upload constraints and partial-success semantics", "Per-school roles and permissions"]
    }
}
if modern_comparison.exists():
    protocol["modern"]["evidence_refs"].append("MR-M01")
    protocol["modern"]["platforms"] = ["Android3.1.7 build116 revision6f4e7b8", "iOS3.1.7 build116 revisiond20dd8d"]
    protocol["modern"]["comparison"] = "modern-platform-comparison.json; shared candidate literals, not call-flow equivalence"
(OUT / "protocol.json").write_text(json.dumps(protocol, ensure_ascii=False, indent=2), encoding="utf8")
print(f"Wrote {len(features)} feature records and protocol.json")
