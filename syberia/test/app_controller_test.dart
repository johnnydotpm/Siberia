import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syberia/src/app_build_info.dart';
import 'package:syberia/src/data/app_repository.dart';
import 'package:syberia/src/domain/models.dart';
import 'package:syberia/src/state/app_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // The repository opens the preferences when it is created. Without a mock
  // that fails in the background and can fail whichever test is running.
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('compares GitHub release versions', () {
    expect(isNewerVersion('v1.1.0', '1.0.9'), isTrue);
    expect(isNewerVersion('1.0.0', '1.0.0'), isFalse);
    expect(isNewerVersion('v1.0.0', '1.1.0'), isFalse);
    expect(isNewerVersion('2.0', '1.9.9'), isTrue);
  });

  test('shows and dismisses an update for the installed version', () async {
    final repository = _UpdateRepository();
    final controller = AppController(repository, updatesEnabled: false);
    await controller.bootstrap();
    await controller.checkForUpdate();

    expect(controller.updateAvailable, isTrue);
    expect(controller.latestVersion, 'v2.0.0');

    await controller.dismissUpdate();
    expect(controller.updateAvailable, isFalse);
    expect(repository.dismissedVersion, AppBuildInfo.version);

    await controller.setAttendanceChartStyle(AttendanceChartStyle.pie);
    expect(controller.attendanceChartStyle, AttendanceChartStyle.pie);
    expect(repository.chartStyle, AttendanceChartStyle.pie);

    expect(controller.design, AppDesign.glass);
    await controller.setDesign(AppDesign.classic);
    expect(controller.design, AppDesign.classic);
    expect(repository.design, AppDesign.classic);
  });
}

class _UpdateRepository extends AppRepository {
  String? dismissedVersion;
  AttendanceChartStyle chartStyle = AttendanceChartStyle.ring;
  AppDesign design = AppDesign.glass;

  @override
  Future<String?> loadLocale() async => null;

  @override
  Future<bool> loadAutoSyncOnOpen() async => true;

  @override
  Future<AttendanceChartStyle> loadAttendanceChartStyle() async => chartStyle;

  @override
  Future<void> saveAttendanceChartStyle(AttendanceChartStyle style) async {
    chartStyle = style;
  }

  @override
  Future<AppDesign> loadDesign() async => design;

  @override
  Future<void> saveDesign(AppDesign design) async {
    this.design = design;
  }

  @override
  Future<AppSnapshot> load() async => AppSnapshot(
    profile: const StudentProfile(
      id: 'signed-out',
      name: 'SiberiaGB',
      school: '',
      provider: 'Signed out',
    ),
    lessons: const [],
    grades: const [],
    events: const [],
    messages: const [],
    attendance: const [],
    announcements: const [],
    notices: const [],
    lastSync: DateTime.fromMillisecondsSinceEpoch(0),
  );

  @override
  Future<String?> loadDismissedUpdateVersion() async => dismissedVersion;

  @override
  Future<String?> fetchLatestReleaseVersion() async => 'v2.0.0';

  @override
  Future<void> dismissUpdatesForVersion(String version) async {
    dismissedVersion = version;
  }

  // The real one would reach Librus; the Today look-ahead asks for weeks.
  @override
  Future<List<Lesson>> fetchTimetableWeek(DateTime day) async => const [];
}
