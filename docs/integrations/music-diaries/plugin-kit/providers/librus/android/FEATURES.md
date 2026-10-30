# Librus Android feature inventory

This bounded checklist has **195 semantic feature rows**. It is not an endpoint count, an assertion of account permissions, or a claim of implementation. The accompanying [UI action index](ui-action-index.json) lists all **308 original Vue components** in this supplied app map, with event bindings and literal dispatch targets. Recovered wrapper/render modules are kept separate from original Vue source.

Read [feature-inventory.json](feature-inventory.json) for source hashes/map indices, gates and acceptance requirements. The rows intentionally include platform/local, external content and optional integration surfaces as well as diary data.

## account

| ID | Feature | Effect |
|---|---|---|
|LIB-UI-001|Authentication browser handoff|authentication-or-external-handoff|
|LIB-UI-002|Portal account login and cancellation|authentication-or-external-handoff|
|LIB-UI-003|Link additional Synergia account|read-or-local-ui|
|LIB-UI-004|Multiple linked diary accounts|read-or-local-ui|
|LIB-UI-005|Account repair and expired authorization|authentication-or-external-handoff|
|LIB-UI-006|Parent/student context separation|read-or-local-ui|
|LIB-UI-007|Logout and local session removal|read-or-local-ui|

## account-state

| ID | Feature | Effect |
|---|---|---|
|LIB-UI-008|Broken account recovery|read-or-local-ui|
|LIB-UI-009|Unactivated account explanation|read-or-local-ui|
|LIB-UI-010|Technical maintenance state|read-or-local-ui|
|LIB-UI-011|Missing linked account state|read-or-local-ui|
|LIB-UI-012|LibrusGO candidate account limitation|read-or-local-ui|

## timeline

| ID | Feature | Effect |
|---|---|---|
|LIB-UI-013|Combined chronological timeline|read-or-local-ui|
|LIB-UI-014|Per-account timeline filtering|read-or-local-ui|
|LIB-UI-015|Grouped and hidden categories|read-or-local-ui|
|LIB-UI-016|New versus changed versus deleted records|potential-network-mutation; verify concrete request recipe|
|LIB-UI-017|Open underlying detail from timeline|read-or-local-ui|
|LIB-UI-018|School-year transition entries|read-or-local-ui|
|LIB-UI-019|Offline timeline and retry|read-or-local-ui|
|LIB-UI-020|Monthly grade summary|read-or-local-ui|
|LIB-UI-021|Monthly grade trend summary|read-or-local-ui|

## grades

| ID | Feature | Effect |
|---|---|---|
|LIB-UI-022|Numeric standard grades|read-or-local-ui|
|LIB-UI-023|Point-based grades|read-or-local-ui|
|LIB-UI-024|Descriptive grades and comments|read-or-local-ui|
|LIB-UI-025|Text grades|read-or-local-ui|
|LIB-UI-026|Partial descriptive grades|read-or-local-ui|
|LIB-UI-027|Behaviour grades|read-or-local-ui|
|LIB-UI-028|Behaviour point grades|read-or-local-ui|
|LIB-UI-029|Behaviour proposal and assessment|read-or-local-ui|
|LIB-UI-030|Period and school-year selection|read-or-local-ui|
|LIB-UI-031|Subject-level grade details|read-or-local-ui|
|LIB-UI-032|Grade metadata and comments|read-or-local-ui|
|LIB-UI-033|Weighted averages when supplied|read-or-local-ui|
|LIB-UI-034|Period and subject averages|read-or-local-ui|
|LIB-UI-035|LibrusGO grade presentation|read-or-local-ui|

## attendance

| ID | Feature | Effect |
|---|---|---|
|LIB-UI-036|Attendance list grouped by date|read-or-local-ui|
|LIB-UI-037|Attendance detail and category|read-or-local-ui|
|LIB-UI-038|Attendance totals and percentages|read-or-local-ui|
|LIB-UI-039|Unknown/unrecorded versus absent attendance|read-or-local-ui|
|LIB-UI-040|Attendance change notifications|read-or-local-ui|

## justification

| ID | Feature | Effect |
|---|---|---|
|LIB-UI-041|List electronic justifications|read-or-local-ui|
|LIB-UI-042|Justification detail and status|read-or-local-ui|
|LIB-UI-043|Select lessons for justification|read-or-local-ui|
|LIB-UI-044|Create justification with reason|potential-network-mutation; verify concrete request recipe|
|LIB-UI-045|Report invalid or unavailable justification window|read-or-local-ui|

