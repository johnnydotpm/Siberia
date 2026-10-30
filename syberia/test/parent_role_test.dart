import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syberia/src/app.dart';
import 'package:syberia/src/domain/models.dart';
import 'package:syberia/src/domain/profiles.dart';
import 'package:syberia/src/domain/together.dart';
import 'package:syberia/src/state/app_controller.dart';

import 'support/profile_fakes.dart';

/// The parent's login with both accounts of its child, the parent's open.
Future<(AppController, FakeLibrusWorld, SchoolProfile, SchoolProfile)>
_parentLogin() async {
  SharedPreferences.setMockInitialValues({
    'auto_sync_on_open_v1': false,
    'app_design_v1': 'classic',
    'app_locale_v1': 'en',
  });
  final world = FakeLibrusWorld()..syncedAt = DateTime.now;
  final repository = world.repository();
  final found = await repository.signIn(username: parentEmail, password: 'x');
  final added = await repository.addProfiles(found.students);
  for (final profile in added) {
    await repository.syncProfile(profile.id);
  }
  final parent = added.firstWhere((profile) => profile.parent);
  final student = added.firstWhere((profile) => !profile.parent);
  await repository.switchProfile(parent.id);
  final controller = AppController(repository, updatesEnabled: false);
  await controller.bootstrap();
  return (controller, world, parent, student);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a profile keeps who uses it; one saved before reads as its account '
      'says', () {
    const profile = SchoolProfile(
      id: 'p',
      account: 'a',
      synergiaLogin: 'u',
      name: 'Uczeń',
    );
    expect(profile.usedBy, ProfileRole.student);
    expect(profile.copyWith(parent: true).usedBy, ProfileRole.parent);
    final parent = profile.copyWith(role: () => ProfileRole.parent);
    expect(SchoolProfile.fromJson(parent.toJson()), parent);
    expect(SchoolProfile.fromJson(parent.toJson())!.usedBy, ProfileRole.parent);
    final old = profile.toJson()..remove('role');
    expect(SchoolProfile.fromJson(old)!.role, isNull);
    expect(SchoolProfile.fromJson({...old, 'role': 'teacher'})!.role, isNull);
  });

  test('who uses a profile is kept, and decides whether a parent looks at '
      'the open view', () async {
    final (controller, world, parent, student) = await _parentLogin();
    expect(controller.parentView, isTrue);

    await controller.switchProfile(student.id);
    expect(controller.parentView, isFalse);
    await controller.setProfileRole(student.id, ProfileRole.parent);
    expect(controller.parentView, isTrue);
    expect(controller.profileOf(student.id)!.role, ProfileRole.parent);

    // The account's own role is kept as none, so it never goes stale.
    await controller.setProfileRole(student.id, ProfileRole.student);
    expect(controller.profileOf(student.id)!.role, isNull);
    await controller.setProfileRole(student.id, ProfileRole.parent);

    final again = AppController(world.repository(), updatesEnabled: false);
    await again.bootstrap();
    expect(again.profileOf(student.id)!.usedBy, ProfileRole.parent);

    // All together: a parent's view only when every profile in it is.
    await controller.openTogether();
    expect(controller.parentView, isTrue);
    await controller.setProfileRole(student.id, ProfileRole.student);
    expect(controller.parentView, isFalse);
  });

  test('a parent\'s profile writes from the parent\'s account', () async {
    final (controller, _, parent, _) = await _parentLogin();
    expect(controller.activeProfile!.id, parent.id);
    await controller.sendMessage(
      recipients: const [
        MessageRecipient(id: 1, name: 'Nauczyciel', group: ''),
      ],
      subject: 'Usprawiedliwienie',
      body: 'Treść',
    );
    final sent = controller.snapshot.sentMessages.single;
    expect(localId(sent.id, sent.source), 'sent-child-parent');
  });

  testWidgets('a profile\'s actions say who uses it, and change it', (
    tester,
  ) async {
    final (controller, _, _, student) = await _parentLogin();
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(SyberiaApp(controller: controller));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('profile-button')).first);
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byKey(ValueKey('profile-${student.id}')),
        matching: find.byIcon(Icons.more_horiz_rounded),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Who uses this profile'), findsOneWidget);
    SegmentedButton<ProfileRole> picker() => tester.widget(
      find.descendant(
        of: find.byKey(const ValueKey('profile-role')),
        matching: find.byType(SegmentedButton<ProfileRole>),
      ),
    );
    expect(picker().selected, {ProfileRole.student});

    await tester.tap(find.byKey(const ValueKey('profile-role-parent')));
    await tester.pumpAndSettle();
    expect(controller.profileOf(student.id)!.usedBy, ProfileRole.parent);
    expect(picker().selected, {ProfileRole.parent});
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
