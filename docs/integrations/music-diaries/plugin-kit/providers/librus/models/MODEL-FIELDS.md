# Client model field reference

These are local Vuex-ORM declarations, not complete wire DTO schemas. Defaults/relationship declarations must not be imposed on server JSON.

Recovered 62 model declarations and 801 fields. Use the source path, source-map index and SHA256 to locate evidence. `attr(null)` establishes a local default only; it does not prove server nullability. ORM relationships require separate loading/join rules. See [mapping guide](DTO-MAPPING.md) and [module workflows](WORKFLOWS.md).

## Announcements — 'schoolnotices'

Source `src/viewmodels/announcements.js`; entity `'schoolnotices'`; primary key `['SynergiaAccountId', 'Id']`; source-content SHA256 `fc4988c30022c56a03a4102fc3b3bca3fa85cfa3265f89a9a13500d71d3ced05`.

| Field | Client declaration | Default / relationship arguments | Source line |
|---|---|---|---|
| `Id` | `attr` | `null` | 26 |
| `AddedBy` | `string` | `null` | 27 |
| `Title` | `attr` | `null` | 28 |
| `Start` | `string` | `''` | 29 |
| `End` | `string` | `''` | 30 |
| `Date` | `string` | `''` | 31 |
| `Description` | `string` | `''` | 32 |
| `SynergiaAccountId` | `string` | `''` | 33 |
| `IsNew` | `boolean` | `false` | 34 |
| `Deleted` | `boolean` | `false` | 35 |
| `Reminder` | `morphOne` | `Reminder, 'ModelableId', 'ModelableType', '$id'` | 36 |
| `isMealNews` | `boolean` | `false` | 38 |
| `Attachments` | `attr` | `[]` | 39 |

## AttendancesTypes — 'attendancestypes'

Source `src/viewmodels/attendances-types.js`; entity `'attendancestypes'`; primary key `['SynergiaAccountId', 'Id']`; source-content SHA256 `08537de4a91856dc91de3df66f231a5afcb0f72996f17a285d0242d165a65ec5`.

| Field | Client declaration | Default / relationship arguments | Source line |
|---|---|---|---|
| `Id` | `string` | `null` | 25 |
| `Name` | `string` | `''` | 26 |
| `Short` | `string` | `''` | 27 |
| `Standard` | `string` | `''` | 28 |
| `SynergiaAccountId` | `string` | `''` | 29 |
| `IsNew` | `boolean` | `false` | 30 |
| `Deleted` | `boolean` | `false` | 31 |
| `StandardTypeId` | `string` | `''` | 32 |

## Attendances — 'attendances'

Source `src/viewmodels/attendances.js`; entity `'attendances'`; primary key `['SynergiaAccountId', 'Id']`; source-content SHA256 `a27701c63f6cd90660724a4122c46d2358cd230eb50d5012e6d4595d21078818`.

| Field | Client declaration | Default / relationship arguments | Source line |
|---|---|---|---|
| `Id` | `string` | `null` | 25 |
| `Lesson` | `string` | `null` | 26 |
| `Subject` | `attr` | `null` | 27 |
| `Type` | `string` | `''` | 28 |
| `TypeId` | `string` | `''` | 29 |
| `ShortType` | `string` | `''` | 30 |
| `StandardShortType` | `string` | `''` | 31 |
| `StandardType` | `string` | `''` | 32 |
| `Comment` | `string` | `null` | 33 |
| `Date` | `string` | `''` | 34 |
| `AddDate` | `string` | `''` | 35 |
| `AddedBy` | `string` | `null` | 36 |
| `Semester` | `number` | `1` | 37 |
| `SynergiaAccountId` | `string` | `''` | 38 |
| `IsNew` | `boolean` | `false` | 39 |
| `Deleted` | `boolean` | `false` | 40 |

## Averages — 'averages'

Source `src/viewmodels/averages.js`; entity `'averages'`; primary key `['SynergiaAccountId', 'SubjectId', 'Period', 'Type']`; source-content SHA256 `9772e615a008a7a070c1f36feed13171171d849c96bebc7ee0189159752b637e`.

| Field | Client declaration | Default / relationship arguments | Source line |
|---|---|---|---|
| `Text` | `string` | `null` | 25 |
| `SubjectId` | `attr` | `null` | 26 |
| `Period` | `attr` | `null` | 27 |
| `IsFullYear` | `boolean` | `false` | 28 |
| `Value` | `string` | `''` | 29 |
| `SynergiaAccountId` | `attr` | `null` | 30 |
| `Type` | `string` | `''` | 31 |
| `IsNew` | `boolean` | `false` | 32 |
| `Deleted` | `boolean` | `false` | 33 |

## Grades — 'behaviourgradespoints'

Source `src/viewmodels/behaviour-grades-point.js`; entity `'behaviourgradespoints'`; primary key `['SynergiaAccountId', 'Id']`; source-content SHA256 `2e0989fc7525e9c6cdad5f2087000b5ca5466cbe16ca9cf0e50ba82b87b6ec64`.

| Field | Client declaration | Default / relationship arguments | Source line |
|---|---|---|---|
| `Id` | `attr` | `null` | 26 |
| `Teacher` | `string` | `null` | 27 |
| `Category` | `string` | `null` | 28 |
| `SubjectId` | `attr` | `null` | 29 |
| `SubjectName` | `attr` | `null` | 30 |
| `Date` | `attr` | `null` | 31 |
| `AddDate` | `attr` | `null` | 32 |
| `Grade` | `attr` | `null` | 33 |
| `GradeValue` | `attr` | `null` | 34 |
| `Description` | `string` | `null` | 35 |
| `Semester` | `attr` | `null` | 36 |
| `Comments` | `hasMany` | `GradeComments, 'GradeId', 'Id'` | 37 |
| `Improvements` | `attr` | `[]` | 38 |
| `SynergiaAccountId` | `attr` | `null` | 39 |
| `IsNew` | `boolean` | `false` | 40 |
| `Deleted` | `boolean` | `false` | 41 |
| `Type` | `string` | `this.entity` | 42 |

## BehaviourGradesPointsCategories — 'behaviourgradespointscategories'

Source `src/viewmodels/behaviour-grades-points-categories.js`; entity `'behaviourgradespointscategories'`; primary key `['SynergiaAccountId', 'Id']`; source-content SHA256 `956ce104a3c0f7289387abe319b04281b4627d0cb115dcc18279011718f62565`.

| Field | Client declaration | Default / relationship arguments | Source line |
|---|---|---|---|
| `Id` | `attr` | `null` | 23 |
| `Name` | `string` | `null` | 24 |
| `Short` | `string` | `null` | 25 |
| `ValueFrom` | `number` | `1` | 26 |
| `ValueTo` | `number` | `6` | 27 |
| `SynergiaAccountId` | `attr` | `null` | 28 |
| `IsNew` | `boolean` | `false` | 29 |
| `Deleted` | `boolean` | `false` | 30 |

## Grades — 'behaviourgradessystemproposal'

Source `src/viewmodels/behaviour-grades-system-proposal.js`; entity `'behaviourgradessystemproposal'`; primary key `['SynergiaAccountId', 'Id']`; source-content SHA256 `ce31559713ad390a1f9779c4b8ce3dce7b31cec61d0ce61ac0e9ad7d2b5dbe9a`.

| Field | Client declaration | Default / relationship arguments | Source line |
|---|---|---|---|
| `Id` | `attr` | `null` | 26 |
| `Teacher` | `string` | `null` | 27 |
| `Category` | `string` | `null` | 28 |
| `SubjectId` | `attr` | `null` | 29 |
| `SubjectName` | `attr` | `null` | 30 |
| `Date` | `attr` | `null` | 31 |
| `AddDate` | `attr` | `null` | 32 |
| `Grade` | `attr` | `null` | 33 |
| `GradeValue` | `attr` | `null` | 34 |
| `Description` | `string` | `null` | 35 |
| `Semester` | `attr` | `null` | 36 |
| `Comments` | `hasMany` | `GradeComments, 'GradeId', 'Id'` | 37 |
| `Improvements` | `attr` | `[]` | 38 |
| `SynergiaAccountId` | `attr` | `null` | 39 |
| `IsNew` | `boolean` | `false` | 40 |
| `Deleted` | `boolean` | `false` | 41 |
| `Type` | `string` | `this.entity` | 42 |

## BehaviourGradesTypes — 'behaviourgradestypes'

Source `src/viewmodels/behaviour-grades-types.js`; entity `'behaviourgradestypes'`; primary key `['SynergiaAccountId', 'Id']`; source-content SHA256 `9ac0ef4b7db147d9a316d25273fbd710f46bb611f69f4ea19ec121fba9a120b9`.

| Field | Client declaration | Default / relationship arguments | Source line |
|---|---|---|---|
| `Id` | `attr` | `null` | 23 |
| `Name` | `string` | `null` | 24 |
| `Shortcut` | `string` | `null` | 25 |
| `SynergiaAccountId` | `attr` | `null` | 26 |
| `IsNew` | `boolean` | `false` | 27 |
| `Deleted` | `boolean` | `false` | 28 |