## timetable

| ID | Feature | Effect |
|---|---|---|
|LIB-UI-046|Week timetable navigation|read-or-local-ui|
|LIB-UI-047|Calendar event list and detail|read-or-local-ui|
|LIB-UI-048|Substitutions and cancellations|read-or-local-ui|
|LIB-UI-049|Original versus changed lesson data|read-or-local-ui|
|LIB-UI-050|Classroom and teacher details|read-or-local-ui|
|LIB-UI-051|Class/teacher/school free days|read-or-local-ui|
|LIB-UI-052|Parent-teacher conference events|read-or-local-ui|
|LIB-UI-053|Kindergarten framework day plan|read-or-local-ui|
|LIB-UI-054|Kindergarten timetable changes|read-or-local-ui|
|LIB-UI-055|Individual learning path timetable|read-or-local-ui|
|LIB-UI-056|One-to-one learning plan timetable|read-or-local-ui|
|LIB-UI-057|Other activities timetable|read-or-local-ui|
|LIB-UI-058|Custom timetable events|read-or-local-ui|
|LIB-UI-059|Create custom timetable event|potential-network-mutation; verify concrete request recipe|
|LIB-UI-060|Edit custom timetable event|potential-network-mutation; verify concrete request recipe|
|LIB-UI-061|Delete custom timetable event|potential-network-mutation; verify concrete request recipe|
|LIB-UI-062|Meal event overlay|read-or-local-ui|

## lessons

| ID | Feature | Effect |
|---|---|---|
|LIB-UI-063|Planned lesson list|read-or-local-ui|
|LIB-UI-064|Realized lesson list|read-or-local-ui|
|LIB-UI-065|Lesson topic and detail|read-or-local-ui|
|LIB-UI-066|Filter planned and realized lesson period|read-or-local-ui|

## homework

| ID | Feature | Effect |
|---|---|---|
|LIB-UI-067|Homework assignment list|read-or-local-ui|
|LIB-UI-068|Homework detail and rich content|read-or-local-ui|
|LIB-UI-069|Homework due dates and status|read-or-local-ui|
|LIB-UI-070|Read assignment attachments|read-or-local-ui|
|LIB-UI-071|Photo solution selection and upload|potential-network-mutation; verify concrete request recipe|
|LIB-UI-072|Solution submission availability and restrictions|read-or-local-ui|

## messages

| ID | Feature | Effect |
|---|---|---|
|LIB-UI-073|Inbox and sent folders|read-or-local-ui|
|LIB-UI-074|Message list and pagination|read-or-local-ui|
|LIB-UI-075|Message detail and read acknowledgement|read-may-change-server-state|
|LIB-UI-076|Recipient groups and subgroups|read-or-local-ui|
|LIB-UI-077|Recipient search and selection|read-or-local-ui|
|LIB-UI-078|Compose message|read-or-local-ui|
|LIB-UI-079|Reply to message|read-or-local-ui|
|LIB-UI-080|Delete message|potential-network-mutation; verify concrete request recipe|
|LIB-UI-081|Attachment display and download|read-or-local-ui|
|LIB-UI-082|Teacher off-duty banner and explanation|read-or-local-ui|
|LIB-UI-083|Attachment upload restrictions|potential-network-mutation; verify concrete request recipe|
|LIB-UI-084|Unread message counts|read-or-local-ui|

## announcements

| ID | Feature | Effect |
|---|---|---|
|LIB-UI-085|Announcement list|read-or-local-ui|
|LIB-UI-086|Announcement detail|read-or-local-ui|
|LIB-UI-087|Unread/new announcement presentation|read-or-local-ui|

## notes

| ID | Feature | Effect |
|---|---|---|
|LIB-UI-088|Notes list|read-or-local-ui|
|LIB-UI-089|Note detail and author|read-or-local-ui|
|LIB-UI-090|Positive/negative or categorized notes|read-or-local-ui|

## dashboard

| ID | Feature | Effect |
|---|---|---|
|LIB-UI-091|Dashboard module cards|read-or-local-ui|
|LIB-UI-092|Dashboard grades|read-or-local-ui|
|LIB-UI-093|Dashboard attendance|read-or-local-ui|
|LIB-UI-094|Dashboard homework|read-or-local-ui|
|LIB-UI-095|Dashboard messages|read-or-local-ui|
|LIB-UI-096|Dashboard notes|read-or-local-ui|
|LIB-UI-097|Dashboard announcements|read-or-local-ui|
|LIB-UI-098|Dashboard planned and realized lessons|read-or-local-ui|
|LIB-UI-099|Dashboard timetable|read-or-local-ui|

