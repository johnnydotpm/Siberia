# Prymus field declarations

These are static Gson/Java declarations. Read MODEL-MAPPING for semantic ownership and source defaults. Unannotated fields may be local state rather than server data.

| Model | Wire/default name | Java type | Annotation | Source line |
|---|---|---|---|---|
| Announcement | `UserName` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/Announcement.java:10 |
| Announcement | `Date` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/Announcement.java:13 |
| Announcement | `Description` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/Announcement.java:16 |
| Announcement | `ExternalId` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/Announcement.java:19 |
| Announcement | `ForParent` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/Announcement.java:22 |
| Announcement | `ForStudent` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/Announcement.java:25 |
| Announcement | `id` | `int` | default/local candidate | pl/bialystok/zeto/prymus/database/Announcement.java:27 |
| Announcement | `Important` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/Announcement.java:29 |
| Announcement | `LinkToFile` | `List<String>` | SerializedName | pl/bialystok/zeto/prymus/database/Announcement.java:32 |
| Announcement | `ReadDate` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/Announcement.java:35 |
| Announcement | `StudentId` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/Announcement.java:38 |
| Announcement | `Title` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/Announcement.java:41 |
| AnnouncementRead | `announcementExternalId` | `String` | default/local candidate | pl/bialystok/zeto/prymus/database/AnnouncementRead.java:5 |
| AnnouncementRead | `id` | `int` | default/local candidate | pl/bialystok/zeto/prymus/database/AnnouncementRead.java:6 |
| AnnouncementRead | `readDate` | `String` | default/local candidate | pl/bialystok/zeto/prymus/database/AnnouncementRead.java:7 |
| AnnouncementRead | `studentExternalId` | `String` | default/local candidate | pl/bialystok/zeto/prymus/database/AnnouncementRead.java:8 |
| ApplicationSettings | `AppMode` | `int` | SerializedName | pl/bialystok/zeto/prymus/database/ApplicationSettings.java:9 |
| ApplicationSettings | `ChoosePlatform` | `int` | SerializedName | pl/bialystok/zeto/prymus/database/ApplicationSettings.java:12 |
| ApplicationSettings | `ChooseVersion` | `int` | SerializedName | pl/bialystok/zeto/prymus/database/ApplicationSettings.java:15 |
| ApplicationSettings | `DateOfShowedChatDialog` | `Long` | SerializedName | pl/bialystok/zeto/prymus/database/ApplicationSettings.java:18 |
| ApplicationSettings | `Dinners` | `byte` | SerializedName | pl/bialystok/zeto/prymus/database/ApplicationSettings.java:21 |
| ApplicationSettings | `helper` | `boolean` | default/local candidate | pl/bialystok/zeto/prymus/database/ApplicationSettings.java:23 |
| ApplicationSettings | `id` | `int` | default/local candidate | pl/bialystok/zeto/prymus/database/ApplicationSettings.java:24 |
| ApplicationSettings | `ParentMode` | `byte` | SerializedName | pl/bialystok/zeto/prymus/database/ApplicationSettings.java:26 |
| ApplicationSettings | `PlatformType` | `byte` | SerializedName | pl/bialystok/zeto/prymus/database/ApplicationSettings.java:29 |
| ApplicationSettings | `PremiumForTests` | `int` | SerializedName | pl/bialystok/zeto/prymus/database/ApplicationSettings.java:32 |
| ApplicationSettings | `ReceivingNotification` | `byte` | SerializedName | pl/bialystok/zeto/prymus/database/ApplicationSettings.java:35 |
| ApplicationSettings | `ReceivingNotificationAttendance` | `byte` | SerializedName | pl/bialystok/zeto/prymus/database/ApplicationSettings.java:38 |
| ApplicationSettings | `ReceivingNotificationChat` | `int` | SerializedName | pl/bialystok/zeto/prymus/database/ApplicationSettings.java:41 |
| ApplicationSettings | `ReceivingNotificationCurfew` | `byte` | SerializedName | pl/bialystok/zeto/prymus/database/ApplicationSettings.java:44 |
| ApplicationSettings | `ReceivingNotificationMarks` | `byte` | SerializedName | pl/bialystok/zeto/prymus/database/ApplicationSettings.java:47 |
| ApplicationSettings | `ReceivingNotificationNever` | `byte` | SerializedName | pl/bialystok/zeto/prymus/database/ApplicationSettings.java:50 |
| ApplicationSettings | `ReceivingNotificationOnSaturday` | `byte` | SerializedName | pl/bialystok/zeto/prymus/database/ApplicationSettings.java:53 |
| ApplicationSettings | `ReceivingNotificationOnWorkingDays` | `byte` | SerializedName | pl/bialystok/zeto/prymus/database/ApplicationSettings.java:56 |
| ApplicationSettings | `ReceivingNotificationOnlineTasks` | `byte` | SerializedName | pl/bialystok/zeto/prymus/database/ApplicationSettings.java:59 |
| ApplicationSettings | `ReceivingNotificationRemarks` | `byte` | SerializedName | pl/bialystok/zeto/prymus/database/ApplicationSettings.java:62 |
| ApplicationSettings | `ShowDialogWithDinnerMenu` | `byte` | SerializedName | pl/bialystok/zeto/prymus/database/ApplicationSettings.java:65 |
| ApplicationSettings | `ShowDialogWithDinners2DaysBefore` | `byte` | SerializedName | pl/bialystok/zeto/prymus/database/ApplicationSettings.java:68 |
| ApplicationSettings | `ShowDialogWithDinners3DaysBefore` | `byte` | SerializedName | pl/bialystok/zeto/prymus/database/ApplicationSettings.java:71 |
| ApplicationSettings | `ShowDialogWithDinners5DaysBefore` | `byte` | SerializedName | pl/bialystok/zeto/prymus/database/ApplicationSettings.java:74 |
| ApplicationSettings | `ShowDialogWithDinnersDayBefore` | `byte` | SerializedName | pl/bialystok/zeto/prymus/database/ApplicationSettings.java:77 |
| ApplicationSettings | `ShowDialogWithPackUp` | `byte` | SerializedName | pl/bialystok/zeto/prymus/database/ApplicationSettings.java:80 |
| ApplicationSettings | `ShowDialogWithTestsAndTasks` | `byte` | SerializedName | pl/bialystok/zeto/prymus/database/ApplicationSettings.java:83 |
| ApplicationSettings | `ShowDialogWithWeather` | `byte` | SerializedName | pl/bialystok/zeto/prymus/database/ApplicationSettings.java:86 |
| ApplicationSettings | `ShowDialogWithWf` | `byte` | SerializedName | pl/bialystok/zeto/prymus/database/ApplicationSettings.java:89 |
| ApplicationSettings | `VersionType` | `byte` | SerializedName | pl/bialystok/zeto/prymus/database/ApplicationSettings.java:92 |
| AppVersionInformation | `AppVersion` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/AppVersionInformation.java:8 |
| AppVersionInformation | `id` | `int` | default/local candidate | pl/bialystok/zeto/prymus/database/AppVersionInformation.java:10 |
| Attendances | `AbsenceDate` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/Attendances.java:8 |
| Attendances | `Comment` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/Attendances.java:11 |
| Attendances | `ExcusedAbsenceStatus` | `byte` | SerializedName | pl/bialystok/zeto/prymus/database/Attendances.java:14 |
| Attendances | `ExcusedDate` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/Attendances.java:17 |
| Attendances | `ExternalId` | `int` | SerializedName | pl/bialystok/zeto/prymus/database/Attendances.java:20 |
| Attendances | `id` | `int` | default/local candidate | pl/bialystok/zeto/prymus/database/Attendances.java:22 |
| Attendances | `LatenessStatus` | `byte` | SerializedName | pl/bialystok/zeto/prymus/database/Attendances.java:24 |
| Attendances | `LessonNumber` | `int` | SerializedName | pl/bialystok/zeto/prymus/database/Attendances.java:27 |
| Attendances | `SchoolSubject` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/Attendances.java:30 |
| Attendances | `SchoolYear` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/Attendances.java:33 |
| Attendances | `StudentId` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/Attendances.java:36 |
| Attendances | `TermShortcut` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/Attendances.java:39 |
| Attendances | `TimeFrom` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/Attendances.java:42 |
| Attendances | `TimeTo` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/Attendances.java:45 |
| Attendances | `UserFirstName` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/Attendances.java:48 |
| Attendances | `UserLastName` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/Attendances.java:51 |
| AttendanceStatistic | `ExternalId` | `Integer` | SerializedName | pl/bialystok/zeto/prymus/database/AttendanceStatistic.java:8 |
| AttendanceStatistic | `id` | `int` | default/local candidate | pl/bialystok/zeto/prymus/database/AttendanceStatistic.java:10 |
| AttendanceStatistic | `PercentageMonthPresence` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/AttendanceStatistic.java:12 |
| AttendanceStatistic | `PercentageSchoolYearPresence` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/AttendanceStatistic.java:15 |
| AttendanceStatistic | `PercentageTermPresence` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/AttendanceStatistic.java:18 |
| AttendanceStatistic | `SchoolYear` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/AttendanceStatistic.java:21 |
| AttendanceStatistic | `StudentId` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/AttendanceStatistic.java:24 |
| AttendanceStatistic | `TermShortcut` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/AttendanceStatistic.java:27 |
| Book | `Author` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/Book.java:9 |
| Book | `Date` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/Book.java:12 |
| Book | `ExternalId` | `int` | SerializedName | pl/bialystok/zeto/prymus/database/Book.java:15 |
| Book | `id` | `int` | default/local candidate | pl/bialystok/zeto/prymus/database/Book.java:17 |
| Book | `PublishedHouse` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/Book.java:19 |
| Book | `Remark` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/Book.java:22 |
| Book | `SchoolSubject` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/Book.java:25 |
| Book | `SchoolYear` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/Book.java:28 |
| Book | `StudentId` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/Book.java:31 |
| Book | `TermShortcut` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/Book.java:34 |
| Book | `Title` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/Book.java:37 |
| ChatMessage | `Files` | `List<ChatAttachment>` | SerializedName | pl/bialystok/zeto/prymus/database/ChatMessage.java:20 |
| ChatMessage | `Name` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/ChatMessage.java:23 |
| ChatMessage | `UserId` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/ChatMessage.java:26 |
| ChatMessage | `DateLong` | `Long` | SerializedName | pl/bialystok/zeto/prymus/database/ChatMessage.java:29 |
| ChatMessage | `ExternalId` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/ChatMessage.java:32 |
| ChatMessage | `id` | `int` | default/local candidate | pl/bialystok/zeto/prymus/database/ChatMessage.java:34 |
| ChatMessage | `IsRead` | `byte` | SerializedName | pl/bialystok/zeto/prymus/database/ChatMessage.java:36 |
| ChatMessage | `Message` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/ChatMessage.java:39 |
| ChatMessage | `Recipient` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/ChatMessage.java:42 |
| ChatMessage | `Title` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/ChatMessage.java:45 |
| ChatMessage | `ChatGroupId` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/ChatMessage.java:48 |
| ChatMessage.ChatAttachment | `nazwaPlikuUzytkownika` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/ChatMessage.java:237 |
| ChatMessage.ChatAttachment | `unikalnaNazwa` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/ChatMessage.java:240 |
| ChatMessage.ChatAttachment | `url` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/ChatMessage.java:243 |
| ChatSettings | `id` | `int` | default/local candidate | pl/bialystok/zeto/prymus/database/ChatSettings.java:7 |
| ChatSettings | `BrokerLogin` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/ChatSettings.java:9 |
| ChatSettings | `BrokerPassword` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/ChatSettings.java:12 |
| ChatSettings | `studentId` | `String` | default/local candidate | pl/bialystok/zeto/prymus/database/ChatSettings.java:14 |
| ChatTeacherId | `id` | `int` | default/local candidate | pl/bialystok/zeto/prymus/database/ChatTeacherId.java:7 |
| ChatTeacherId | `studentId` | `String` | default/local candidate | pl/bialystok/zeto/prymus/database/ChatTeacherId.java:8 |
| ChatTeacherId | `TeacherId` | `int` | SerializedName | pl/bialystok/zeto/prymus/database/ChatTeacherId.java:10 |
| DeletedTasks | `deletionDate` | `String` | default/local candidate | pl/bialystok/zeto/prymus/database/DeletedTasks.java:5 |
| DeletedTasks | `externalId` | `String` | default/local candidate | pl/bialystok/zeto/prymus/database/DeletedTasks.java:6 |
| DeletedTasks | `id` | `int` | default/local candidate | pl/bialystok/zeto/prymus/database/DeletedTasks.java:7 |
| DeletedTasks | `studentId` | `String` | default/local candidate | pl/bialystok/zeto/prymus/database/DeletedTasks.java:8 |
| Faq | `androidVersion` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/Faq.java:9 |
| Faq | `appVersion` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/Faq.java:12 |
| Faq | `content` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/Faq.java:15 |
| Faq | `date` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/Faq.java:18 |
| Faq | `displayMode` | `int` | SerializedName | pl/bialystok/zeto/prymus/database/Faq.java:21 |
| Faq | `guid` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/Faq.java:24 |
| Faq | `id` | `int` | default/local candidate | pl/bialystok/zeto/prymus/database/Faq.java:26 |
| Faq | `parentMode` | `int` | SerializedName | pl/bialystok/zeto/prymus/database/Faq.java:28 |
| Faq | `premium` | `int` | SerializedName | pl/bialystok/zeto/prymus/database/Faq.java:31 |
| Faq | `priority` | `int` | SerializedName | pl/bialystok/zeto/prymus/database/Faq.java:34 |
| Faq | `order` | `int` | SerializedName | pl/bialystok/zeto/prymus/database/Faq.java:37 |
| Faq | `title` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/Faq.java:40 |
| Faq | `type` | `int` | SerializedName | pl/bialystok/zeto/prymus/database/Faq.java:43 |
| FaqRead | `faqGuid` | `String` | default/local candidate | pl/bialystok/zeto/prymus/database/FaqRead.java:5 |
| FaqRead | `id` | `int` | default/local candidate | pl/bialystok/zeto/prymus/database/FaqRead.java:6 |
| Favourites | `category` | `String` | default/local candidate | pl/bialystok/zeto/prymus/database/Favourites.java:5 |
| Favourites | `id` | `int` | default/local candidate | pl/bialystok/zeto/prymus/database/Favourites.java:6 |
| Favourites | `objectExternalId` | `String` | default/local candidate | pl/bialystok/zeto/prymus/database/Favourites.java:7 |
| Favourites | `studentExternalId` | `String` | default/local candidate | pl/bialystok/zeto/prymus/database/Favourites.java:8 |
| Helper | `fragmentName` | `String` | default/local candidate | pl/bialystok/zeto/prymus/database/Helper.java:5 |
| Helper | `id` | `int` | default/local candidate | pl/bialystok/zeto/prymus/database/Helper.java:6 |
| JustifiedAttendances | `AbsenceDate` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/JustifiedAttendances.java:8 |
| JustifiedAttendances | `Content` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/JustifiedAttendances.java:11 |
| JustifiedAttendances | `ExternalIds` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/JustifiedAttendances.java:14 |
| JustifiedAttendances | `id` | `int` | default/local candidate | pl/bialystok/zeto/prymus/database/JustifiedAttendances.java:16 |
| JustifiedAttendances | `SendDate` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/JustifiedAttendances.java:18 |
| JustifiedAttendances | `StudentId` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/JustifiedAttendances.java:21 |
| Lessons | `id` | `int` | default/local candidate | pl/bialystok/zeto/prymus/database/Lessons.java:7 |
| Lessons | `LessonNumber` | `int` | SerializedName | pl/bialystok/zeto/prymus/database/Lessons.java:9 |
| Lessons | `StudentId` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/Lessons.java:12 |
| Lessons | `TimeFrom` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/Lessons.java:15 |
| Lessons | `TimeTo` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/Lessons.java:18 |
| License | `expirationDate` | `String` | default/local candidate | pl/bialystok/zeto/prymus/database/License.java:5 |
| License | `id` | `int` | default/local candidate | pl/bialystok/zeto/prymus/database/License.java:6 |
| License | `license` | `int` | default/local candidate | pl/bialystok/zeto/prymus/database/License.java:7 |
| License | `licenseSended` | `boolean` | default/local candidate | pl/bialystok/zeto/prymus/database/License.java:8 |
| License | `paymentDate` | `String` | default/local candidate | pl/bialystok/zeto/prymus/database/License.java:9 |
| License | `token` | `String` | default/local candidate | pl/bialystok/zeto/prymus/database/License.java:10 |
| Mark | `Category` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/Mark.java:9 |
| Mark | `Color` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/Mark.java:12 |
| Mark | `Comment` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/Mark.java:15 |
| Mark | `CorrectMarkDate` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/Mark.java:18 |
| Mark | `ExternalId` | `int` | SerializedName | pl/bialystok/zeto/prymus/database/Mark.java:21 |
| Mark | `id` | `int` | default/local candidate | pl/bialystok/zeto/prymus/database/Mark.java:23 |
| Mark | `IncludeToAverage` | `byte` | SerializedName | pl/bialystok/zeto/prymus/database/Mark.java:25 |
| Mark | `Mark` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/Mark.java:28 |
| Mark | `PreviousMark` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/Mark.java:31 |
| Mark | `ReceivedDate` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/Mark.java:34 |
| Mark | `SchoolSubject` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/Mark.java:37 |
| Mark | `SchoolSubjectShortcut` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/Mark.java:40 |
| Mark | `SchoolYear` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/Mark.java:43 |
| Mark | `StudentId` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/Mark.java:46 |
| Mark | `TeacherFirstName` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/Mark.java:49 |
| Mark | `TeacherLastName` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/Mark.java:52 |
| Mark | `TermShortcut` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/Mark.java:55 |
| Mark | `Weight` | `double` | SerializedName | pl/bialystok/zeto/prymus/database/Mark.java:58 |
| MarkAverage | `ClassMark` | `byte` | SerializedName | pl/bialystok/zeto/prymus/database/MarkAverage.java:8 |
| MarkAverage | `id` | `int` | default/local candidate | pl/bialystok/zeto/prymus/database/MarkAverage.java:10 |
| MarkAverage | `Mark` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/MarkAverage.java:12 |
| MarkAverage | `SchoolSubject` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/MarkAverage.java:15 |
| MarkAverage | `SchoolYear` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/MarkAverage.java:18 |
| MarkAverage | `StudentId` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/MarkAverage.java:21 |
| MarkAverage | `TermShortcut` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/MarkAverage.java:24 |
| MarkAverage | `Type` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/MarkAverage.java:27 |
| MarkFinal | `ExternalId` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/MarkFinal.java:8 |
| MarkFinal | `id` | `int` | default/local candidate | pl/bialystok/zeto/prymus/database/MarkFinal.java:10 |
| MarkFinal | `Mark` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/MarkFinal.java:12 |
| MarkFinal | `ProposedMark` | `byte` | SerializedName | pl/bialystok/zeto/prymus/database/MarkFinal.java:15 |
| MarkFinal | `SchoolSubject` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/MarkFinal.java:18 |
| MarkFinal | `SchoolYear` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/MarkFinal.java:21 |
| MarkFinal | `StudentId` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/MarkFinal.java:24 |
| MarkFinal | `TermShortcut` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/MarkFinal.java:27 |
| MarkFinal | `Type` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/MarkFinal.java:30 |
| MarkRead | `id` | `int` | default/local candidate | pl/bialystok/zeto/prymus/database/MarkRead.java:5 |
| MarkRead | `mark` | `String` | default/local candidate | pl/bialystok/zeto/prymus/database/MarkRead.java:6 |
| MarkRead | `markExternalId` | `int` | default/local candidate | pl/bialystok/zeto/prymus/database/MarkRead.java:7 |
| MarkRead | `studentExternalId` | `String` | default/local candidate | pl/bialystok/zeto/prymus/database/MarkRead.java:8 |
| MarkRead | `studentFirstName` | `String` | default/local candidate | pl/bialystok/zeto/prymus/database/MarkRead.java:9 |
| MarkRead | `studentLastName` | `String` | default/local candidate | pl/bialystok/zeto/prymus/database/MarkRead.java:10 |
| MarkResults | `AllStudentMarks` | `List<AllStudentsMarks>` | SerializedName | pl/bialystok/zeto/prymus/database/MarkResults.java:9 |
| MarkResults | `id` | `int` | default/local candidate | pl/bialystok/zeto/prymus/database/MarkResults.java:11 |
| MarkResults | `MarkAreaId` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/MarkResults.java:13 |
| MarkResults | `MarkExternalId` | `int` | SerializedName | pl/bialystok/zeto/prymus/database/MarkResults.java:16 |
| MarkResults | `StudentId` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/MarkResults.java:19 |
| MarkResults.AllStudentsMarks | `Count` | `int` | SerializedName | pl/bialystok/zeto/prymus/database/MarkResults.java:64 |
| MarkResults.AllStudentsMarks | `Mark` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/MarkResults.java:67 |
| NewFeature | `displayed` | `int` | default/local candidate | pl/bialystok/zeto/prymus/database/NewFeature.java:5 |
| NewFeature | `elementId` | `int` | default/local candidate | pl/bialystok/zeto/prymus/database/NewFeature.java:6 |
| NewFeature | `fragmentName` | `String` | default/local candidate | pl/bialystok/zeto/prymus/database/NewFeature.java:7 |
| NewFeature | `gravity` | `int` | default/local candidate | pl/bialystok/zeto/prymus/database/NewFeature.java:8 |
| NewFeature | `id` | `int` | default/local candidate | pl/bialystok/zeto/prymus/database/NewFeature.java:9 |
| NewFeature | `message` | `String` | default/local candidate | pl/bialystok/zeto/prymus/database/NewFeature.java:10 |
| NewFeature | `version` | `String` | default/local candidate | pl/bialystok/zeto/prymus/database/NewFeature.java:11 |
| News | `Category` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/News.java:9 |
| News | `CreateDate` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/News.java:12 |
| News | `DateFrom` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/News.java:15 |
| News | `DateFromInMs` | `long` | SerializedName | pl/bialystok/zeto/prymus/database/News.java:18 |
| News | `DateTo` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/News.java:21 |
| News | `DateToInMs` | `long` | SerializedName | pl/bialystok/zeto/prymus/database/News.java:24 |
| News | `Description` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/News.java:27 |
| News | `ExternalId` | `int` | SerializedName | pl/bialystok/zeto/prymus/database/News.java:30 |
| News | `id` | `int` | default/local candidate | pl/bialystok/zeto/prymus/database/News.java:32 |
| News | `Name` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/News.java:34 |
| News | `PersonEnteringDataFirstName` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/News.java:37 |
| News | `PersonEnteringDataLastName` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/News.java:40 |
| News | `SchoolYear` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/News.java:43 |
| News | `StudentId` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/News.java:46 |
| News | `TermShortcut` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/News.java:49 |
| Notes | `Content` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/Notes.java:8 |
| Notes | `ExternalId` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/Notes.java:11 |
| Notes | `id` | `int` | default/local candidate | pl/bialystok/zeto/prymus/database/Notes.java:13 |
| Notes | `StudentId` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/Notes.java:15 |
| Notes | `TeacherId` | `int` | SerializedName | pl/bialystok/zeto/prymus/database/Notes.java:18 |
| Notification | `Attachments` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/Notification.java:9 |
| Notification | `Body` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/Notification.java:12 |
| Notification | `Category` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/Notification.java:15 |
| Notification | `id` | `int` | default/local candidate | pl/bialystok/zeto/prymus/database/Notification.java:17 |
| Notification | `MessageId` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/Notification.java:19 |
| Notification | `readDate` | `String` | default/local candidate | pl/bialystok/zeto/prymus/database/Notification.java:21 |
| Notification | `ReceivedDate` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/Notification.java:23 |
| Notification | `StudentToken` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/Notification.java:26 |
| Notification | `Teacher` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/Notification.java:29 |
| Notification | `TeacherId` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/Notification.java:32 |
| Notification | `Title` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/Notification.java:35 |
| OnlineLesson | `date` | `String` | default/local candidate | pl/bialystok/zeto/prymus/database/OnlineLesson.java:10 |
| OnlineLesson | `id` | `int` | default/local candidate | pl/bialystok/zeto/prymus/database/OnlineLesson.java:11 |
| OnlineLesson | `lessonName` | `String` | default/local candidate | pl/bialystok/zeto/prymus/database/OnlineLesson.java:12 |
| OnlineLesson | `studentId` | `String` | default/local candidate | pl/bialystok/zeto/prymus/database/OnlineLesson.java:13 |
| OnlineLesson | `taskId` | `String` | default/local candidate | pl/bialystok/zeto/prymus/database/OnlineLesson.java:14 |
| OnlineLesson | `teacherName` | `String` | default/local candidate | pl/bialystok/zeto/prymus/database/OnlineLesson.java:15 |
| OnlineLesson | `timeFrom` | `Long` | default/local candidate | pl/bialystok/zeto/prymus/database/OnlineLesson.java:16 |
| OnlineLesson | `timeFromString` | `String` | default/local candidate | pl/bialystok/zeto/prymus/database/OnlineLesson.java:17 |
| OnlineLesson | `timeTo` | `Long` | default/local candidate | pl/bialystok/zeto/prymus/database/OnlineLesson.java:18 |
| OnlineLesson | `timeToString` | `String` | default/local candidate | pl/bialystok/zeto/prymus/database/OnlineLesson.java:19 |
| Parent | `externalId` | `String` | default/local candidate | pl/bialystok/zeto/prymus/database/Parent.java:5 |
| Parent | `firstName` | `String` | default/local candidate | pl/bialystok/zeto/prymus/database/Parent.java:6 |
| Parent | `id` | `int` | default/local candidate | pl/bialystok/zeto/prymus/database/Parent.java:7 |
| Parent | `lastName` | `String` | default/local candidate | pl/bialystok/zeto/prymus/database/Parent.java:8 |
| Parent | `parentId` | `String` | default/local candidate | pl/bialystok/zeto/prymus/database/Parent.java:9 |
| Parent | `studentId` | `String` | default/local candidate | pl/bialystok/zeto/prymus/database/Parent.java:10 |
| ParentMode | `Id` | `int` | default/local candidate | pl/bialystok/zeto/prymus/database/ParentMode.java:8 |
| ParentMode | `IsOn` | `boolean` | SerializedName | pl/bialystok/zeto/prymus/database/ParentMode.java:10 |
| ParentMode | `PIN` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/ParentMode.java:13 |
| ParentMode | `ParentId` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/ParentMode.java:16 |
| PremiumLogs | `date` | `String` | default/local candidate | pl/bialystok/zeto/prymus/database/PremiumLogs.java:5 |
| PremiumLogs | `id` | `int` | default/local candidate | pl/bialystok/zeto/prymus/database/PremiumLogs.java:6 |
| PremiumLogs | `message` | `String` | default/local candidate | pl/bialystok/zeto/prymus/database/PremiumLogs.java:7 |
| PremiumLogs | `orderId` | `String` | default/local candidate | pl/bialystok/zeto/prymus/database/PremiumLogs.java:8 |
| PremiumLogs | `productToken` | `String` | default/local candidate | pl/bialystok/zeto/prymus/database/PremiumLogs.java:9 |
| PremiumLogs | `status` | `String` | default/local candidate | pl/bialystok/zeto/prymus/database/PremiumLogs.java:10 |
| PremiumLogs | `tokens` | `String` | default/local candidate | pl/bialystok/zeto/prymus/database/PremiumLogs.java:11 |
| ReadNotSendedObject | `category` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/ReadNotSendedObject.java:8 |
| ReadNotSendedObject | `count` | `int` | SerializedName | pl/bialystok/zeto/prymus/database/ReadNotSendedObject.java:11 |
| ReadNotSendedObject | `id` | `int` | default/local candidate | pl/bialystok/zeto/prymus/database/ReadNotSendedObject.java:13 |
| ReadNotSendedObject | `objectId` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/ReadNotSendedObject.java:15 |
| ReadNotSendedObject | `readDate` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/ReadNotSendedObject.java:18 |
| ReadNotSendedObject | `token` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/ReadNotSendedObject.java:21 |
| Remark | `Date` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/Remark.java:9 |
| Remark | `Description` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/Remark.java:12 |
| Remark | `ExternalId` | `int` | SerializedName | pl/bialystok/zeto/prymus/database/Remark.java:15 |
| Remark | `id` | `int` | default/local candidate | pl/bialystok/zeto/prymus/database/Remark.java:17 |
| Remark | `ReadDate` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/Remark.java:19 |
| Remark | `SchoolYear` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/Remark.java:22 |
| Remark | `Status` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/Remark.java:25 |
| Remark | `StudentId` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/Remark.java:28 |
| Remark | `TeacherFirstName` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/Remark.java:31 |
| Remark | `TeacherLastName` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/Remark.java:34 |
| Remark | `TermShortcut` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/Remark.java:37 |
| RemarkRead | `id` | `int` | default/local candidate | pl/bialystok/zeto/prymus/database/RemarkRead.java:5 |
| RemarkRead | `readDate` | `String` | default/local candidate | pl/bialystok/zeto/prymus/database/RemarkRead.java:6 |
| RemarkRead | `remarkExternalId` | `int` | default/local candidate | pl/bialystok/zeto/prymus/database/RemarkRead.java:7 |
| RemarkRead | `studentExternalId` | `String` | default/local candidate | pl/bialystok/zeto/prymus/database/RemarkRead.java:8 |
| Replacement | `Date` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/Replacement.java:9 |
| Replacement | `ExternalId` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/Replacement.java:12 |
| Replacement | `id` | `int` | default/local candidate | pl/bialystok/zeto/prymus/database/Replacement.java:14 |
| Replacement | `LessonNumber` | `int` | SerializedName | pl/bialystok/zeto/prymus/database/Replacement.java:16 |
| Replacement | `ReplacementTeacherFirstName` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/Replacement.java:19 |
| Replacement | `ReplacementTeacherLastName` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/Replacement.java:22 |
| Replacement | `SchoolSubject` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/Replacement.java:25 |
| Replacement | `studentId` | `String` | default/local candidate | pl/bialystok/zeto/prymus/database/Replacement.java:27 |
| Replacement | `TimeFrom` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/Replacement.java:29 |
| Replacement | `TimeTo` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/Replacement.java:32 |
| SchoolInformation | `City` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/SchoolInformation.java:8 |
| SchoolInformation | `Email` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/SchoolInformation.java:11 |
| SchoolInformation | `FullName` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/SchoolInformation.java:14 |
| SchoolInformation | `id` | `int` | default/local candidate | pl/bialystok/zeto/prymus/database/SchoolInformation.java:16 |
| SchoolInformation | `Name` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/SchoolInformation.java:18 |
| SchoolInformation | `Number` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/SchoolInformation.java:21 |
| SchoolInformation | `Phone` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/SchoolInformation.java:24 |
| SchoolInformation | `PostalCode` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/SchoolInformation.java:27 |
| SchoolInformation | `PostalCodeCity` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/SchoolInformation.java:30 |
| SchoolInformation | `Province` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/SchoolInformation.java:33 |
| SchoolInformation | `Street` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/SchoolInformation.java:36 |
| SchoolInformation | `StudentFirstName` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/SchoolInformation.java:39 |
| SchoolInformation | `StudentId` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/SchoolInformation.java:42 |
| SchoolInformation | `StudentLastName` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/SchoolInformation.java:45 |
| SchoolInformation | `UnitName` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/SchoolInformation.java:48 |
| ScoringRemark | `CreatedDate` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/ScoringRemark.java:8 |
| ScoringRemark | `ExternalId` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/ScoringRemark.java:11 |
| ScoringRemark | `id` | `int` | default/local candidate | pl/bialystok/zeto/prymus/database/ScoringRemark.java:13 |
| ScoringRemark | `Message` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/ScoringRemark.java:15 |
| ScoringRemark | `Points` | `int` | SerializedName | pl/bialystok/zeto/prymus/database/ScoringRemark.java:18 |
| ScoringRemark | `RemarkId` | `Integer` | SerializedName | pl/bialystok/zeto/prymus/database/ScoringRemark.java:21 |
| ScoringRemark | `studentId` | `String` | default/local candidate | pl/bialystok/zeto/prymus/database/ScoringRemark.java:23 |
| Stats | `Id` | `int` | default/local candidate | pl/bialystok/zeto/prymus/database/Stats.java:7 |
| Stats | `count` | `int` | SerializedName | pl/bialystok/zeto/prymus/database/Stats.java:9 |
| Stats | `mark` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/Stats.java:12 |
| Student | `ActualSchoolYear` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/Student.java:10 |
| Student | `ActualTermShortcut` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/Student.java:13 |
| Student | `Avatar` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/Student.java:16 |
| Student | `BehaviorActualPoints` | `Integer` | SerializedName | pl/bialystok/zeto/prymus/database/Student.java:19 |
| Student | `BehaviorStartingPoints` | `Integer` | SerializedName | pl/bialystok/zeto/prymus/database/Student.java:22 |
| Student | `UserId` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/Student.java:25 |
| Student | `DateOfPayment` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/Student.java:28 |
| Student | `DiaryNumber` | `int` | SerializedName | pl/bialystok/zeto/prymus/database/Student.java:31 |
| Student | `Dinners` | `byte` | SerializedName | pl/bialystok/zeto/prymus/database/Student.java:34 |
| Student | `ExternalId` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/Student.java:37 |
| Student | `FirstName` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/Student.java:40 |
| Student | `hasParentMessages` | `boolean` | default/local candidate | pl/bialystok/zeto/prymus/database/Student.java:42 |
| Student | `id` | `int` | default/local candidate | pl/bialystok/zeto/prymus/database/Student.java:43 |
| Student | `inactive` | `int` | default/local candidate | pl/bialystok/zeto/prymus/database/Student.java:44 |
| Student | `IpAddress` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/Student.java:46 |
| Student | `IsPaid` | `byte` | SerializedName | pl/bialystok/zeto/prymus/database/Student.java:49 |
| Student | `IsScoringSystem` | `boolean` | SerializedName | pl/bialystok/zeto/prymus/database/Student.java:52 |
| Student | `LastName` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/Student.java:55 |
| Student | `lastUpdateDate` | `String` | default/local candidate | pl/bialystok/zeto/prymus/database/Student.java:57 |
| Student | `License` | `int` | SerializedName | pl/bialystok/zeto/prymus/database/Student.java:59 |
| Student | `Login` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/Student.java:62 |
| Student | `LuckyNumber` | `int` | SerializedName | pl/bialystok/zeto/prymus/database/Student.java:65 |
| Student | `PIN` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/Student.java:68 |
| Student | `ResetDeviceDate` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/Student.java:71 |
| Student | `SchoolClass` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/Student.java:74 |
| Student | `SchoolName` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/Student.java:77 |
| Student | `Sex` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/Student.java:80 |
| Student | `token` | `String` | default/local candidate | pl/bialystok/zeto/prymus/database/Student.java:82 |
| TaskAnswer | `Attachments` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/TaskAnswer.java:9 |
| TaskAnswer | `ExternalId` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/TaskAnswer.java:12 |
| TaskAnswer | `id` | `int` | default/local candidate | pl/bialystok/zeto/prymus/database/TaskAnswer.java:14 |
| TaskAnswer | `Message` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/TaskAnswer.java:16 |
| TaskAnswer | `ReplyDate` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/TaskAnswer.java:19 |
| TaskAnswer | `StudentId` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/TaskAnswer.java:22 |
| TaskAnswer | `TaskId` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/TaskAnswer.java:25 |
| Tasks | `Attachments` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/Tasks.java:9 |
| Tasks | `Completed` | `boolean` | SerializedName | pl/bialystok/zeto/prymus/database/Tasks.java:12 |
| Tasks | `CreateDate` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/Tasks.java:15 |
| Tasks | `Deadline` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/Tasks.java:18 |
| Tasks | `ExternalId` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/Tasks.java:21 |
| Tasks | `id` | `int` | default/local candidate | pl/bialystok/zeto/prymus/database/Tasks.java:23 |
| Tasks | `Message` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/Tasks.java:25 |
| Tasks | `ReadDate` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/Tasks.java:28 |
| Tasks | `Reply` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/Tasks.java:31 |
| Tasks | `ReplyAttachments` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/Tasks.java:34 |
| Tasks | `ReplyDate` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/Tasks.java:37 |
| Tasks | `SchoolYear` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/Tasks.java:40 |
| Tasks | `StudentId` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/Tasks.java:43 |
| Tasks | `Teacher` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/Tasks.java:46 |
| Tasks | `Title` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/Tasks.java:49 |
| TasksRead | `id` | `int` | default/local candidate | pl/bialystok/zeto/prymus/database/TasksRead.java:5 |
| TasksRead | `readDate` | `String` | default/local candidate | pl/bialystok/zeto/prymus/database/TasksRead.java:6 |
| TasksRead | `studentExternalId` | `String` | default/local candidate | pl/bialystok/zeto/prymus/database/TasksRead.java:7 |
| TasksRead | `taskExternalId` | `String` | default/local candidate | pl/bialystok/zeto/prymus/database/TasksRead.java:8 |
| Teacher | `Educator` | `byte` | SerializedName | pl/bialystok/zeto/prymus/database/Teacher.java:8 |
| Teacher | `ExternalId` | `int` | SerializedName | pl/bialystok/zeto/prymus/database/Teacher.java:11 |
| Teacher | `FirstName` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/Teacher.java:14 |
| Teacher | `id` | `int` | default/local candidate | pl/bialystok/zeto/prymus/database/Teacher.java:16 |
| Teacher | `LastName` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/Teacher.java:18 |
| Teacher | `SchoolYear` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/Teacher.java:21 |
| Teacher | `StudentFirstName` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/Teacher.java:24 |
| Teacher | `StudentId` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/Teacher.java:27 |
| Teacher | `StudentLastName` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/Teacher.java:30 |
| Teacher | `Subject` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/Teacher.java:33 |
| Teacher | `TermShortcut` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/Teacher.java:36 |
| Timetable | `Date` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/Timetable.java:9 |
| Timetable | `DayName` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/Timetable.java:12 |
| Timetable | `ExternalId` | `int` | SerializedName | pl/bialystok/zeto/prymus/database/Timetable.java:15 |
| Timetable | `Group` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/Timetable.java:18 |
| Timetable | `id` | `int` | default/local candidate | pl/bialystok/zeto/prymus/database/Timetable.java:20 |
| Timetable | `InClassRegister` | `byte` | SerializedName | pl/bialystok/zeto/prymus/database/Timetable.java:22 |
| Timetable | `LessonNumber` | `int` | SerializedName | pl/bialystok/zeto/prymus/database/Timetable.java:25 |
| Timetable | `Room` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/Timetable.java:28 |
| Timetable | `SchoolSubject` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/Timetable.java:31 |
| Timetable | `SchoolYear` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/Timetable.java:34 |
| Timetable | `StudentId` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/Timetable.java:37 |
| Timetable | `SupportTeacherFirstName` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/Timetable.java:40 |
| Timetable | `SupportTeacherLastName` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/Timetable.java:43 |
| Timetable | `TeacherFirstName` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/Timetable.java:46 |
| Timetable | `TeacherLastName` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/Timetable.java:49 |
| Timetable | `TermShortcut` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/Timetable.java:52 |
| Timetable | `TimeFrom` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/Timetable.java:55 |
| Timetable | `TimeTo` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/Timetable.java:58 |
| Tip | `count` | `int` | default/local candidate | pl/bialystok/zeto/prymus/database/Tip.java:5 |
| Tip | `description` | `String` | default/local candidate | pl/bialystok/zeto/prymus/database/Tip.java:6 |
| Tip | `englishDescription` | `String` | default/local candidate | pl/bialystok/zeto/prymus/database/Tip.java:7 |
| Tip | `id` | `int` | default/local candidate | pl/bialystok/zeto/prymus/database/Tip.java:8 |
| Tip | `isDisplay` | `boolean` | default/local candidate | pl/bialystok/zeto/prymus/database/Tip.java:9 |
| Tip | `tipVersion` | `int` | default/local candidate | pl/bialystok/zeto/prymus/database/Tip.java:10 |
| Topic | `countOfPeople` | `int` | SerializedName | pl/bialystok/zeto/prymus/database/Topic.java:9 |
| Topic | `ExternalId` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/Topic.java:12 |
| Topic | `ForParents` | `boolean` | SerializedName | pl/bialystok/zeto/prymus/database/Topic.java:15 |
| Topic | `id` | `int` | default/local candidate | pl/bialystok/zeto/prymus/database/Topic.java:17 |
| Topic | `ChatGroupName` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/Topic.java:19 |
| Topic | `studentId` | `String` | default/local candidate | pl/bialystok/zeto/prymus/database/Topic.java:21 |
| Topic | `UnreadNumber` | `int` | SerializedName | pl/bialystok/zeto/prymus/database/Topic.java:23 |
| Topic | `Topic` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/Topic.java:26 |
| User | `FirstName` | `String` | default/local candidate | pl/bialystok/zeto/prymus/database/User.java:5 |
| User | `Id` | `int` | default/local candidate | pl/bialystok/zeto/prymus/database/User.java:6 |
| User | `IsLog` | `byte` | default/local candidate | pl/bialystok/zeto/prymus/database/User.java:7 |
| User | `LastLoginDate` | `String` | default/local candidate | pl/bialystok/zeto/prymus/database/User.java:8 |
| User | `LastName` | `String` | default/local candidate | pl/bialystok/zeto/prymus/database/User.java:9 |
| User | `LastStudent` | `String` | default/local candidate | pl/bialystok/zeto/prymus/database/User.java:10 |
| User | `Login` | `String` | default/local candidate | pl/bialystok/zeto/prymus/database/User.java:11 |
| User | `Password` | `String` | default/local candidate | pl/bialystok/zeto/prymus/database/User.java:12 |
| User | `PasswordValidDate` | `String` | default/local candidate | pl/bialystok/zeto/prymus/database/User.java:13 |
| User | `SchoolYear` | `String` | default/local candidate | pl/bialystok/zeto/prymus/database/User.java:14 |
| User | `Term` | `String` | default/local candidate | pl/bialystok/zeto/prymus/database/User.java:15 |
| User | `Token` | `String` | default/local candidate | pl/bialystok/zeto/prymus/database/User.java:16 |
| User | `Type` | `String` | default/local candidate | pl/bialystok/zeto/prymus/database/User.java:17 |
| UserActivityLog | `AndroidVersion` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/UserActivityLog.java:9 |
| UserActivityLog | `AppVersion` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/UserActivityLog.java:12 |
| UserActivityLog | `Date` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/UserActivityLog.java:15 |
| UserActivityLog | `DeviceBrand` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/UserActivityLog.java:18 |
| UserActivityLog | `DeviceModel` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/UserActivityLog.java:21 |
| UserActivityLog | `DeviceUuid` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/UserActivityLog.java:24 |
| UserActivityLog | `Error` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/UserActivityLog.java:27 |
| UserActivityLog | `ErrorType` | `int` | SerializedName | pl/bialystok/zeto/prymus/database/UserActivityLog.java:30 |
| UserActivityLog | `Fragment` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/UserActivityLog.java:33 |
| UserActivityLog | `id` | `int` | default/local candidate | pl/bialystok/zeto/prymus/database/UserActivityLog.java:35 |
| UserActivityLog | `sentData` | `String` | default/local candidate | pl/bialystok/zeto/prymus/database/UserActivityLog.java:36 |
| UserInformation | `Id` | `int` | default/local candidate | pl/bialystok/zeto/prymus/database/UserInformation.java:7 |
| UserInformation | `AcceptRegulaminDate` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/UserInformation.java:9 |
| UserInformation | `AcceptRodoDate` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/UserInformation.java:12 |
| UserInformation | `actualVersion` | `boolean` | default/local candidate | pl/bialystok/zeto/prymus/database/UserInformation.java:14 |
| UserInformation | `dateDisplayLuckyNumber` | `String` | default/local candidate | pl/bialystok/zeto/prymus/database/UserInformation.java:15 |
| UserInformation | `dateOfLastLog` | `String` | default/local candidate | pl/bialystok/zeto/prymus/database/UserInformation.java:16 |
| UserInformation | `dateReminderPackUp` | `String` | default/local candidate | pl/bialystok/zeto/prymus/database/UserInformation.java:17 |
| UserInformation | `dateReminderTests` | `String` | default/local candidate | pl/bialystok/zeto/prymus/database/UserInformation.java:18 |
| UserInformation | `IsAcceptRODO` | `boolean` | SerializedName | pl/bialystok/zeto/prymus/database/UserInformation.java:20 |
| UserInformation | `IsAcceptRegulamin` | `boolean` | SerializedName | pl/bialystok/zeto/prymus/database/UserInformation.java:23 |
| UserInformation | `justificationDialog` | `int` | default/local candidate | pl/bialystok/zeto/prymus/database/UserInformation.java:25 |
| UserInformation | `LastSyncDate` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/UserInformation.java:27 |
| UserInformation | `NextTime` | `byte` | SerializedName | pl/bialystok/zeto/prymus/database/UserInformation.java:30 |
| UserInformation | `Opinion` | `byte` | SerializedName | pl/bialystok/zeto/prymus/database/UserInformation.java:33 |
| UserInformation | `OpinionReminderDate` | `String` | SerializedName | pl/bialystok/zeto/prymus/database/UserInformation.java:36 |
| UserInformation | `tipVersion` | `int` | SerializedName | pl/bialystok/zeto/prymus/database/UserInformation.java:39 |
| ActiveParentModeModel | `activationCode` | `String` | default/local candidate | pl/bialystok/zeto/prymus/models/requests/ActiveParentModeModel.java:5 |
| ActiveParentModeModel | `apiVersion` | `int` | default/local candidate | pl/bialystok/zeto/prymus/models/requests/ActiveParentModeModel.java:6 |
| ActiveParentModeModel | `mobileId` | `String` | default/local candidate | pl/bialystok/zeto/prymus/models/requests/ActiveParentModeModel.java:7 |
| ActiveParentModeModel | `securityToken` | `String` | default/local candidate | pl/bialystok/zeto/prymus/models/requests/ActiveParentModeModel.java:8 |
| ActiveParentModeModel | `token` | `String` | default/local candidate | pl/bialystok/zeto/prymus/models/requests/ActiveParentModeModel.java:9 |
| ActiveParentModeModel | `type` | `int` | default/local candidate | pl/bialystok/zeto/prymus/models/requests/ActiveParentModeModel.java:10 |
| ChangeLicenseForTokensModel | `license` | `int` | default/local candidate | pl/bialystok/zeto/prymus/models/requests/ChangeLicenseForTokensModel.java:5 |
| ChangeLicenseForTokensModel | `paymentDate` | `String` | default/local candidate | pl/bialystok/zeto/prymus/models/requests/ChangeLicenseForTokensModel.java:6 |
| ChangeLicenseForTokensModel | `securityToken` | `String` | default/local candidate | pl/bialystok/zeto/prymus/models/requests/ChangeLicenseForTokensModel.java:7 |
| ChangeLicenseForTokensModel | `token` | `String` | default/local candidate | pl/bialystok/zeto/prymus/models/requests/ChangeLicenseForTokensModel.java:8 |
| ChangeLicenseForTokensModel | `tokensToUpgrade` | `String` | default/local candidate | pl/bialystok/zeto/prymus/models/requests/ChangeLicenseForTokensModel.java:9 |
| CommunicationModuleMessage | `attachments` | `List<String>` | default/local candidate | pl/bialystok/zeto/prymus/models/requests/CommunicationModuleMessage.java:7 |
| CommunicationModuleMessage | `chatType` | `int` | default/local candidate | pl/bialystok/zeto/prymus/models/requests/CommunicationModuleMessage.java:8 |
| CommunicationModuleMessage | `content` | `String` | default/local candidate | pl/bialystok/zeto/prymus/models/requests/CommunicationModuleMessage.java:9 |
| CommunicationModuleMessage | `extensions` | `List<String>` | default/local candidate | pl/bialystok/zeto/prymus/models/requests/CommunicationModuleMessage.java:10 |
| CommunicationModuleMessage | `fileNames` | `List<String>` | default/local candidate | pl/bialystok/zeto/prymus/models/requests/CommunicationModuleMessage.java:11 |
| CommunicationModuleMessage | `parentId` | `String` | default/local candidate | pl/bialystok/zeto/prymus/models/requests/CommunicationModuleMessage.java:12 |
| CommunicationModuleMessage | `recipientId` | `String` | default/local candidate | pl/bialystok/zeto/prymus/models/requests/CommunicationModuleMessage.java:13 |
| CommunicationModuleMessage | `title` | `String` | default/local candidate | pl/bialystok/zeto/prymus/models/requests/CommunicationModuleMessage.java:14 |
| CommunicationModuleMessage | `topicUuid` | `String` | default/local candidate | pl/bialystok/zeto/prymus/models/requests/CommunicationModuleMessage.java:15 |
| CreateTopicWithTeacherModel | `securityToken` | `String` | default/local candidate | pl/bialystok/zeto/prymus/models/requests/CreateTopicWithTeacherModel.java:5 |
| CreateTopicWithTeacherModel | `teacherId` | `String` | default/local candidate | pl/bialystok/zeto/prymus/models/requests/CreateTopicWithTeacherModel.java:6 |
| CreateTopicWithTeacherModel | `token` | `String` | default/local candidate | pl/bialystok/zeto/prymus/models/requests/CreateTopicWithTeacherModel.java:7 |
| CreateTopicWithTeacherModel | `userId` | `String` | default/local candidate | pl/bialystok/zeto/prymus/models/requests/CreateTopicWithTeacherModel.java:8 |
| DataToSend | `mobileId` | `String` | SerializedName | pl/bialystok/zeto/prymus/models/requests/DataToSend.java:9 |
| DataToSend | `securityToken` | `String` | SerializedName | pl/bialystok/zeto/prymus/models/requests/DataToSend.java:12 |
| DataToSend | `token` | `String` | SerializedName | pl/bialystok/zeto/prymus/models/requests/DataToSend.java:15 |
| ErrorLog | `appVersion` | `String` | SerializedName | pl/bialystok/zeto/prymus/models/requests/ErrorLog.java:8 |
| ErrorLog | `date` | `String` | SerializedName | pl/bialystok/zeto/prymus/models/requests/ErrorLog.java:11 |
| ErrorLog | `Error` | `String` | SerializedName | pl/bialystok/zeto/prymus/models/requests/ErrorLog.java:14 |
| ErrorLog | `Fragment` | `String` | SerializedName | pl/bialystok/zeto/prymus/models/requests/ErrorLog.java:17 |
| ErrorLog | `mobileId` | `String` | SerializedName | pl/bialystok/zeto/prymus/models/requests/ErrorLog.java:20 |
| GetApiResponseModel | `apiVersion` | `int` | default/local candidate | pl/bialystok/zeto/prymus/models/requests/GetApiResponseModel.java:5 |
| GetApiResponseModel | `fcmToken` | `String` | default/local candidate | pl/bialystok/zeto/prymus/models/requests/GetApiResponseModel.java:6 |
| GetApiResponseModel | `mobileId` | `String` | default/local candidate | pl/bialystok/zeto/prymus/models/requests/GetApiResponseModel.java:7 |
| GetApiResponseModel | `securityToken` | `String` | default/local candidate | pl/bialystok/zeto/prymus/models/requests/GetApiResponseModel.java:8 |
| GetApiResponseModel | `token` | `String` | default/local candidate | pl/bialystok/zeto/prymus/models/requests/GetApiResponseModel.java:9 |
| GetApiResponseModel | `versionName` | `String` | default/local candidate | pl/bialystok/zeto/prymus/models/requests/GetApiResponseModel.java:10 |
| GetWeatherModel | `securityToken` | `String` | default/local candidate | pl/bialystok/zeto/prymus/models/requests/GetWeatherModel.java:5 |
| GetWeatherModel | `token` | `String` | default/local candidate | pl/bialystok/zeto/prymus/models/requests/GetWeatherModel.java:6 |
| JustifyAttendanceModel | `frekw_id` | `String` | SerializedName | pl/bialystok/zeto/prymus/models/requests/JustifyAttendanceModel.java:8 |
| JustifyAttendanceModel | `uspr` | `String` | SerializedName | pl/bialystok/zeto/prymus/models/requests/JustifyAttendanceModel.java:11 |
| JustifyAttendanceModel | `godz_lekc` | `String` | SerializedName | pl/bialystok/zeto/prymus/models/requests/JustifyAttendanceModel.java:14 |
| JustifyAttendanceModel | `data_wyslania` | `String` | SerializedName | pl/bialystok/zeto/prymus/models/requests/JustifyAttendanceModel.java:17 |
| JustifyAttendanceModel | `data_nb` | `String` | SerializedName | pl/bialystok/zeto/prymus/models/requests/JustifyAttendanceModel.java:20 |
| JustifyAttendanceModel | `id_ucznia` | `String` | SerializedName | pl/bialystok/zeto/prymus/models/requests/JustifyAttendanceModel.java:23 |
| NotifyTopicReadModel | `securityToken` | `String` | default/local candidate | pl/bialystok/zeto/prymus/models/requests/NotifyTopicReadModel.java:5 |
| NotifyTopicReadModel | `token` | `String` | default/local candidate | pl/bialystok/zeto/prymus/models/requests/NotifyTopicReadModel.java:6 |
| NotifyTopicReadModel | `topic` | `String` | default/local candidate | pl/bialystok/zeto/prymus/models/requests/NotifyTopicReadModel.java:7 |
| NotifyTopicReadModel | `userId` | `String` | default/local candidate | pl/bialystok/zeto/prymus/models/requests/NotifyTopicReadModel.java:8 |
| PostReadStatusModel | `objectId` | `String` | default/local candidate | pl/bialystok/zeto/prymus/models/requests/PostReadStatusModel.java:5 |
| PostReadStatusModel | `readDate` | `String` | default/local candidate | pl/bialystok/zeto/prymus/models/requests/PostReadStatusModel.java:6 |
| PostReadStatusModel | `securityToken` | `String` | default/local candidate | pl/bialystok/zeto/prymus/models/requests/PostReadStatusModel.java:7 |
| PostReadStatusModel | `token` | `String` | default/local candidate | pl/bialystok/zeto/prymus/models/requests/PostReadStatusModel.java:8 |
| PostReadStatusModel | `type` | `String` | default/local candidate | pl/bialystok/zeto/prymus/models/requests/PostReadStatusModel.java:9 |
| PostReadStatusMultiple | `apiVersion` | `int` | default/local candidate | pl/bialystok/zeto/prymus/models/requests/PostReadStatusMultiple.java:5 |
| PostReadStatusMultiple | `read` | `String` | default/local candidate | pl/bialystok/zeto/prymus/models/requests/PostReadStatusMultiple.java:6 |
| PostReadStatusMultiple | `securityToken` | `String` | default/local candidate | pl/bialystok/zeto/prymus/models/requests/PostReadStatusMultiple.java:7 |
| PostReadStatusMultiple | `token` | `String` | default/local candidate | pl/bialystok/zeto/prymus/models/requests/PostReadStatusMultiple.java:8 |
| ReportBugModel | `securityToken` | `String` | default/local candidate | pl/bialystok/zeto/prymus/models/requests/ReportBugModel.java:5 |
| ReportBugModel | `token` | `String` | default/local candidate | pl/bialystok/zeto/prymus/models/requests/ReportBugModel.java:6 |
| ReportBugModel | `userReport` | `String` | default/local candidate | pl/bialystok/zeto/prymus/models/requests/ReportBugModel.java:7 |
| ResetDevicesModel | `mobileId` | `String` | default/local candidate | pl/bialystok/zeto/prymus/models/requests/ResetDevicesModel.java:5 |
| ResetDevicesModel | `securityToken` | `String` | default/local candidate | pl/bialystok/zeto/prymus/models/requests/ResetDevicesModel.java:6 |
| ResetDevicesModel | `token` | `String` | default/local candidate | pl/bialystok/zeto/prymus/models/requests/ResetDevicesModel.java:7 |
| SendChatMessageModel | `attachment` | `String` | default/local candidate | pl/bialystok/zeto/prymus/models/requests/SendChatMessageModel.java:5 |
| SendChatMessageModel | `fromParent` | `int` | default/local candidate | pl/bialystok/zeto/prymus/models/requests/SendChatMessageModel.java:6 |
| SendChatMessageModel | `message` | `String` | default/local candidate | pl/bialystok/zeto/prymus/models/requests/SendChatMessageModel.java:7 |
| SendChatMessageModel | `securityToken` | `String` | default/local candidate | pl/bialystok/zeto/prymus/models/requests/SendChatMessageModel.java:8 |
| SendChatMessageModel | `token` | `String` | default/local candidate | pl/bialystok/zeto/prymus/models/requests/SendChatMessageModel.java:9 |
| SendChatMessageModel | `topic` | `String` | default/local candidate | pl/bialystok/zeto/prymus/models/requests/SendChatMessageModel.java:10 |
| SendChatMessageModel | `userId` | `String` | default/local candidate | pl/bialystok/zeto/prymus/models/requests/SendChatMessageModel.java:11 |
| SendDataModel | `json` | `String` | default/local candidate | pl/bialystok/zeto/prymus/models/requests/SendDataModel.java:5 |
| SendDataModel | `securityToken` | `String` | default/local candidate | pl/bialystok/zeto/prymus/models/requests/SendDataModel.java:6 |
| SendDataModel | `token` | `String` | default/local candidate | pl/bialystok/zeto/prymus/models/requests/SendDataModel.java:7 |
| SendDataModel | `type` | `int` | default/local candidate | pl/bialystok/zeto/prymus/models/requests/SendDataModel.java:8 |
| SendLogsModel | `logs` | `String` | default/local candidate | pl/bialystok/zeto/prymus/models/requests/SendLogsModel.java:5 |
| SendLogsModel | `mobileId` | `String` | default/local candidate | pl/bialystok/zeto/prymus/models/requests/SendLogsModel.java:6 |
| SendLogsModel | `securityToken` | `String` | default/local candidate | pl/bialystok/zeto/prymus/models/requests/SendLogsModel.java:7 |
| SendLogsModel | `token` | `String` | default/local candidate | pl/bialystok/zeto/prymus/models/requests/SendLogsModel.java:8 |
| SendLogsModel | `tokens` | `String` | default/local candidate | pl/bialystok/zeto/prymus/models/requests/SendLogsModel.java:9 |
| SetFcmTokenModel | `apiVersion` | `int` | default/local candidate | pl/bialystok/zeto/prymus/models/requests/SetFcmTokenModel.java:5 |
| SetFcmTokenModel | `fcmToken` | `String` | default/local candidate | pl/bialystok/zeto/prymus/models/requests/SetFcmTokenModel.java:6 |
| SetFcmTokenModel | `mobileId` | `String` | default/local candidate | pl/bialystok/zeto/prymus/models/requests/SetFcmTokenModel.java:7 |
| UpdateTokensModel | `mobileId` | `String` | default/local candidate | pl/bialystok/zeto/prymus/models/requests/UpdateTokensModel.java:5 |
| UpdateTokensModel | `parentId` | `String` | default/local candidate | pl/bialystok/zeto/prymus/models/requests/UpdateTokensModel.java:6 |
| UpdateTokensModel | `premium` | `int` | default/local candidate | pl/bialystok/zeto/prymus/models/requests/UpdateTokensModel.java:7 |
| UpdateTokensModel | `securityToken` | `String` | default/local candidate | pl/bialystok/zeto/prymus/models/requests/UpdateTokensModel.java:8 |
| UpdateTokensModel | `tokens` | `String` | default/local candidate | pl/bialystok/zeto/prymus/models/requests/UpdateTokensModel.java:9 |
| UpgradeLicensePremiumForTokensModel | `mobileId` | `String` | default/local candidate | pl/bialystok/zeto/prymus/models/requests/UpgradeLicensePremiumForTokensModel.java:5 |
| UpgradeLicensePremiumForTokensModel | `securityToken` | `String` | default/local candidate | pl/bialystok/zeto/prymus/models/requests/UpgradeLicensePremiumForTokensModel.java:6 |
| UpgradeLicensePremiumForTokensModel | `token` | `String` | default/local candidate | pl/bialystok/zeto/prymus/models/requests/UpgradeLicensePremiumForTokensModel.java:7 |
| UpgradeLicensePremiumForTokensModel | `tokensToUpgrade` | `String` | default/local candidate | pl/bialystok/zeto/prymus/models/requests/UpgradeLicensePremiumForTokensModel.java:8 |
| UploadReplyToTeacherModel | `apiVersion` | `int` | default/local candidate | pl/bialystok/zeto/prymus/models/requests/UploadReplyToTeacherModel.java:7 |
| UploadReplyToTeacherModel | `attachments` | `List<String>` | default/local candidate | pl/bialystok/zeto/prymus/models/requests/UploadReplyToTeacherModel.java:8 |
| UploadReplyToTeacherModel | `extensions` | `List<String>` | default/local candidate | pl/bialystok/zeto/prymus/models/requests/UploadReplyToTeacherModel.java:9 |
| UploadReplyToTeacherModel | `fileNames` | `List<String>` | default/local candidate | pl/bialystok/zeto/prymus/models/requests/UploadReplyToTeacherModel.java:10 |
| UploadReplyToTeacherModel | `message` | `String` | default/local candidate | pl/bialystok/zeto/prymus/models/requests/UploadReplyToTeacherModel.java:11 |
| UploadReplyToTeacherModel | `securityToken` | `String` | default/local candidate | pl/bialystok/zeto/prymus/models/requests/UploadReplyToTeacherModel.java:12 |
| UploadReplyToTeacherModel | `taskId` | `String` | default/local candidate | pl/bialystok/zeto/prymus/models/requests/UploadReplyToTeacherModel.java:13 |
| UploadReplyToTeacherModel | `token` | `String` | default/local candidate | pl/bialystok/zeto/prymus/models/requests/UploadReplyToTeacherModel.java:14 |
| ApiResponse | `ActualSchoolYear` | `String` | SerializedName | pl/bialystok/zeto/prymus/network/ApiResponse.java:33 |
| ApiResponse | `ActualTermShortcut` | `String` | SerializedName | pl/bialystok/zeto/prymus/network/ApiResponse.java:36 |
| ApiResponse | `ActualVersion` | `boolean` | SerializedName | pl/bialystok/zeto/prymus/network/ApiResponse.java:39 |
| ApiResponse | `Announcements` | `List<Announcement>` | SerializedName | pl/bialystok/zeto/prymus/network/ApiResponse.java:42 |
| ApiResponse | `Attendance` | `List<Attendances>` | SerializedName | pl/bialystok/zeto/prymus/network/ApiResponse.java:45 |
| ApiResponse | `AttendanceStatistics` | `List<AttendanceStatistic>` | SerializedName | pl/bialystok/zeto/prymus/network/ApiResponse.java:48 |
| ApiResponse | `BehaviorActualPoints` | `int` | SerializedName | pl/bialystok/zeto/prymus/network/ApiResponse.java:51 |
| ApiResponse | `BehaviorStartingPoints` | `int` | SerializedName | pl/bialystok/zeto/prymus/network/ApiResponse.java:54 |
| ApiResponse | `Books` | `List<Book>` | SerializedName | pl/bialystok/zeto/prymus/network/ApiResponse.java:57 |
| ApiResponse | `UserId` | `String` | SerializedName | pl/bialystok/zeto/prymus/network/ApiResponse.java:60 |
| ApiResponse | `Messages` | `List<JsonObject>` | SerializedName | pl/bialystok/zeto/prymus/network/ApiResponse.java:63 |
| ApiResponse | `ChatSettings` | `ChatSettings` | SerializedName | pl/bialystok/zeto/prymus/network/ApiResponse.java:66 |
| ApiResponse | `ChatTeachersIds` | `List<ChatTeacherId>` | SerializedName | pl/bialystok/zeto/prymus/network/ApiResponse.java:69 |
| ApiResponse | `DiaryNumber` | `int` | SerializedName | pl/bialystok/zeto/prymus/network/ApiResponse.java:72 |
| ApiResponse | `ExpirationDate` | `String` | SerializedName | pl/bialystok/zeto/prymus/network/ApiResponse.java:75 |
| ApiResponse | `ExternalId` | `String` | SerializedName | pl/bialystok/zeto/prymus/network/ApiResponse.java:78 |
| ApiResponse | `FAQ` | `List<Faq>` | SerializedName | pl/bialystok/zeto/prymus/network/ApiResponse.java:81 |
| ApiResponse | `FirstName` | `String` | SerializedName | pl/bialystok/zeto/prymus/network/ApiResponse.java:84 |
| ApiResponse | `IpAddress` | `String` | SerializedName | pl/bialystok/zeto/prymus/network/ApiResponse.java:87 |
| ApiResponse | `isParentMessage` | `boolean` | SerializedName | pl/bialystok/zeto/prymus/network/ApiResponse.java:90 |
| ApiResponse | `IsScoringSystem` | `boolean` | SerializedName | pl/bialystok/zeto/prymus/network/ApiResponse.java:93 |
| ApiResponse | `LastName` | `String` | SerializedName | pl/bialystok/zeto/prymus/network/ApiResponse.java:96 |
| ApiResponse | `LastResetDate` | `String` | SerializedName | pl/bialystok/zeto/prymus/network/ApiResponse.java:99 |
| ApiResponse | `Lessons` | `List<Lessons>` | SerializedName | pl/bialystok/zeto/prymus/network/ApiResponse.java:102 |
| ApiResponse | `License` | `int` | SerializedName | pl/bialystok/zeto/prymus/network/ApiResponse.java:105 |
| ApiResponse | `Login` | `String` | SerializedName | pl/bialystok/zeto/prymus/network/ApiResponse.java:108 |
| ApiResponse | `LuckyNumber` | `int` | SerializedName | pl/bialystok/zeto/prymus/network/ApiResponse.java:111 |
| ApiResponse | `MarkAverage` | `List<MarkAverage>` | SerializedName | pl/bialystok/zeto/prymus/network/ApiResponse.java:114 |
| ApiResponse | `MarkFinal` | `List<MarkFinal>` | SerializedName | pl/bialystok/zeto/prymus/network/ApiResponse.java:117 |
| ApiResponse | `MarksResults` | `List<MarkResults>` | SerializedName | pl/bialystok/zeto/prymus/network/ApiResponse.java:120 |
| ApiResponse | `Marks` | `List<Mark>` | SerializedName | pl/bialystok/zeto/prymus/network/ApiResponse.java:123 |
| ApiResponse | `News` | `List<News>` | SerializedName | pl/bialystok/zeto/prymus/network/ApiResponse.java:126 |
| ApiResponse | `ParentsChats` | `List<Topic>` | SerializedName | pl/bialystok/zeto/prymus/network/ApiResponse.java:129 |
| ApiResponse | `ParentsMessages` | `List<JsonObject>` | SerializedName | pl/bialystok/zeto/prymus/network/ApiResponse.java:132 |
| ApiResponse | `Parents` | `List<Parent>` | SerializedName | pl/bialystok/zeto/prymus/network/ApiResponse.java:135 |
| ApiResponse | `PaymentDay` | `String` | SerializedName | pl/bialystok/zeto/prymus/network/ApiResponse.java:138 |
| ApiResponse | `PIN` | `String` | SerializedName | pl/bialystok/zeto/prymus/network/ApiResponse.java:141 |
| ApiResponse | `Remarks` | `List<Remark>` | SerializedName | pl/bialystok/zeto/prymus/network/ApiResponse.java:144 |
| ApiResponse | `Replacements` | `List<Replacement>` | SerializedName | pl/bialystok/zeto/prymus/network/ApiResponse.java:147 |
| ApiResponse | `SchoolClass` | `String` | SerializedName | pl/bialystok/zeto/prymus/network/ApiResponse.java:150 |
| ApiResponse | `SchoolInformation` | `SchoolInformation` | SerializedName | pl/bialystok/zeto/prymus/network/ApiResponse.java:153 |
| ApiResponse | `SchoolName` | `String` | SerializedName | pl/bialystok/zeto/prymus/network/ApiResponse.java:156 |
| ApiResponse | `ScoringRemarks` | `List<ScoringRemark>` | SerializedName | pl/bialystok/zeto/prymus/network/ApiResponse.java:159 |
| ApiResponse | `Sex` | `String` | SerializedName | pl/bialystok/zeto/prymus/network/ApiResponse.java:162 |
| ApiResponse | `system_message` | `SystemMessage` | SerializedName | pl/bialystok/zeto/prymus/network/ApiResponse.java:165 |
| ApiResponse | `TaskAnswers` | `List<TaskAnswer>` | SerializedName | pl/bialystok/zeto/prymus/network/ApiResponse.java:168 |
| ApiResponse | `Tasks` | `List<Tasks>` | SerializedName | pl/bialystok/zeto/prymus/network/ApiResponse.java:171 |
| ApiResponse | `Teacher` | `List<Teacher>` | SerializedName | pl/bialystok/zeto/prymus/network/ApiResponse.java:174 |
| ApiResponse | `Timetable` | `List<Timetable>` | SerializedName | pl/bialystok/zeto/prymus/network/ApiResponse.java:177 |
| ApiResponse | `Chats` | `List<Topic>` | SerializedName | pl/bialystok/zeto/prymus/network/ApiResponse.java:180 |
| SystemMessage | `code` | `int` | SerializedName | pl/bialystok/zeto/prymus/network/SystemMessage.java:9 |
| SystemMessage | `data` | `String` | SerializedName | pl/bialystok/zeto/prymus/network/SystemMessage.java:12 |
| SystemMessage | `message` | `String` | SerializedName | pl/bialystok/zeto/prymus/network/SystemMessage.java:15 |
| SystemMessage | `title` | `String` | SerializedName | pl/bialystok/zeto/prymus/network/SystemMessage.java:18 |
| MessageJson | `zalaczniki` | `List<ChatMessage.ChatAttachment>` | SerializedName | pl/bialystok/zeto/prymus/chat/MessageJson.java:10 |
| MessageJson | `externalId` | `String` | SerializedName | pl/bialystok/zeto/prymus/chat/MessageJson.java:13 |
| MessageJson | `wiadomosc` | `String` | SerializedName | pl/bialystok/zeto/prymus/chat/MessageJson.java:16 |
| MessageJson | `imie` | `String` | SerializedName | pl/bialystok/zeto/prymus/chat/MessageJson.java:19 |
| MessageJson | `recipient` | `String` | SerializedName | pl/bialystok/zeto/prymus/chat/MessageJson.java:22 |
| MessageJson | `nazwisko` | `String` | SerializedName | pl/bialystok/zeto/prymus/chat/MessageJson.java:25 |
| MessageJson | `tytul` | `String` | SerializedName | pl/bialystok/zeto/prymus/chat/MessageJson.java:28 |
| MessageJson | `id_uzytkownika` | `String` | SerializedName | pl/bialystok/zeto/prymus/chat/MessageJson.java:31 |