## Grades — 'behaviourgrades'

Source `src/viewmodels/behaviour-grades.js`; entity `'behaviourgrades'`; primary key `['SynergiaAccountId', 'Id']`; source-content SHA256 `837acf20b9655b01296060648da1b400b4e99be0be030a6cc6b1981ae4355953`.

| Field | Client declaration | Default / relationship arguments | Source line |
|---|---|---|---|
| `Id` | `attr` | `null` | 26 |
| `Teacher` | `string` | `null` | 27 |
| `Category` | `string` | `null` | 28 |
| `SubjectId` | `attr` | `null` | 29 |
| `SubjectName` | `attr` | `null` | 30 |
| `Date` | `attr` | `null` | 31 |
| `AddDate` | `attr` | `null` | 32 |
| `Grade` | `attr` | `null` | 33 |
| `GradeValue` | `attr` | `null` | 34 |
| `Description` | `string` | `null` | 35 |
| `Semester` | `attr` | `null` | 36 |
| `Comments` | `hasMany` | `GradeComments, 'GradeId', 'Id'` | 37 |
| `Improvements` | `attr` | `[]` | 38 |
| `SynergiaAccountId` | `attr` | `null` | 39 |
| `IsNew` | `boolean` | `false` | 40 |
| `Deleted` | `boolean` | `false` | 41 |
| `Type` | `string` | `this.entity` | 42 |
| `IsProposal` | `boolean` | `false` | 43 |

## CalendarIdsCategories — 'calendarcategories'

Source `src/viewmodels/calendar-ids-categories.js`; entity `'calendarcategories'`; primary key `['SynergiaAccountId', 'Id']`; source-content SHA256 `dc9d8f51073f8abd9a76ed6879055847da45d43b6688246378f2e20dacf4a643`.

| Field | Client declaration | Default / relationship arguments | Source line |
|---|---|---|---|
| `Id` | `attr` | `null` | 23 |
| `Name` | `string` | `''` | 24 |
| `SynergiaAccountId` | `attr` | `null` | 25 |
| `Deleted` | `attr` | `false` | 26 |

## CalendarId — 'calendars'

Source `src/viewmodels/calendar-ids.js`; entity `'calendars'`; primary key `['SynergiaAccountId', 'Id']`; source-content SHA256 `0e8f5b819c36c87baaa8883955c86e7e44968c56d0d8051e7d1908657c3c32e7`.

| Field | Client declaration | Default / relationship arguments | Source line |
|---|---|---|---|
| `Id` | `attr` | `null` | 25 |
| `SynergiaAccountId` | `attr` | `null` | 26 |
| `Deleted` | `attr` | `false` | 27 |

## Calendar — 'calendarevents'

Source `src/viewmodels/calendar.js`; entity `'calendarevents'`; primary key `['SynergiaAccountId', 'Id']`; source-content SHA256 `9c3c6c9e0a677a6f0dbfc5f149a8017528a99dceae1ce49901d4e0d5b3b7cd29`.

| Field | Client declaration | Default / relationship arguments | Source line |
|---|---|---|---|
| `Id` | `attr` | `null` | 26 |
| `SynergiaAccountId` | `attr` | `null` | 27 |
| `IsNew` | `boolean` | `false` | 28 |
| `Deleted` | `boolean` | `false` | 29 |
| `ResourceName` | `attr` | `null` | 30 |
| `start` | `string` | `null` | 31 |
| `end` | `string` | `null` | 32 |
| `title` | `string` | `null` | 33 |
| `subject` | `string` | `null` | 34 |
| `teacher` | `string` | `null` | 35 |
| `lessonNo` | `string` | `null` | 36 |
| `description` | `string` | `null` | 37 |
| `classroom` | `string` | `null` | 38 |
| `class` | `string` | `null` | 39 |
| `date` | `string` | `null` | 40 |
| `customStyle` | `attr` | `null` | 41 |
| `allDay` | `attr` | `false` | 42 |
| `type` | `string` | `null` | 43 |
| `canceled` | `attr` | `null` | 44 |
| `isSubstitutionClass` | `attr` | `null` | 45 |
| `onlineLessonUrl` | `attr` | `null` | 46 |
| `Reminder` | `morphOne` | `Reminder, 'ModelableId', 'ModelableType', '$id'` | 47 |

## Changes — 'changes'

Source `src/viewmodels/changes.js`; entity `'changes'`; primary key `['SynergiaAccountId', 'Id']`; source-content SHA256 `406e6a599bb1c8883bc8fc5b10fd7096fb8b6606015d6598c5d1d20a15f02118`.

| Field | Client declaration | Default / relationship arguments | Source line |
|---|---|---|---|
| `Id` | `attr` | `null` | 24 |
| `SynergiaAccountId` | `attr` | `null` | 25 |
| `Type` | `string` | `null` | 26 |
| `Resource` | `string` | `null` | 27 |
| `TriesCount` | `number` | `0` | 28 |
| `LastAdded` | `string` | `null` | 29 |

## ClassAndSchoolInfo — 'classAndSchoolInfo'

Source `src/viewmodels/class-and-school-info.js`; entity `'classAndSchoolInfo'`; primary key `'Id'`; source-content SHA256 `c7035c53dfcf9f9c872774d37a59778aebe152c116a5854128150d239e48dc25`.

| Field | Client declaration | Default / relationship arguments | Source line |
|---|---|---|---|
| `Id` | `attr` | `null` | 26 |
| `ClassName` | `string` | `''` | 27 |
| `TeachersId` | `attr` | `[]` | 28 |
| `Teachers` | `hasManyBy` | `Users, 'TeachersId', '$id'` | 29 |
| `SchoolName` | `string` | `''` | 30 |
| `SchoolKind` | `string` | `''` | 31 |
| `SchoolStreet` | `string` | `''` | 32 |
| `SchoolCity` | `string` | `''` | 33 |
| `SchoolState` | `string` | `''` | 34 |
| `SchoolDirector` | `string` | `''` | 35 |
| `IsKindergarten` | `boolean` | `false` | 36 |
| `KindergartenGroupPeriod` | `attr` | `{ start: this.string(''), end: this.string(''), }` | 37 |
| `start` | `string` | `''` | 38 |
| `end` | `string` | `''` | 39 |

## ClassFreeDaysTypes — 'classfreedaystypes'

Source `src/viewmodels/class-free-days-types.js`; entity `'classfreedaystypes'`; primary key `['SynergiaAccountId', 'Id']`; source-content SHA256 `a0064cb039275647957b27b751b986654747ca965526f3cb760531a5ca46d43d`.

| Field | Client declaration | Default / relationship arguments | Source line |
|---|---|---|---|
| `Id` | `attr` | `null` | 23 |
| `Name` | `string` | `''` | 24 |
| `SynergiaAccountId` | `attr` | `null` | 25 |
| `Deleted` | `attr` | `false` | 26 |

## DescriptiveGradesSkills — 'descriptivegradesskills'

Source `src/viewmodels/descriptive-grades-skills.js`; entity `'descriptivegradesskills'`; primary key `['SynergiaAccountId', 'Id']`; source-content SHA256 `cbe1a86eda97e856e4e64dba12869e76209c0c892b235ebdb8e142018d45c20a`.

| Field | Client declaration | Default / relationship arguments | Source line |
|---|---|---|---|
| `Id` | `attr` | `null` | 23 |
| `Name` | `string` | `null` | 24 |
| `CountToTheAverage` | `boolean` | `false` | 25 |
| `Weight` | `number` | `1` | 26 |
| `SynergiaAccountId` | `attr` | `null` | 27 |
| `IsNew` | `boolean` | `false` | 28 |
| `Deleted` | `boolean` | `false` | 29 |

## Grades — 'descriptivegradestext'

Source `src/viewmodels/descriptive-grades-text.js`; entity `'descriptivegradestext'`; primary key `['SynergiaAccountId', 'Id']`; source-content SHA256 `0fbd27bea5750461468dd53f31c49e9b12a989caa8d7f33c9bde8fb4efe4f326`.

| Field | Client declaration | Default / relationship arguments | Source line |
|---|---|---|---|
| `Id` | `attr` | `null` | 26 |
| `Teacher` | `string` | `null` | 27 |
| `Category` | `string` | `null` | 28 |
| `SubjectId` | `attr` | `null` | 29 |
| `SubjectName` | `attr` | `null` | 30 |
| `Date` | `attr` | `null` | 31 |
| `AddDate` | `attr` | `null` | 32 |
| `Grade` | `attr` | `null` | 33 |
| `Description` | `string` | `null` | 34 |
| `Semester` | `attr` | `null` | 35 |
| `Comments` | `hasMany` | `GradeComments, 'GradeId', 'Id'` | 36 |
| `ImproveId` | `attr` | `null` | 37 |
| `Improvements` | `attr` | `[]` | 38 |
| `GradesIds` | `attr` | `[]` | 39 |
| `SynergiaAccountId` | `attr` | `null` | 40 |
| `IsNew` | `boolean` | `false` | 41 |
| `Deleted` | `boolean` | `false` | 42 |
| `Type` | `string` | `this.entity` | 43 |