## school

| ID | Feature | Effect |
|---|---|---|
|LIB-UI-100|School details and contacts|read-or-local-ui|
|LIB-UI-101|Class and tutor information|read-or-local-ui|
|LIB-UI-102|LibrusGO additional school details|read-or-local-ui|

## lucky-number

| ID | Feature | Effect |
|---|---|---|
|LIB-UI-103|Lucky number current value|read-or-local-ui|
|LIB-UI-104|Lucky number timeline and notification|read-or-local-ui|

## goals

| ID | Feature | Effect |
|---|---|---|
|LIB-UI-105|Create personal grade goal|potential-network-mutation; verify concrete request recipe|
|LIB-UI-106|Edit personal grade goal|potential-network-mutation; verify concrete request recipe|
|LIB-UI-107|Subject selection for goal|read-or-local-ui|
|LIB-UI-108|Period-specific goal view|read-or-local-ui|
|LIB-UI-109|Grade potential and progress|read-or-local-ui|
|LIB-UI-110|Grade trend charts|read-or-local-ui|
|LIB-UI-111|Recent grade charts|read-or-local-ui|
|LIB-UI-112|Attendance chart|read-or-local-ui|
|LIB-UI-113|Unpreparedness per subject|read-or-local-ui|
|LIB-UI-114|Goal incentive timeline entries|read-or-local-ui|

## reminders

| ID | Feature | Effect |
|---|---|---|
|LIB-UI-115|Reminder list|read-or-local-ui|
|LIB-UI-116|Reminder detail|read-or-local-ui|
|LIB-UI-117|Create reminder|potential-network-mutation; verify concrete request recipe|
|LIB-UI-118|Edit reminder|potential-network-mutation; verify concrete request recipe|
|LIB-UI-119|Delete reminder|potential-network-mutation; verify concrete request recipe|
|LIB-UI-120|Predefined reminder times|read-or-local-ui|
|LIB-UI-121|Reminder timeline integration|read-or-local-ui|

## go-messages

| ID | Feature | Effect |
|---|---|---|
|LIB-UI-122|LibrusGO inbox and message detail|read-or-local-ui|
|LIB-UI-123|LibrusGO recipient selection|read-or-local-ui|
|LIB-UI-124|LibrusGO compose/reply|read-or-local-ui|
|LIB-UI-125|LibrusGO unread and read state|read-may-change-server-state|

## go-timetable

| ID | Feature | Effect |
|---|---|---|
|LIB-UI-126|LibrusGO lesson/event detail|read-or-local-ui|
|LIB-UI-127|LibrusGO report absence|potential-network-mutation; verify concrete request recipe|
|LIB-UI-128|LibrusGO cancel absence|potential-network-mutation; verify concrete request recipe|
|LIB-UI-129|LibrusGO available catch-up dates|read-or-local-ui|
|LIB-UI-130|LibrusGO request catch-up|potential-network-mutation; verify concrete request recipe|
|LIB-UI-131|LibrusGO cancel catch-up|potential-network-mutation; verify concrete request recipe|
|LIB-UI-132|LibrusGO lesson cycle detail|read-or-local-ui|

## go-documents

| ID | Feature | Effect |
|---|---|---|
|LIB-UI-133|LibrusGO document list|read-or-local-ui|
|LIB-UI-134|Document detail and fields|read-or-local-ui|
|LIB-UI-135|Document download|read-or-local-ui|
|LIB-UI-136|Document permissions state|read-or-local-ui|

## go-legal

| ID | Feature | Effect |
|---|---|---|
|LIB-UI-137|Legal approval decisions|read-or-local-ui|
|LIB-UI-138|Legal approval detail and fields|read-or-local-ui|
|LIB-UI-139|Submit approval decision|potential-network-mutation; verify concrete request recipe|
|LIB-UI-140|Approval history list and detail|read-or-local-ui|

## go-payments

| ID | Feature | Effect |
|---|---|---|
|LIB-UI-141|LibrusGO liabilities list|read-or-local-ui|
|LIB-UI-142|Payment detail and amounts|read-or-local-ui|
|LIB-UI-143|Payment provider handoff|authentication-or-external-handoff|
|LIB-UI-144|Payment status return and refresh|read-or-local-ui|

