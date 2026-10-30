import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syberia/src/network_vpn.dart';
import 'package:syberia/src/ui/brand/brand_events.dart';

/// Runs before every test file in this directory.
///
/// Tests have no app directory. Answering path_provider at once makes the
/// snapshot store keep the snapshot in SharedPreferences, as on the web;
/// without an answer a widget test would wait for the platform forever.
/// For the same reason every test gets an empty secure storage in memory.
/// The logo follows the calendar, so tests run on an ordinary day unless
/// they pick one; and the phone has no VPN on unless a test says so.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (_) async => null,
      );
  setUp(() {
    FlutterSecureStoragePlatform.instance = TestFlutterSecureStoragePlatform(
      {},
    );
    BrandEvents.clock = () => DateTime(2026, 10, 20, 12);
    BrandEvents.override = null;
    Vpn.simulated = false;
    Vpn.check = () async => false;
  });
  await testMain();
}