## Grades — 'descriptivegrades'

Source `src/viewmodels/descriptive-grades.js`; entity `'descriptivegrades'`; primary key `['SynergiaAccountId', 'Id']`; source-content SHA256 `4e6e70bcce3042c81d955a9b58ed07f40e27509a788f6a616ea55e25040534e6`.

| Field | Client declaration | Default / relationship arguments | Source line |
|---|---|---|---|
| `Id` | `attr` | `null` | 26 |
| `Teacher` | `string` | `null` | 27 |
| `Category` | `string` | `null` | 28 |
| `SubjectId` | `attr` | `null` | 29 |
| `SubjectName` | `attr` | `null` | 30 |
| `Date` | `attr` | `null` | 31 |
| `AddDate` | `attr` | `null` | 32 |
| `Grade` | `attr` | `null` | 33 |
| `Description` | `string` | `null` | 34 |
| `Semester` | `attr` | `null` | 35 |
| `Comments` | `hasMany` | `GradeComments, 'GradeId', 'Id'` | 36 |
| `ImproveId` | `attr` | `null` | 37 |
| `Improvements` | `attr` | `[]` | 38 |
| `SynergiaAccountId` | `attr` | `null` | 39 |
| `IsNew` | `boolean` | `false` | 40 |
| `Deleted` | `boolean` | `false` | 41 |
| `Type` | `string` | `this.entity` | 42 |
| `Color` | `string` | `''` | 43 |

## DescriptiveTextGradesSkills — 'descriptivetextgradesskills'

Source `src/viewmodels/descriptive-text-grades-skills.js`; entity `'descriptivetextgradesskills'`; primary key `['SynergiaAccountId', 'Id']`; source-content SHA256 `e05d406f1ab0604631b1aca2429d6200a637de23e828088436164a817678c63b`.

| Field | Client declaration | Default / relationship arguments | Source line |
|---|---|---|---|
| `Id` | `attr` | `null` | 23 |
| `Name` | `string` | `null` | 24 |
| `CountToTheAverage` | `boolean` | `false` | 25 |
| `Weight` | `number` | `1` | 26 |
| `SynergiaAccountId` | `attr` | `null` | 27 |
| `IsNew` | `boolean` | `false` | 28 |
| `Deleted` | `boolean` | `false` | 29 |

## Grades — 'descriptivetextgrades'

Source `src/viewmodels/descriptive-text-grades.js`; entity `'descriptivetextgrades'`; primary key `['SynergiaAccountId', 'Id']`; source-content SHA256 `1a543152e680a9338321f9169d9e90535d2babbe9397b557253ec19c967275d3`.

| Field | Client declaration | Default / relationship arguments | Source line |
|---|---|---|---|
| `Id` | `attr` | `null` | 26 |
| `Teacher` | `string` | `null` | 27 |
| `Category` | `string` | `null` | 28 |
| `SubjectId` | `number` | `null` | 29 |
| `SubjectName` | `attr` | `null` | 30 |
| `Date` | `attr` | `null` | 31 |
| `AddDate` | `attr` | `null` | 32 |
| `Grade` | `attr` | `null` | 33 |
| `Description` | `string` | `null` | 34 |
| `Semester` | `attr` | `null` | 35 |
| `Comments` | `hasMany` | `GradeComments, 'GradeId', 'Id'` | 36 |
| `ImproveId` | `attr` | `null` | 37 |
| `Improvements` | `attr` | `[]` | 38 |
| `SynergiaAccountId` | `attr` | `null` | 39 |
| `IsNew` | `boolean` | `false` | 40 |
| `Deleted` | `boolean` | `false` | 41 |
| `Type` | `string` | `this.entity` | 42 |

## EventFrame — 'eventframes'

Source `src/viewmodels/event-frames.js`; entity `'eventframes'`; primary key `['identifier']`; source-content SHA256 `39d9094d80a15353109374129b19878f18e8b567ac9f7a3dddbb5d5200a615c4`.

| Field | Client declaration | Default / relationship arguments | Source line |
|---|---|---|---|
| `identifier` | `string` | `null` | 25 |
| `date` | `string` | `null` | 26 |
| `type` | `string` | `null` | 27 |
| `objectType` | `string` | `null` | 28 |
| `objectIdentifier` | `string` | `null` | 29 |
| `changed` | `attr` | `null` | 30 |

## Event — 'events'

Source `src/viewmodels/events.js`; entity `'events'`; primary key `['SynergiaAccountId', 'Id']`; source-content SHA256 `14810b41bf7306d308ca46e0660011f3b57b523371ea1f2eaf4bc98e1ddb868e`.

| Field | Client declaration | Default / relationship arguments | Source line |
|---|---|---|---|
| `Id` | `attr` | `null` | 25 |
| `UserName` | `string` | `null` | 26 |
| `EventName` | `string` | `null` | 27 |
| `EventActionType` | `string` | `null` | 28 |
| `ModelId` | `attr` | `null` | 29 |
| `ComponentName` | `string` | `null` | 30 |
| `ComponentPath` | `string` | `null` | 31 |
| `ComponentProps` | `attr` | `null` | 32 |
| `Date` | `attr` | `null` | 33 |
| `Type` | `string` | `''` | 34 |
| `SynergiaAccountId` | `string` | `''` | 35 |
| `IsNew` | `boolean` | `true` | 36 |
| `Deleted` | `boolean` | `false` | 37 |
| `GroupingOptions` | `attr` | `{ isVisible: true }` | 38 |
| `SortBy` | `number` | `null` | 39 |
| `IsLibrusGo` | `boolean` | `false` | 40 |
| `LibrusGoAccountId` | `string` | `''` | 41 |
| `ExtraData` | `attr` | `null` | 42 |

## FrameworkDayPlan — 'frameworkdayplan'

Source `src/viewmodels/framework-day-plan.js`; entity `'frameworkdayplan'`; primary key `['SynergiaAccountId', 'Id']`; source-content SHA256 `2e0f34f405feac8f7256bfcdde40ba2385ca572337bbdba1d99094af3a011a09`.

| Field | Client declaration | Default / relationship arguments | Source line |
|---|---|---|---|
| `Id` | `string` | `null` | 25 |
| `Name` | `string` | `null` | 26 |
| `IsValidFrom` | `string` | `null` | 27 |
| `IsValidTo` | `string` | `null` | 28 |
| `SchedulePoints` | `attr` | `null` | 29 |
| `SynergiaAccountId` | `string` | `''` | 30 |
| `IsNew` | `boolean` | `false` | 31 |
| `Deleted` | `boolean` | `false` | 32 |

## GradeComments — 'gradescomments'

Source `src/viewmodels/grade-comments.js`; entity `'gradescomments'`; primary key `['SynergiaAccountId', 'Id']`; source-content SHA256 `6b40d144f9e136a4ed8c350f096001fc8c1d5474702ce9579c4cb9f64ec4f760`.

| Field | Client declaration | Default / relationship arguments | Source line |
|---|---|---|---|
| `Id` | `attr` | `null` | 25 |
| `User` | `string` | `null` | 26 |
| `GradeId` | `attr` | `null` | 27 |
| `GradeType` | `string` | `null` | 28 |
| `Text` | `string` | `null` | 29 |
| `SynergiaAccountId` | `attr` | `null` | 30 |
| `IsNew` | `boolean` | `false` | 31 |
| `Deleted` | `boolean` | `false` | 32 |

## GradesCategories — 'gradescategories'

Source `src/viewmodels/grades-categories.js`; entity `'gradescategories'`; primary key `['SynergiaAccountId', 'Id']`; source-content SHA256 `08638aac60678fbac53484fe69cd34f5744fe7fc134a52bfe59f14e984c3768f`.

| Field | Client declaration | Default / relationship arguments | Source line |
|---|---|---|---|
| `Id` | `attr` | `null` | 23 |
| `Name` | `string` | `null` | 24 |
| `Short` | `string` | `null` | 25 |
| `Standard` | `boolean` | `true` | 26 |
| `ObligationToPerform` | `boolean` | `false` | 27 |
| `Weight` | `number` | `1` | 28 |
| `CountToTheAverage` | `boolean` | `true` | 29 |
| `IsReadOnly` | `string` | `null` | 30 |
| `AdultsDaily` | `boolean` | `false` | 31 |
| `AdultsExtramural` | `boolean` | `false` | 32 |
| `BlockAnyGrades` | `boolean` | `false` | 33 |
| `IsFinal` | `boolean` | `false` | 34 |
| `IsFinalProposition` | `boolean` | `false` | 35 |
| `IsSemestral` | `boolean` | `false` | 36 |
| `IsSemestralProposition` | `boolean` | `false` | 37 |
| `SynergiaAccountId` | `attr` | `null` | 39 |
| `IsNew` | `boolean` | `false` | 40 |
| `Deleted` | `boolean` | `false` | 41 |

