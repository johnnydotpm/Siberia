import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'domain/models.dart';
import 'l10n/app_localizations.dart';
import 'state/app_controller.dart';
import 'theme/app_theme.dart';
import 'ui/app_shell.dart';
import 'ui/brand/brand_events.dart';
import 'ui/glass/glass_platform.dart';
import 'ui/screen_transitions.dart';

class SyberiaApp extends StatefulWidget {
  const SyberiaApp({required this.controller, super.key});

  final AppController controller;

  @override
  State<SyberiaApp> createState() => _SyberiaAppState();
}

class _SyberiaAppState extends State<SyberiaApp> with WidgetsBindingObserver {
  bool _wasBackgrounded = false;

  /// True while a new theme spreads in a circle: the theme then changes at
  /// once beneath it rather than fading on its own.
  final _revealing = ValueNotifier(false);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _revealing.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _wasBackgrounded = true;
    } else if (state == AppLifecycleState.resumed && _wasBackgrounded) {
      _wasBackgrounded = false;
      // The background check may have found news for another profile.
      unawaited(widget.controller.refreshProfiles());
      if (widget.controller.autoSyncOnOpen) unawaited(widget.controller.sync());
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final glass =
          GlassPlatform.supported &&
          widget.controller.design == AppDesign.glass;
      // Where Flutter draws the glass, the design is a copy of the iPhone's
      // and brings the iPhone's look and manners with it.
      final likeIos = glass && GlassPlatform.backend == GlassBackend.rendered;
      return ValueListenableBuilder(
        valueListenable: _revealing,
        builder: (context, revealing, _) => BrandEventScope(
          // The day's logo: on a holiday, or on 1 September, its own.
          event: BrandEvents.today(),
          child: MaterialApp(
            title: 'SiberiaGB',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(likeIos: likeIos),
            darkTheme: widget.controller.colorMode == AppColorMode.amoled
                ? AppTheme.amoled(likeIos: likeIos)
                : AppTheme.dark(likeIos: likeIos),
            themeAnimationDuration: revealing
                ? Duration.zero
                : kThemeAnimationDuration,
            themeMode: switch (widget.controller.colorMode) {
              AppColorMode.system => ThemeMode.system,
              AppColorMode.light => ThemeMode.light,
              AppColorMode.dark || AppColorMode.amoled => ThemeMode.dark,
            },
            locale: widget.controller.locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
            ],
            // Above the navigator, so sheets and dialogs follow the design too,
            // and a change of the whole screen covers them as well. UIKit's own
            // glass views would be missing from a picture of the screen.
            builder: (context, child) => ScreenTransitions(
              enabled: !(glass && GlassPlatform.backend == GlassBackend.uikit),
              revealing: _revealing,
              child: GlassStyle(enabled: glass, child: child!),
            ),
            home: _SystemNavigationStyle(
              child: AppShell(controller: widget.controller),
            ),
          ),
        ),
      );
    },
  );
}

class _SystemNavigationStyle extends StatelessWidget {
  const _SystemNavigationStyle({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle(
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarContrastEnforced: false,
      systemNavigationBarIconBrightness:
          Theme.of(context).brightness == Brightness.dark
          ? Brightness.light
          : Brightness.dark,
    ),
    child: child,
  );
}
