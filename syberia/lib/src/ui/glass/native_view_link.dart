import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';

/// Keeps one UIKit platform view in step with the parameters Flutter builds
/// for it.
///
/// A platform view receives its parameters once, when UIKit creates it. Later
/// changes travel over a channel named after the view, and only when the
/// parameters really differ.
class NativeViewLink {
  NativeViewLink(this.viewType, {this._onCall});

  final String viewType;
  final Future<void> Function(MethodCall call)? _onCall;

  MethodChannel? _channel;
  Map<String, Object?> _params = const {};
  String? _sent;

  /// The parameters of the current frame, also used to create the view.
  Map<String, Object?> get params => _params;

  void update(Map<String, Object?> params) {
    _params = params;
    _flush();
  }

  /// Called once UIKit has created the view with [viewId].
  void attach(int viewId) {
    _channel?.setMethodCallHandler(null);
    _channel = MethodChannel('$viewType/$viewId')
      ..setMethodCallHandler(_onCall);
    // The widget may have been rebuilt while the view was being created.
    _sent = null;
    _flush();
  }

  void dispose() {
    _channel?.setMethodCallHandler(null);
    _channel = null;
  }

  void _flush() {
    final channel = _channel;
    if (channel == null) return;
    final encoded = jsonEncode(_params);
    if (encoded == _sent) return;
    _sent = encoded;
    unawaited(_send(channel, _params));
  }

  static Future<void> _send(
    MethodChannel channel,
    Map<String, Object?> params,
  ) async {
    try {
      await channel.invokeMethod<void>('update', params);
    } on PlatformException {
      // The view is being torn down; its successor starts from fresh values.
    } on MissingPluginException {
      // Same as above.
    }
  }
}
