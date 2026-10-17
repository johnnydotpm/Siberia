import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Asks Android for the screen's top refresh rate while the app moves, and
/// gives the rate back to the system as soon as it is still.
///
/// Frames that come in quick succession (scrolling, page transitions,
/// animations) start a boost; a moment without frames ends it. A lone
/// frame, such as the Today clock ticking, never boosts. Released, the app
/// states no preference, so an LTPO screen can drop as low as it goes.
class FrameRateBooster with WidgetsBindingObserver {
  FrameRateBooster({
    this._channel = const MethodChannel('app.syberia.client/frame_rate'),
    this.burstGap = const Duration(milliseconds: 50),
    this.idleDelay = const Duration(milliseconds: 700),
  });

  final MethodChannel _channel;

  /// Two frames closer together than this mean the app is moving.
  final Duration burstGap;

  /// How long without a frame before the rate is handed back.
  final Duration idleDelay;

  final Stopwatch _sinceFrame = Stopwatch();
  Duration? _lastFrame;
  Timer? _idle;
  bool _boosted = false;
  bool _started = false;

  bool get boosted => _boosted;

  void start() {
    if (_started) return;
    _started = true;
    SchedulerBinding.instance.addPersistentFrameCallback(onFrame);
    WidgetsBinding.instance.addObserver(this);
  }

  @visibleForTesting
  void onFrame(Duration timeStamp) {
    final previous = _lastFrame;
    _lastFrame = timeStamp;
    _sinceFrame
      ..reset()
      ..start();
    if (_boosted || previous == null) return;
    final gap = timeStamp - previous;
    if (gap >= Duration.zero && gap < burstGap) {
      _boosted = true;
      _send('boost');
      _idle = Timer(idleDelay, _checkIdle);
    }
  }

  void _checkIdle() {
    final quiet = _sinceFrame.elapsed;
    if (quiet < idleDelay) {
      _idle = Timer(idleDelay - quiet, _checkIdle);
      return;
    }
    _release();
  }

  void _release() {
    _idle?.cancel();
    _idle = null;
    _lastFrame = null;
    if (!_boosted) return;
    _boosted = false;
    _send('release');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Android releases the rate itself when the app leaves the screen.
    if (state != AppLifecycleState.resumed) _release();
  }

  void _send(String method) {
    unawaited(
      _channel.invokeMethod<void>(method).catchError((Object _) {
        // Without the channel the system keeps choosing the rate.
      }),
    );
  }
}