## Grades — 'grades'

Source `src/viewmodels/grades.js`; entity `'grades'`; primary key `['SynergiaAccountId', 'Id']`; source-content SHA256 `49e5d72f033f4dfd3d6eb76a0e04189cf078b7e599f61eedec3a58c491f203c3`.

| Field | Client declaration | Default / relationship arguments | Source line |
|---|---|---|---|
| `Id` | `attr` | `null` | 26 |
| `Teacher` | `string` | `null` | 27 |
| `Category` | `string` | `null` | 28 |
| `SubjectId` | `attr` | `null` | 29 |
| `SubjectName` | `attr` | `null` | 30 |
| `Date` | `attr` | `null` | 31 |
| `AddDate` | `attr` | `null` | 32 |
| `Grade` | `attr` | `null` | 33 |
| `Description` | `string` | `null` | 34 |
| `Semester` | `attr` | `null` | 35 |
| `Comments` | `hasMany` | `GradeComments, 'GradeId', 'Id'` | 36 |
| `ImproveId` | `attr` | `null` | 37 |
| `Improvements` | `attr` | `[]` | 38 |
| `CountToTheAverage` | `attr` | `undefined` | 39 |
| `Weight` | `attr` | `undefined` | 40 |
| `SynergiaAccountId` | `attr` | `null` | 41 |
| `IsNew` | `boolean` | `false` | 42 |
| `Deleted` | `boolean` | `false` | 43 |
| `Type` | `string` | `this.entity` | 44 |
| `IsFinal` | `boolean` | `false` | 45 |
| `IsFinalProposition` | `boolean` | `false` | 46 |
| `IsSemestral` | `boolean` | `false` | 47 |
| `IsSemestralProposition` | `boolean` | `false` | 48 |

## HomeworkAssignments — 'homeworkassignments'

Source `src/viewmodels/homeworkAssignments.js`; entity `'homeworkassignments'`; primary key `['SynergiaAccountId', 'Id']`; source-content SHA256 `35b21c109fe57259e1f5043243c19e318957d99a739c98dba99ee990763269b4`.

| Field | Client declaration | Default / relationship arguments | Source line |
|---|---|---|---|
| `Id` | `attr` | `null` | 25 |
| `Teacher` | `string` | `null` | 26 |
| `Title` | `attr` | `null` | 27 |
| `Subject` | `string` | `''` | 28 |
| `AddDate` | `string` | `''` | 29 |
| `Date` | `string` | `''` | 30 |
| `Description` | `string` | `''` | 31 |
| `HasAttachment` | `boolean` | `false` | 32 |
| `HomeworkAssigmentFiles` | `attr` | `null` | 33 |
| `MustSendAttachFile` | `boolean` | `false` | 34 |
| `SendFilePossible` | `boolean` | `false` | 35 |
| `SynergiaAccountId` | `string` | `''` | 36 |
| `IsNew` | `boolean` | `false` | 37 |
| `Deleted` | `boolean` | `false` | 38 |
| `MarkedAsRead` | `boolean` | `false` | 39 |
| `MarkedAsDone` | `boolean` | `false` | 40 |
| `StudentAnswerSend` | `attr` | `null` | 41 |

## IndividualLearningPath — 'timetablesindividuallearningpath'

Source `src/viewmodels/individual-learing-path.js`; entity `'timetablesindividuallearningpath'`; primary key `['SynergiaAccountId', 'Id']`; source-content SHA256 `77ad237647579ee68536501a8774739f79a712403afd3b11bb0e546f4996242a`.

| Field | Client declaration | Default / relationship arguments | Source line |
|---|---|---|---|
| `Id` | `attr` | `null` | 26 |
| `SynergiaAccountId` | `attr` | `null` | 27 |
| `IsNew` | `boolean` | `false` | 28 |
| `Deleted` | `boolean` | `false` | 29 |
| `start` | `string` | `null` | 30 |
| `end` | `string` | `null` | 31 |
| `title` | `string` | `null` | 32 |
| `subject` | `string` | `null` | 33 |
| `teacher` | `string` | `null` | 34 |
| `class` | `string` | `null` | 35 |
| `date` | `string` | `null` | 36 |
| `customStyle` | `attr` | `null` | 37 |
| `type` | `string` | `null` | 38 |
| `lessonNo` | `string` | `null` | 39 |
| `description` | `string` | `null` | 40 |
| `classroom` | `string` | `null` | 41 |
| `substitutedLessonId` | `attr` | `null` | 42 |
| `isSubstituted` | `boolean` | `false` | 43 |
| `canceled` | `boolean` | `false` | 44 |
| `Reminder` | `morphOne` | `Reminder, 'ModelableId', 'ModelableType', '$id'` | 45 |

## Justifications — 'justifications'

Source `src/viewmodels/justifications.js`; entity `'justifications'`; primary key `['SynergiaAccountId', 'Id']`; source-content SHA256 `b4cd1e6c538d6bdee6658293b2bb0748ef8ffee2167506d9430c3fd1a565c1c8`.

| Field | Client declaration | Default / relationship arguments | Source line |
|---|---|---|---|
| `Id` | `string` | `null` | 25 |
| `PostDate` | `string` | `''` | 26 |
| `MessageFromParent` | `string` | `''` | 27 |
| `JustificationStatus` | `string` | `''` | 28 |
| `Lessons` | `attr` | `null` | 29 |
| `Attachment` | `boolean` | `false` | 30 |
| `DateFrom` | `string` | `''` | 31 |
| `DateTo` | `string` | `''` | 32 |
| `JustifiedAbsences` | `number` | `0` | 33 |
| `NotifiedTeachers` | `attr` | `null` | 34 |
| `SynergiaAccountId` | `string` | `''` | 35 |
| `IsNew` | `boolean` | `false` | 36 |
| `Deleted` | `boolean` | `false` | 37 |

## KindergartnerActivityType — 'kindergartnerActivityType'

Source `src/viewmodels/kindergartner-activity-type.js`; entity `'kindergartnerActivityType'`; primary key `['SynergiaAccountId', 'Id']`; source-content SHA256 `5a2783d77b3305fa7826e3656e062c8c52063bb5f74d692bc52a938bd1af4121`.

| Field | Client declaration | Default / relationship arguments | Source line |
|---|---|---|---|
| `Id` | `attr` | `null` | 25 |
| `Name` | `string` | `null` | 26 |
| `SynergiaAccountId` | `attr` | `null` | 27 |
| `IsNew` | `boolean` | `false` | 28 |
| `Deleted` | `boolean` | `false` | 29 |

## KindergartnersTimetable — 'kindergartnerstimetable'

Source `src/viewmodels/kindergartners-timetable.js`; entity `'kindergartnerstimetable'`; primary key `['SynergiaAccountId', 'Id']`; source-content SHA256 `ffad6e8c6d7b68b6b3a7e3a17a2d92f1ed9fb3dd31baa53937900f1de2b9d9fe`.

| Field | Client declaration | Default / relationship arguments | Source line |
|---|---|---|---|
| `Id` | `attr` | `null` | 25 |
| `Deleted` | `boolean` | `false` | 26 |
| `start` | `attr` | `null` | 27 |
| `end` | `attr` | `null` | 28 |
| `title` | `attr` | `null` | 29 |
| `subject` | `attr` | `null` | 30 |
| `teacher` | `attr` | `null` | 31 |
| `lessonNo` | `attr` | `null` | 32 |
| `description` | `attr` | `null` | 33 |
| `classroom` | `attr` | `null` | 34 |
| `class` | `attr` | `null` | 35 |
| `date` | `attr` | `null` | 36 |
| `allDay` | `attr` | `null` | 37 |
| `type` | `attr` | `'timetable'` | 38 |
| `customStyle` | `attr` | `() => ({ color: 'white' })` | 39 |
| `canceled` | `attr` | `false` | 40 |
| `isSubstitutionClass` | `attr` | `null` | 41 |
| `SynergiaAccountId` | `attr` | `null` | 42 |
| `changesData` | `attr` | `null` | 43 |

## Lessons — 'lessons'

Source `src/viewmodels/lessons.js`; entity `'lessons'`; primary key `['SynergiaAccountId', 'Id']`; source-content SHA256 `ff12a1e7bf18370664f3c07218ed2cb86e7fd6e50ffbd578bd348e4f79090a80`.

| Field | Client declaration | Default / relationship arguments | Source line |
|---|---|---|---|
| `Id` | `attr` | `null` | 25 |
| `Subject` | `attr` | `null` | 26 |
| `Teacher` | `attr` | `null` | 27 |
| `Class` | `attr` | `null` | 28 |
| `SynergiaAccountId` | `string` | `''` | 29 |
| `Canceled` | `boolean` | `false` | 30 |
| `IsNew` | `boolean` | `false` | 31 |
| `Deleted` | `boolean` | `false` | 32 |