## meals

| ID | Feature | Effect |
|---|---|---|
|LIB-UI-145|Meal integration status|read-or-local-ui|
|LIB-UI-146|Meal calendar|read-or-local-ui|
|LIB-UI-147|Meal day detail|read-or-local-ui|
|LIB-UI-148|Meal selection and order actions|potential-network-mutation; verify concrete request recipe|
|LIB-UI-149|Meal balance display|read-or-local-ui|
|LIB-UI-150|Low balance timeline notifications|read-or-local-ui|
|LIB-UI-151|Meal unavailability and integration error|read-or-local-ui|

## school-photo

| ID | Feature | Effect |
|---|---|---|
|LIB-UI-152|School ID photo requirements and examples|read-or-local-ui|
|LIB-UI-153|Gallery or camera photo selection|read-or-local-ui|
|LIB-UI-154|Crop/prepare ID photo|read-or-local-ui|
|LIB-UI-155|Upload school ID photo|potential-network-mutation; verify concrete request recipe|
|LIB-UI-156|Uploaded photo status and details|potential-network-mutation; verify concrete request recipe|
|LIB-UI-157|Photo replacement/restriction feedback|read-or-local-ui|

## content

| ID | Feature | Effect |
|---|---|---|
|LIB-UI-158|Recommended articles|read-or-local-ui|
|LIB-UI-159|Article external opening|read-or-local-ui|
|LIB-UI-160|Subscription-gated content|read-or-local-ui|

## video

| ID | Feature | Effect |
|---|---|---|
|LIB-UI-161|Video material list|read-or-local-ui|
|LIB-UI-162|Video preview|read-or-local-ui|
|LIB-UI-163|Portrait video player|read-or-local-ui|
|LIB-UI-164|Playback controls and loading/error state|read-or-local-ui|

## settings

| ID | Feature | Effect |
|---|---|---|
|LIB-UI-165|Select theme and dark mode|read-or-local-ui|
|LIB-UI-166|Calendar display settings|read-or-local-ui|
|LIB-UI-167|Group/hide data categories|read-or-local-ui|
|LIB-UI-168|Select avatar icon|read-or-local-ui|
|LIB-UI-169|Select avatar photograph|read-or-local-ui|
|LIB-UI-170|Notification category preferences|read-or-local-ui|
|LIB-UI-171|LibrusGO notification preferences|read-or-local-ui|
|LIB-UI-172|Quiet night preferences|read-or-local-ui|
|LIB-UI-173|Ad display preference|read-or-local-ui|
|LIB-UI-174|Voucher activation|read-or-local-ui|
|LIB-UI-175|Subscription management|read-or-local-ui|
|LIB-UI-176|Add linked diary account|read-or-local-ui|
|LIB-UI-177|Force data refresh with cooldown|read-or-local-ui|
|LIB-UI-178|Change app language|read-or-local-ui|

## subscription

| ID | Feature | Effect |
|---|---|---|
|LIB-UI-179|Subscription slot list|read-or-local-ui|
|LIB-UI-180|Assign account to subscription slot|potential-network-mutation; verify concrete request recipe|
|LIB-UI-181|Deactivate assigned slot|potential-network-mutation; verify concrete request recipe|
|LIB-UI-182|Premium/plus/subscription explanation|read-or-local-ui|
|LIB-UI-183|Purchase flow state and receipt handling|read-or-local-ui|

## platform

| ID | Feature | Effect |
|---|---|---|
|LIB-UI-184|App version and update requirement|read-or-local-ui|
|LIB-UI-185|Help/support opening|read-or-local-ui|
|LIB-UI-186|External account settings opening|read-or-local-ui|
|LIB-UI-187|Accessibility labels and keyboard focus|read-or-local-ui|
|LIB-UI-188|Native clipboard|read-or-local-ui|
|LIB-UI-189|Native file/open/download handling|read-or-local-ui|
|LIB-UI-190|Offline/connectivity detection|read-or-local-ui|
|LIB-UI-191|Foreground resume update|read-or-local-ui|
|LIB-UI-192|Push click account routing|read-or-local-ui|
|LIB-UI-193|Notification permission handling|read-or-local-ui|
|LIB-UI-194|Crash/analytics integration boundary|read-or-local-ui|
|LIB-UI-195|Developer-only diagnostic page|read-or-local-ui|
