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

  test('counts take the form their number needs', () {
    String forms(String language, String key) => [
      for (final count in [1, 2, 5, 12, 22, 25, 101, 111])
        AppLocalizations(Locale(language)).plural(count, key),
    ].join(', ');
    expect(
      forms('pl', 'grades'),
      '1 ocena, 2 oceny, 5 ocen, 12 ocen, 22 oceny, 25 ocen, 101 ocen, 111 ocen',
    );
    expect(
      forms('ru', 'grades'),
      '1 оценка, 2 оценки, 5 оценок, 12 оценок, 22 оценки, 25 оценок, '
      '101 оценка, 111 оценок',
    );
    expect(
      forms('uk', 'profiles'),
      '1 профіль, 2 профілі, 5 профілів, 12 профілів, 22 профілі, '
      '25 профілів, 101 профіль, 111 профілів',
    );
    expect(
      forms('en', 'newEntries'),
      '1 new item, 2 new items, 5 new items, 12 new items, 22 new items, '
      '25 new items, 101 new items, 111 new items',
    );
  });

  test('a long Polish text never ends a line on a one-letter word', () {
    const keep = '\u00A0';
    final polish = AppLocalizations(const Locale('pl'));
    // Long: each "w", "z" and "i" holds on to the word after it.
    final long = polish.text('logoutConfirm');
    expect(long, contains('z${keep}telefonu'));
    expect(RegExp(r'(^|\s)[aiouwzAIOUWZ] ').hasMatch(long), isFalse);
    // Short texts stay as they are, as do other languages.
    expect(polish.text('messagesThisWeek'), 'W tym tygodniu');
    expect(
      AppLocalizations(const Locale('en')).text('togetherSettingsNote'),
      isNot(contains(keep)),
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