## LibrusGoEvents — 'librusgoevents'

Source `src/viewmodels/librus-go-events.js`; entity `'librusgoevents'`; primary key `['LibrusGoAccountId', 'Id']`; source-content SHA256 `16eb2b1d416bfd7d49f4298ec8d870dcc37be6bb9ac1a1db0707a9852821cf9f`.

| Field | Client declaration | Default / relationship arguments | Source line |
|---|---|---|---|
| `Id` | `attr` | `null` | 25 |
| `Resource` | `string` | `null` | 26 |
| `Type` | `string` | `null` | 27 |
| `Version` | `string` | `null` | 28 |
| `Payload` | `attr` | `null` | 29 |
| `CreatedAt` | `string` | `null` | 30 |
| `IsNew` | `boolean` | `true` | 31 |
| `Deleted` | `boolean` | `false` | 32 |
| `GroupingOptions` | `attr` | `{ isVisible: true }` | 33 |
| `SortBy` | `number` | `null` | 34 |
| `IsLibrusGo` | `boolean` | `true` | 35 |
| `LibrusGoAccountId` | `string` | `''` | 36 |

## LuckyNumbers — 'luckynumbers'

Source `src/viewmodels/lucky-numbers.js`; entity `'luckynumbers'`; primary key `['SynergiaAccountId', 'Id']`; source-content SHA256 `3b5d3eedabc253e07e82be363f7ef50f5fd14aa7e1dac532cc4118a12e5b3a72`.

| Field | Client declaration | Default / relationship arguments | Source line |
|---|---|---|---|
| `Id` | `attr` | `null` | 25 |
| `LuckyNumber` | `attr` | `null` | 26 |
| `LuckyNumberDay` | `attr` | `null` | 27 |
| `SynergiaAccountId` | `string` | `''` | 28 |

## MealUpdates — 'mealupdates'

Source `src/viewmodels/meal-updates.js`; entity `'mealupdates'`; primary key `['SynergiaAccountId', 'Id']`; source-content SHA256 `064e2e832409ebb307088fc8b1a86ef47c0892201a1b4ada2b8b927b5dd1cf2a`.

| Field | Client declaration | Default / relationship arguments | Source line |
|---|---|---|---|
| `Id` | `attr` | `null` | 27 |
| `Title` | `string` | `''` | 28 |
| `Content` | `string` | `''` | 29 |
| `Date` | `string` | `''` | 30 |
| `Author` | `string` | `''` | 31 |
| `SynergiaAccountId` | `string` | `''` | 32 |
| `IsNew` | `boolean` | `false` | 33 |
| `Deleted` | `boolean` | `false` | 34 |
| `Attachments` | `attr` | `[]` | 35 |
| `Reminder` | `morphOne` | `Reminder, 'ModelableId', 'ModelableType', '$id'` | 36 |

## MessagesLibrusGo — 'messageslibrusgo'

Source `src/viewmodels/messages-librus-go.js`; entity `'messageslibrusgo'`; primary key `['LibrusGoAccountId', 'Id']`; source-content SHA256 `984b62e36831b161b27f5f5fe12e66f5e283ac88b672eb87d0412b659d3a556d`.

| Field | Client declaration | Default / relationship arguments | Source line |
|---|---|---|---|
| `Id` | `attr` | `null` | 25 |
| `LibrusGoAccountId` | `attr` | `null` | 26 |
| `Sender` | `attr` | `null` | 27 |
| `SenderId` | `attr` | `null` | 28 |
| `SendDate` | `attr` | `null` | 29 |
| `Receiver` | `attr` | `null` | 30 |
| `Title` | `attr` | `null` | 31 |
| `Description` | `attr` | `null` | 32 |
| `HasAttachment` | `boolean` | `false` | 33 |
| `InSent` | `boolean` | `true` | 34 |
| `IsNew` | `boolean` | `false` | 35 |
| `IsNote` | `attr` | `null` | 37 |
| `InTrash` | `attr` | `null` | 38 |
| `Deleted` | `boolean` | `false` | 39 |

## Messages — 'messages'

Source `src/viewmodels/messages.js`; entity `'messages'`; primary key `['SynergiaAccountId', 'Id']`; source-content SHA256 `8b10ccfd0a325d9a860957e5dd166146bced05ccedf496acf934f81322d6bc57`.

| Field | Client declaration | Default / relationship arguments | Source line |
|---|---|---|---|
| `Id` | `attr` | `null` | 26 |
| `Sender` | `attr` | `null` | 27 |
| `SenderId` | `attr` | `null` | 28 |
| `SendDate` | `attr` | `null` | 29 |
| `IsNote` | `attr` | `null` | 30 |
| `InSent` | `attr` | `null` | 31 |
| `InTrash` | `attr` | `null` | 32 |
| `HasAttachment` | `boolean` | `false` | 33 |
| `MessageFiles` | `attr` | `null` | 34 |
| `Title` | `attr` | `null` | 35 |
| `Description` | `attr` | `null` | 36 |
| `SynergiaAccountId` | `attr` | `null` | 37 |
| `IsNew` | `boolean` | `false` | 38 |
| `Deleted` | `boolean` | `false` | 39 |
| `ReadDates` | `attr` | `null` | 40 |
| `Receiver` | `attr` | `null` | 41 |
| `ReceiverMap` | `attr` | `null` | 42 |
| `IsPinned` | `boolean` | `false` | 43 |
| `Reminder` | `morphOne` | `Reminder, 'ModelableId', 'ModelableType', '$id'` | 44 |

## MyGoalsSummaries — 'mygoalssummaries'

Source `src/viewmodels/my-goals-summaries.js`; entity `'mygoalssummaries'`; primary key `['SynergiaAccountId', 'Id']`; source-content SHA256 `cbe4e9aaf36640d8bfd5ad7eb316c229a4d3a3bff4fe7417c85fc5939e4003f8`.

| Field | Client declaration | Default / relationship arguments | Source line |
|---|---|---|---|
| `Id` | `string` | `null` | 13 |
| `SynergiaAccountId` | `string` | `''` | 14 |
| `Date` | `string` | `null` | 15 |
| `GroupingOptions` | `attr` | `{ isVisible: true }` | 16 |
| `ComponentProps` | `attr` | `null` | 17 |
| `ComponentName` | `string` | `null` | 18 |
| `EventActionType` | `string` | `''` | 19 |
| `Type` | `string` | `null` | 20 |

## MyGoals — 'mygoals'

Source `src/viewmodels/my-goals.js`; entity `'mygoals'`; primary key `['synergiaAccountId', 'refId', 'period']`; source-content SHA256 `4c4523caa41bd14c20aaea3d2282c8075bcbdd656c8b147588f98b179f4b4ce8`.

| Field | Client declaration | Default / relationship arguments | Source line |
|---|---|---|---|
| `id` | `number` | `null` | 25 |
| `name` | `string` | `null` | 26 |
| `goal` | `number` | `0` | 27 |
| `type` | `string` | `''` | 28 |
| `refId` | `string` | `''` | 29 |
| `period` | `string` | `''` | 30 |
| `synergiaAccountId` | `string` | `''` | 31 |
| `properties` | `attr` | `{}` | 32 |

## NotesCategories — 'notescategories'

Source `src/viewmodels/notes-categories.js`; entity `'notescategories'`; primary key `['SynergiaAccountId', 'Id']`; source-content SHA256 `cf68aba4ce2b4f510c7c4a9d431fffcf4c925b98d9cf20333398476612eed28a`.

| Field | Client declaration | Default / relationship arguments | Source line |
|---|---|---|---|
| `Id` | `attr` | `null` | 25 |
| `Name` | `string` | `''` | 26 |
| `SynergiaAccountId` | `string` | `''` | 27 |
| `IsNew` | `boolean` | `false` | 28 |
| `Deleted` | `boolean` | `false` | 29 |

## Notes — 'notes'

Source `src/viewmodels/notes.js`; entity `'notes'`; primary key `['SynergiaAccountId', 'Id']`; source-content SHA256 `91900b301160ad73fdc3f3ae66cd6b5b7d37ecd6952b21fbe92885c252096b23`.

| Field | Client declaration | Default / relationship arguments | Source line |
|---|---|---|---|
| `Id` | `attr` | `null` | 25 |
| `Teacher` | `string` | `null` | 26 |
| `Category` | `attr` | `null` | 27 |
| `Type` | `string` | `''` | 28 |
| `Date` | `string` | `''` | 29 |
| `Description` | `string` | `''` | 30 |
| `SynergiaAccountId` | `string` | `''` | 31 |
| `IsNew` | `boolean` | `false` | 32 |
| `Deleted` | `boolean` | `false` | 33 |

## OneToOneLearningPlan — 'timetablesonetoonelearningplan'

