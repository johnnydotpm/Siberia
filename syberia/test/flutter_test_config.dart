import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Runs before every test file in this directory.
///
/// Tests have no app directory. Answering path_provider at once makes the
/// snapshot store keep the snapshot in SharedPreferences, as on the web;
/// without an answer a widget test would wait for the platform forever.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (_) async => null,
      );
  await testMain();
}
