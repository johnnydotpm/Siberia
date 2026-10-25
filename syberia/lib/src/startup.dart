import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app.dart';
import 'data/app_repository.dart';
import 'domain/models.dart';
import 'l10n/app_localizations.dart';
import 'state/app_controller.dart';
import 'ui/brand_logo.dart';

/// Draws the first Flutter frame before account restoration and network I/O.
/// Startup finishes as soon as initialization does; the animation adds no
/// delay. On a first launch the setup carries the animation on from where it
/// got to and plays it to the whole logo.
class StartupApp extends StatefulWidget {
  const StartupApp({
    required this.initialize,
    required this.preferences,
    super.key,
  });
  final Future<AppController> Function() initialize;
  final AppRepository preferences;

  @override
  State<StartupApp> createState() => _StartupAppState();
}

class _StartupAppState extends State<StartupApp> {
  AppController? _controller;
  AppColorMode _colorMode = AppColorMode.system;
  Locale? _locale;
  bool _failed = false;
  int _attempt = 0;

  /// How long the animation has been running.
  final _logoTime = BrandLogoTime();

  @override
  void initState() {
    super.initState();
    unawaited(_loadPreferences());
    unawaited(_start());
  }

  Future<void> _loadPreferences() async {
    try {
      final mode = await widget.preferences.loadColorMode();
      final language = await widget.preferences.loadLocale();
      if (!mounted) return;
      setState(() {
        _colorMode = mode;
        _locale = language == null ? null : Locale(language);
      });
    } on Object {
      // Follow the phone's appearance if preferences are unavailable.
    }
  }

  Future<void> _start() async {
    setState(() {
      _failed = false;
      _attempt++;
    });
    try {
      final controller = await widget.initialize();
      if (!mounted) {
        controller.dispose();
        return;
      }
      if (!controller.onboardingDone && !controller.isDemo) {
        controller.playIntro(from: _logoTime.elapsed);
      }
      setState(() => _controller = controller);
    } on Object {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller != null) return SyberiaApp(controller: controller);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SiberiaGB',
      locale: _locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      themeMode: switch (_colorMode) {
        AppColorMode.system => ThemeMode.system,
        AppColorMode.light => ThemeMode.light,
        AppColorMode.dark || AppColorMode.amoled => ThemeMode.dark,
      },
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF176B8F)),
        scaffoldBackgroundColor: startupBackground(Brightness.light),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF176B8F),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: startupBackground(
          Brightness.dark,
          amoled: _colorMode == AppColorMode.amoled,
        ),
      ),
      home: Builder(
        builder: (context) => AnnotatedRegion<SystemUiOverlayStyle>(
          value: Theme.of(context).brightness == Brightness.dark
              ? SystemUiOverlayStyle.light
              : SystemUiOverlayStyle.dark,
          child: Scaffold(
            body: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Semantics(
                        liveRegion: true,
                        label: context.tr(
                          _failed ? 'startupFailed' : 'startingApp',
                        ),
                        child: AnimatedBrandLogo(
                          key: ValueKey('startup-logo-$_attempt'),
                          time: _logoTime,
                        ),
                      ),
                      if (_failed) ...[
                        const SizedBox(height: 24),
                        Text(
                          context.tr('startupFailed'),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: _start,
                          icon: const Icon(Icons.refresh_rounded),
                          label: Text(context.tr('startupRetry')),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