Source `src/viewmodels/one-to-one-learning-plan.js`; entity `'timetablesonetoonelearningplan'`; primary key `['SynergiaAccountId', 'Id']`; source-content SHA256 `53d4b5066484e1516bb961cf80b145ef6ae92de345b632a57fe175370a0c104b`.

| Field | Client declaration | Default / relationship arguments | Source line |
|---|---|---|---|
| `Id` | `attr` | `null` | 26 |
| `SynergiaAccountId` | `attr` | `null` | 27 |
| `IsNew` | `boolean` | `false` | 28 |
| `Deleted` | `boolean` | `false` | 29 |
| `start` | `string` | `null` | 30 |
| `end` | `string` | `null` | 31 |
| `title` | `string` | `null` | 32 |
| `subject` | `string` | `null` | 33 |
| `teacher` | `string` | `null` | 34 |
| `class` | `string` | `null` | 35 |
| `date` | `string` | `null` | 36 |
| `customStyle` | `attr` | `null` | 37 |
| `type` | `string` | `null` | 38 |
| `lessonNo` | `string` | `null` | 39 |
| `description` | `string` | `null` | 40 |
| `classroom` | `string` | `null` | 41 |
| `substitutedLessonId` | `attr` | `null` | 42 |
| `isSubstituted` | `boolean` | `false` | 43 |
| `canceled` | `boolean` | `false` | 44 |
| `Reminder` | `morphOne` | `Reminder, 'ModelableId', 'ModelableType', '$id'` | 45 |

## OtherActivitiesRegister — 'timetablesotheractivitiesregister'

Source `src/viewmodels/other-activities-register.js`; entity `'timetablesotheractivitiesregister'`; primary key `['SynergiaAccountId', 'Id']`; source-content SHA256 `eb11beece188ddaa09b27917aa77161139defdfaa4fb028eef9209f4a335985e`.

| Field | Client declaration | Default / relationship arguments | Source line |
|---|---|---|---|
| `Id` | `attr` | `null` | 26 |
| `SynergiaAccountId` | `attr` | `null` | 27 |
| `IsNew` | `boolean` | `false` | 28 |
| `Deleted` | `boolean` | `false` | 29 |
| `start` | `string` | `null` | 30 |
| `end` | `string` | `null` | 31 |
| `title` | `string` | `null` | 32 |
| `subject` | `string` | `null` | 33 |
| `teacher` | `string` | `null` | 34 |
| `class` | `string` | `null` | 35 |
| `date` | `string` | `null` | 36 |
| `customStyle` | `attr` | `null` | 37 |
| `type` | `string` | `null` | 38 |
| `lessonNo` | `string` | `null` | 39 |
| `description` | `string` | `null` | 40 |
| `classroom` | `string` | `null` | 41 |
| `substitutedLessonId` | `attr` | `null` | 42 |
| `isSubstituted` | `boolean` | `false` | 43 |
| `canceled` | `boolean` | `false` | 44 |
| `Reminder` | `morphOne` | `Reminder, 'ModelableId', 'ModelableType', '$id'` | 45 |

## PartialDescriptiveGrades — 'partialdescriptivegrades'

Source `src/viewmodels/partial-descriptive-grades.js`; entity `'partialdescriptivegrades'`; primary key `['SynergiaAccountId', 'Id']`; source-content SHA256 `f8a45073ceb0287cf3911ca03e3595b3d6c619071a0265ab30d974bcb84b6559`.

| Field | Client declaration | Default / relationship arguments | Source line |
|---|---|---|---|
| `Id` | `attr` | `null` | 30 |
| `Grade` | `attr` | `null` | 32 |
| `Category` | `string` | `null` | 34 |
| `Description` | `string` | `null` | 36 |
| `Comments` | `attr` | `[]` | 38 |
| `Requirements` | `attr` | `[]` | 40 |
| `ScaleValue` | `attr` | `null` | 42 |
| `Teacher` | `string` | `null` | 45 |
| `SubjectId` | `attr` | `null` | 46 |
| `SubjectName` | `attr` | `null` | 47 |
| `LessonAssignmentId` | `attr` | `null` | 48 |
| `Date` | `attr` | `null` | 49 |
| `Semester` | `attr` | `null` | 50 |
| `SynergiaAccountId` | `attr` | `null` | 51 |
| `Improvements` | `attr` | `[]` | 53 |
| `Color` | `string` | `''` | 54 |
| `IsNew` | `boolean` | `false` | 55 |
| `Deleted` | `boolean` | `false` | 56 |
| `Type` | `string` | `this.entity` | 57 |

## PlannedLessons — 'plannedlessons'

Source `src/viewmodels/planned-lessons.js`; entity `'plannedlessons'`; primary key `['SynergiaAccountId', 'Id']`; source-content SHA256 `6f40832a07ffe08714476026556f0013cfba873d18c8586a072be0d454e67578`.

| Field | Client declaration | Default / relationship arguments | Source line |
|---|---|---|---|
| `Id` | `attr` | `null` | 25 |
| `Lesson` | `string` | `null` | 26 |
| `Subject` | `string` | `null` | 27 |
| `Date` | `string` | `null` | 28 |
| `DateFormatted` | `string` | `null` | 29 |
| `TimeFrom` | `string` | `null` | 30 |
| `TimeTo` | `string` | `null` | 31 |
| `Topic` | `string` | `null` | 32 |
| `IsTrip` | `boolean` | `false` | 33 |
| `Teacher` | `string` | `null` | 34 |
| `Title` | `string` | `null` | 35 |
| `HasAttachment` | `boolean` | `false` | 36 |
| `LessonFiles` | `attr` | `null` | 37 |
| `LessonLinks` | `attr` | `null` | 38 |
| `SynergiaAccountId` | `string` | `''` | 39 |
| `Canceled` | `boolean` | `false` | 40 |
| `IsNew` | `boolean` | `false` | 41 |
| `Deleted` | `boolean` | `false` | 42 |

## PointGradesCategories — 'pointgradescategories'

Source `src/viewmodels/point-grades-categories.js`; entity `'pointgradescategories'`; primary key `['SynergiaAccountId', 'Id']`; source-content SHA256 `0515f311121c7e92128e5ccf588b34eb745cccb9b747926c4a58f550e5b33de8`.

| Field | Client declaration | Default / relationship arguments | Source line |
|---|---|---|---|
| `Id` | `attr` | `null` | 23 |
| `Name` | `string` | `null` | 24 |
| `Short` | `string` | `null` | 25 |
| `ObligationToPerform` | `boolean` | `false` | 26 |
| `Weight` | `number` | `1` | 27 |
| `CountToTheAverage` | `boolean` | `true` | 28 |
| `DontCountToPot` | `number` | `0` | 29 |
| `TypeOfCount` | `number` | `1` | 30 |
| `ValueFrom` | `number` | `0` | 31 |
| `ValueTo` | `number` | `100` | 32 |
| `SynergiaAccountId` | `attr` | `null` | 33 |
| `IsNew` | `boolean` | `false` | 34 |
| `Deleted` | `boolean` | `false` | 35 |

## Grades — 'pointgrades'

Source `src/viewmodels/point-grades.js`; entity `'pointgrades'`; primary key `['SynergiaAccountId', 'Id']`; source-content SHA256 `654e3209c6c6115370bda2e5336f15791e3b09daa7a8918ff6713bc469c247c4`.

| Field | Client declaration | Default / relationship arguments | Source line |
|---|---|---|---|
| `Id` | `attr` | `null` | 26 |
| `Teacher` | `string` | `null` | 27 |
| `Category` | `string` | `null` | 28 |
| `SubjectId` | `attr` | `null` | 29 |
| `SubjectName` | `attr` | `null` | 30 |
| `Date` | `attr` | `null` | 31 |
| `AddDate` | `attr` | `null` | 32 |
| `Grade` | `attr` | `null` | 33 |
| `GradeValue` | `attr` | `null` | 34 |
| `Description` | `string` | `null` | 35 |
| `Semester` | `attr` | `null` | 36 |
| `Comments` | `hasMany` | `GradeComments, 'GradeId', 'Id'` | 37 |
| `Improvements` | `attr` | `[]` | 38 |
| `Weight` | `attr` | `undefined` | 39 |
| `CountToTheAverage` | `attr` | `undefined` | 40 |
| `SynergiaAccountId` | `attr` | `null` | 41 |
| `IsNew` | `boolean` | `false` | 42 |
| `Deleted` | `boolean` | `false` | 43 |
| `Type` | `string` | `this.entity` | 44 |

## RealizedLessons — 'realizedlessons'

Source `src/viewmodels/realized-lessons.js`; entity `'realizedlessons'`; primary key `['SynergiaAccountId', 'Id']`; source-content SHA256 `8eb8a317c39fbe3892432d04b6a4f5eedd01f3f824e0b98cf46ab7229546864a`.

