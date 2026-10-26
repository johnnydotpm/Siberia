import 'dart:io' show NetworkInterface;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'domain/librus_error.dart';

/// Whether a VPN carries the phone's traffic. Librus sometimes blocks VPNs,
/// so the app says so, but only while one is on.
abstract final class Vpn {
  static const _channel = MethodChannel('app.syberia.client/vpn');

  /// Set in the debug menu: a VPN is said to be on whatever the phone says.
  static bool simulated = false;

  /// What the phone says; tests answer for it.
  @visibleForTesting
  static Future<bool?> Function() check = _ask;

  /// True with a VPN on, false without, and null where the app cannot tell:
  /// on Windows, macOS and the web, or when the phone does not answer.
  static Future<bool?> isActive() async => simulated ? true : await phone();

  /// What the phone itself says, whatever the debug menu simulates.
  static Future<bool?> phone() => check();

  static Future<bool?> _ask() async {
    if (kIsWeb) return null;
    try {
      switch (defaultTargetPlatform) {
        case TargetPlatform.android:
        case TargetPlatform.iOS:
          return await _channel.invokeMethod<bool>('active');
        case TargetPlatform.linux:
          final interfaces = await NetworkInterface.list();
          return interfaces.any(
            (interface) => _tunnel.hasMatch(interface.name),
          );
        case TargetPlatform.windows:
        case TargetPlatform.macOS:
        case TargetPlatform.fuchsia:
          return null;
      }
    } on Object {
      return null;
    }
  }

  /// The names Linux gives tunnels: OpenVPN's tun and tap, WireGuard's wg,
  /// and ppp.
  static final _tunnel = RegExp(r'^(tun|tap|wg|ppp)\d*$');

  /// Whether a VPN may be behind [error]: Librus did not answer, or turned
  /// the request away. A wrong password or a missing account it is not.
  static bool mayCause(AppError error) => switch (error.errorCode) {
    LibrusErrorCode.networkTimeout ||
    LibrusErrorCode.networkUnavailable ||
    LibrusErrorCode.networkOther ||
    LibrusErrorCode.networkUnknown ||
    LibrusErrorCode.serverReply ||
    LibrusErrorCode.captchaRequired ||
    LibrusErrorCode.sessionRenewFailed ||
    LibrusErrorCode.loginFailed ||
    LibrusErrorCode.portalRejected ||
    LibrusErrorCode.apiRejected => true,
    _ => false,
  };
}
