import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syberia/src/domain/librus_error.dart';
import 'package:syberia/src/l10n/app_localizations.dart';

void main() {
  test('German and Ukrainian are supported in the app', () {
    expect(AppLocalizations.supportedLocales, contains(const Locale('de')));
    expect(AppLocalizations.supportedLocales, contains(const Locale('uk')));
    expect(
      AppLocalizations(const Locale('de')).text('login'),
      'Anmelden und synchronisieren',
    );
    expect(
      AppLocalizations(const Locale('uk')).text('notifications'),
      'Сповіщення',
    );
  });

  test('every locale defines the same translation keys', () {
    final expected = AppLocalizations.keysFor('pl');
    expect(expected, isNotEmpty);
    for (final locale in AppLocalizations.supportedLocales) {
      expect(
        AppLocalizations.keysFor(locale.languageCode),
        expected,
        reason: 'locale ${locale.languageCode} drifted from pl',
      );
    }
  });

  test('every Librus error code resolves to a translation', () {
    for (final code in LibrusErrorCode.values) {
      final key = errorMessageKeys[code];
      expect(key, isNotNull, reason: '$code has no translation key');
      for (final locale in AppLocalizations.supportedLocales) {
        // `text` returns the key itself when a translation is missing.
        expect(
          AppLocalizations(locale).text(key!),
          isNot(key),
          reason: '$code is untranslated in ${locale.languageCode}',
        );
      }
    }
  });

  test('errors carrying a detail keep the placeholder in every locale', () {
    const keysWithDetail = [
      'portalRejected',
      'apiRejected',
      'messageNotSent',
      'networkOther',
      'serverReply',
    ];
    for (final key in keysWithDetail) {
      for (final locale in AppLocalizations.supportedLocales) {
        expect(
          AppLocalizations(locale).text(key),
          contains('{detail}'),
          reason: '$key lost {detail} in ${locale.languageCode}',
        );
      }
    }
  });
}