| Field | Client declaration | Default / relationship arguments | Source line |
|---|---|---|---|
| `Id` | `attr` | `null` | 25 |
| `Lesson` | `string` | `null` | 26 |
| `Subject` | `string` | `null` | 27 |
| `Date` | `string` | `null` | 28 |
| `DateFormatted` | `string` | `null` | 29 |
| `TimeFrom` | `string` | `null` | 30 |
| `TimeTo` | `string` | `null` | 31 |
| `Topic` | `string` | `null` | 32 |
| `IsTrip` | `boolean` | `false` | 33 |
| `Teacher` | `string` | `null` | 34 |
| `Title` | `string` | `null` | 35 |
| `HasAttachment` | `boolean` | `false` | 36 |
| `LessonFiles` | `attr` | `null` | 37 |
| `LessonLinks` | `attr` | `null` | 38 |
| `EBoard` | `boolean` | `false` | 39 |
| `SynergiaAccountId` | `string` | `''` | 40 |
| `Canceled` | `boolean` | `false` | 41 |
| `IsNew` | `boolean` | `false` | 42 |
| `Deleted` | `boolean` | `false` | 43 |

## Reminder — 'reminders'

Source `src/viewmodels/reminders.js`; entity `'reminders'`; primary key `['SynergiaAccountId', 'Id']`; source-content SHA256 `a88657f01b588a3497c1a476c94ef636c430b4eb8ce4350fe9d7b87abefd3766`.

| Field | Client declaration | Default / relationship arguments | Source line |
|---|---|---|---|
| `Id` | `string` | `null` | 23 |
| `DateTime` | `string` | `null` | 24 |
| `PredefinedPeriod` | `attr` | `null` | 25 |
| `SynergiaAccountId` | `attr` | `null` | 26 |
| `LessonData` | `attr` | `null), // for proper lesson ID and time data` | 27 |
| `IsCyclic` | `boolean` | `false` | 28 |
| `ModelableId` | `attr` | `null` | 29 |
| `ModelableType` | `attr` | `null` | 30 |
| `ModelableApiId` | `attr` | `null` | 31 |
| `ModelableResourceName` | `attr` | `null` | 32 |
| `Modelable` | `morphTo` | `'ModelableId', 'ModelableType'` | 33 |
| `PushTitle` | `string` | `null` | 34 |
| `PushBody` | `string` | `null` | 35 |

## ClassAndSchoolInfoLibrusGo — 'schoolInfoLibrusGo'

Source `src/viewmodels/school-info-librus-go.js`; entity `'schoolInfoLibrusGo'`; primary key `'LibrusGoAccountId'`; source-content SHA256 `f10535c0d17520caeedba1f731f691a9325e3461e15836a105a6bce737916107`.

| Field | Client declaration | Default / relationship arguments | Source line |
|---|---|---|---|
| `LibrusGoAccountId` | `attr` | `null` | 25 |
| `SchoolName` | `string` | `''` | 26 |
| `SchoolShortName` | `string` | `''` | 27 |
| `SchoolStreet` | `string` | `''` | 28 |
| `SchoolCity` | `string` | `''` | 29 |
| `SchoolPhone` | `string` | `''` | 30 |
| `SchoolWebsite` | `string` | `''` | 31 |
| `SchoolEmail` | `string` | `''` | 32 |
| `AdditionalInfo` | `string` | `''` | 33 |

## Schools — 'schools'

Source `src/viewmodels/schools.js`; entity `'schools'`; primary key `['SynergiaAccountId', 'Id']`; source-content SHA256 `5145843f20e501ddb658307cce6350169822357c075c0bd7f8944e5bf6e6a05c`.

| Field | Client declaration | Default / relationship arguments | Source line |
|---|---|---|---|
| `Id` | `attr` | `null` | 25 |
| `ApartmentNumber` | `attr` | `null` | 26 |
| `BuildingNumber` | `attr` | `null` | 27 |
| `LessonsRange` | `attr` | `null` | 28 |
| `Name` | `attr` | `null` | 29 |
| `SchoolYear` | `attr` | `null` | 30 |
| `State` | `attr` | `null` | 31 |
| `Street` | `attr` | `null` | 32 |
| `Town` | `attr` | `null` | 33 |
| `SynergiaAccountId` | `attr` | `null` | 34 |
| `IsNew` | `boolean` | `false` | 35 |
| `Deleted` | `boolean` | `false` | 36 |

## Event — 'specialEntries'

Source `src/viewmodels/special-entries.js`; entity `'specialEntries'`; primary key `'Id'`; source-content SHA256 `f0e90dc1122098c6991e8d0c546e51c53b654d04c894e2c88d2e09f2eba86f26`.

| Field | Client declaration | Default / relationship arguments | Source line |
|---|---|---|---|
| `Id` | `attr` | `null` | 25 |
| `EntryId` | `attr` | `null` | 26 |
| `ComponentName` | `string` | `null` | 27 |
| `SpecialType` | `string` | `null` | 28 |
| `IsNew` | `boolean` | `true` | 29 |
| `Date` | `attr` | `null` | 30 |
| `ExpirationDate` | `attr` | `null` | 31 |
| `Title` | `attr` | `null` | 32 |
| `Sender` | `attr` | `null` | 33 |
| `Icon` | `attr` | `null` | 34 |
| `Link` | `attr` | `null` | 35 |
| `Image` | `attr` | `null` | 36 |
| `Content` | `attr` | `null` | 37 |
| `Footer` | `attr` | `null` | 38 |
| `Meta` | `attr` | `null` | 39 |
| `SortBy` | `number` | `null` | 40 |
| `Videos` | `attr` | `[]` | 41 |
| `CarouselImages` | `attr` | `[]` | 42 |
| `SponsoredArticle` | `boolean` | `null` | 43 |

## Subjects — 'subjects'

Source `src/viewmodels/subjects.js`; entity `'subjects'`; primary key `['SynergiaAccountId', 'Id']`; source-content SHA256 `369d298d889d9fa2bcba2b52df4286abfbef5fb63a73ed80381cc1896a0fdeb6`.

| Field | Client declaration | Default / relationship arguments | Source line |
|---|---|---|---|
| `Id` | `attr` | `null` | 36 |
| `Name` | `string` | `null` | 37 |
| `Averages` | `hasMany` | `Averages, 'SubjectId', 'Id'` | 38 |
| `Grades` | `hasMany` | `Grades, 'SubjectId', 'Id'` | 39 |
| `PointGrades` | `hasMany` | `PointGrades, 'SubjectId', 'Id'` | 40 |
| `DescriptiveGrades` | `hasMany` | `DescriptiveGrades, 'SubjectId', 'Id'` | 41 |
| `DescriptiveGradesText` | `hasMany` | `DescriptiveGradesText, 'SubjectId', 'Id'` | 42 |
| `DescriptiveTextGrades` | `hasMany` | `DescriptiveTextGrades, 'SubjectId', 'Id'` | 43 |
| `PartialDescriptiveGrades` | `hasMany` | `PartialDescriptiveGrades, 'SubjectId', 'Id'` | 44 |
| `TextGrades` | `hasMany` | `TextGrades, 'SubjectId', 'Id'` | 45 |
| `BehaviourGradesPoints` | `hasMany` | `BehaviourGradesPoints, 'SubjectId', 'Id'` | 46 |
| `BehaviourGrades` | `hasMany` | `BehaviourGrades, 'SubjectId', 'Id'` | 47 |
| `BehaviourGradesSystemProposal` | `hasMany` | `BehaviourGradesSystemProposal, 'SubjectId', 'Id'` | 48 |
| `SynergiaAccountId` | `attr` | `null` | 49 |
| `IsNew` | `boolean` | `false` | 50 |
| `Deleted` | `boolean` | `false` | 51 |

## Grades — 'textgrades'

Source `src/viewmodels/text-grades.js`; entity `'textgrades'`; primary key `['SynergiaAccountId', 'Id']`; source-content SHA256 `ecae1153aa18c47420e69f49a37ada803946cdc6606ad4c3d0da759bad2384be`.

| Field | Client declaration | Default / relationship arguments | Source line |
|---|---|---|---|
| `Id` | `attr` | `null` | 26 |
| `Teacher` | `string` | `null` | 27 |
| `Category` | `string` | `null` | 28 |
| `SubjectId` | `number` | `null` | 29 |
| `SubjectName` | `attr` | `null` | 30 |
| `Date` | `attr` | `null` | 31 |
| `AddDate` | `attr` | `null` | 32 |
| `Grade` | `attr` | `null` | 33 |
| `Description` | `string` | `null` | 34 |
| `Semester` | `attr` | `null` | 35 |
| `Comments` | `hasMany` | `GradeComments, 'GradeId', 'Id'` | 36 |
| `ImproveId` | `attr` | `null` | 37 |
| `Improvements` | `attr` | `[]` | 38 |
| `SynergiaAccountId` | `attr` | `null` | 39 |
| `IsNew` | `boolean` | `false` | 40 |
| `Deleted` | `boolean` | `false` | 41 |
| `Type` | `string` | `this.entity` | 42 |

## TimetablesCustomEvent — 'timetablescustomevents'

Source `src/viewmodels/timetables-custom-event.js`; entity `'timetablescustomevents'`; primary key `['Id']`; source-content SHA256 `a9253d977b13194e40478a5d15af99a8e47cf6958dabcc68211885e2d8a11d0c`.

| Field | Client declaration | Default / relationship arguments | Source line |
|---|---|---|---|
| `Id` | `attr` | `null` | 26 |
| `IsNew` | `boolean` | `false` | 27 |
| `Deleted` | `boolean` | `false` | 28 |
| `GroupingOptions` | `attr` | `{ isVisible: true }` | 29 |
| `SortBy` | `number` | `null` | 30 |
| `synergiaAccountId` | `string` | `null` | 31 |
| `customStyle` | `attr` | `null` | 32 |
| `type` | `string` | `null` | 33 |
| `dateFrom` | `string` | `null` | 34 |
| `dateTo` | `string` | `null` | 35 |
| `endUnspecified` | `boolean` | `true` | 36 |
| `entry` | `attr` | `null` | 37 |
| `Reminder` | `morphOne` | `Reminder, 'ModelableId', 'ModelableType', '$id'` | 38 |

## TimetablesLibrusGo — 'timetableslibrusgo'

Source `src/viewmodels/timetables-librus-go.js`; entity `'timetableslibrusgo'`; primary key `['LibrusGoAccountId', 'Id']`; source-content SHA256 `1a7f54306e51c208a8dabce0455aae8d5081db24139bb48d1bf44f903346def4`.

| Field | Client declaration | Default / relationship arguments | Source line |
|---|---|---|---|
| `Id` | `attr` | `null` | 25 |
| `start` | `attr` | `null` | 26 |
| `end` | `attr` | `null` | 27 |
| `title` | `attr` | `null` | 28 |
| `date` | `attr` | `null` | 29 |
| `cycleName` | `attr` | `null` | 30 |
| `activityName` | `attr` | `null` | 31 |
| `activityId` | `attr` | `null` | 32 |
| `activityGroupName` | `attr` | `null` | 33 |
| `activityGroupId` | `attr` | `null` | 34 |
| `note` | `attr` | `null` | 35 |
| `places` | `attr` | `null` | 36 |
| `onlineMeetings` | `attr` | `null` | 37 |
| `canceled` | `attr` | `null` | 38 |
| `tutors` | `attr` | `null` | 39 |
| `customStyle` | `attr` | `null` | 40 |
| `type` | `attr` | `null` | 41 |
| `onlineLessonUrl` | `attr` | `null` | 42 |
| `LibrusGoAccountId` | `attr` | `null` | 43 |
| `IsNew` | `boolean` | `false` | 44 |
| `Deleted` | `boolean` | `false` | 45 |

## Timetables — 'timetables'

Source `src/viewmodels/timetables.js`; entity `'timetables'`; primary key `['SynergiaAccountId', 'Id', 'start']`; source-content SHA256 `cbb6b403970f2f68fc18af6c960620e81680c34aac776b967e456ab0ca9818a6`.

| Field | Client declaration | Default / relationship arguments | Source line |
|---|---|---|---|
| `Id` | `attr` | `null` | 26 |
| `IsNew` | `boolean` | `false` | 27 |
| `Deleted` | `boolean` | `false` | 28 |
| `Reminder` | `morphOne` | `Reminder, 'ModelableId', 'ModelableType', '$id'` | 29 |
| `start` | `attr` | `null` | 30 |
| `end` | `attr` | `null` | 31 |
| `title` | `attr` | `null` | 32 |
| `subject` | `attr` | `null` | 33 |
| `teacher` | `attr` | `null` | 34 |
| `lessonNo` | `attr` | `null` | 35 |
| `description` | `attr` | `null` | 36 |
| `classroom` | `attr` | `null` | 37 |
| `class` | `attr` | `null` | 38 |
| `date` | `attr` | `null` | 39 |
| `type` | `attr` | `null` | 40 |
| `customStyle` | `attr` | `null` | 41 |
| `canceled` | `boolean` | `false` | 42 |
| `isSubstitutionClass` | `boolean` | `false` | 43 |
| `allDay` | `boolean` | `false` | 44 |
| `SynergiaAccountId` | `attr` | `null` | 45 |

## VideoMaterials — 'videomaterials'

Source `src/viewmodels/video-materials.js`; entity `'videomaterials'`; primary key `'Id'`; source-content SHA256 `1e4236892df1f6f0cfdc4eef7523cff9129c8316c956ccfcc1c9228ff5de82cc`.

| Field | Client declaration | Default / relationship arguments | Source line |
|---|---|---|---|
| `Id` | `attr` | `null` | 27 |
| `Title` | `string` | `''` | 28 |
| `Type` | `string` | `'Training'` | 29 |
| `Duration` | `number` | `0` | 30 |
| `DurationFormatted` | `string` | `'0:00'` | 31 |
| `ThumbnailUrl` | `string` | `null` | 32 |
| `ThumbnailWidth` | `number` | `0` | 33 |
| `ThumbnailHeight` | `number` | `0` | 34 |
| `HeroImageUrl` | `string` | `null` | 35 |
| `PresenterName` | `string` | `'Unknown'` | 36 |
| `PresenterAvatarUrl` | `string` | `null` | 37 |
| `CreatedAt` | `string` | `null` | 38 |
| `Description` | `attr` | `null` | 39 |
| `MainVideo` | `attr` | `null` | 40 |
| `Presenters` | `attr` | `[]` | 41 |
| `PresenterDescription` | `string` | `''` | 42 |
| `Categories` | `attr` | `[]` | 43 |
| `FilterCodes` | `attr` | `[]` | 44 |
| `LastProgressTime` | `number` | `0` | 45 |

## BaseModel — 'baseModel'

Source `src/models/base-model.js`; entity `'baseModel'`; primary key `'Id'`; source-content SHA256 `56a39736a87696a1b9f9a6bc849e907c3bd51eb9dc2e765578ad8ad6d5f065f2`.

| Field | Client declaration | Default / relationship arguments | Source line |
|---|---|---|---|
| `Id` | `attr` | `null` | 25 |

## PushConfiguration — 'pushConfiguration'

Source `src/models/push-configuration.js`; entity `'pushConfiguration'`; primary key `None`; source-content SHA256 `fc78ee76d343a9088aaaa0699d4d82d915642f20bf190a9572661d2b6d74ff0f`.

| Field | Client declaration | Default / relationship arguments | Source line |
|---|---|---|---|
| `id` | `string` | `''` | 22 |
| `grades` | `boolean` | `true` | 23 |
| `attendances` | `boolean` | `true` | 24 |
| `calendars` | `boolean` | `true` | 25 |
| `notes` | `boolean` | `true` | 26 |
| `homeWorks` | `boolean` | `true` | 27 |
| `notices` | `boolean` | `true` | 28 |
| `silentNight` | `boolean` | `false` | 29 |
| `messages` | `boolean` | `true` | 30 |
| `luckyNumbers` | `boolean` | `true` | 31 |
| `timeTables` | `boolean` | `true` | 32 |
| `individualLearningPathTimeTables` | `boolean` | `true` | 33 |
| `oneToOneLearningPlanTimeTables` | `boolean` | `true` | 34 |
| `otherActivitiesRegisterTimeTables` | `boolean` | `true` | 35 |
| `plannedLessons` | `boolean` | `true` | 36 |
| `realizations` | `boolean` | `true` | 37 |
| `teacherSchoolClassFreeDays` | `boolean` | `true` | 38 |
| `zamowPosilekBalance` | `boolean` | `true` | 39 |
| `zamowPosilekNews` | `boolean` | `true` | 40 |

## Semester — 'semester'

Source `src/models/semester.js`; entity `'semester'`; primary key `'Id'`; source-content SHA256 `13a5656da36a9b3c6427a4b673d226e4c240c78417331e48bcc3d47cdf70090d`.

| Field | Client declaration | Default / relationship arguments | Source line |
|---|---|---|---|
| `Id` | `attr` | `null` | 25 |
| `EndFirstSemester` | `attr` | `null` | 26 |
| `EndSchoolYear` | `attr` | `null` | 27 |

## Users — 'users'

Source `src/models/users.js`; entity `'users'`; primary key `['SynergiaAccountId', 'Id']`; source-content SHA256 `2c35946640baf95af97848d8ba752162ff2f7d6e3db0f73241a370822d3a1d56`.

| Field | Client declaration | Default / relationship arguments | Source line |
|---|---|---|---|
| `Id` | `attr` | `null` | 25 |
| `AccountId` | `string` | `null` | 26 |
| `FirstName` | `string` | `null` | 27 |
| `LastName` | `string` | `null` | 28 |
| `SynergiaAccountId` | `string` | `null` | 29 |
| `IsSchoolAdministrator` | `boolean` | `false` | 30 |
| `Deleted` | `boolean` | `false` | 31 |
