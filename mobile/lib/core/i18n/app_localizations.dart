import 'package:flutter/widgets.dart';

import 'strings_en.dart';
import 'strings_mr.dart';

/// Minimal key-based localization lookup. Backed by plain Dart maps so the
/// skeleton has no codegen / .arb tooling dependency yet — swap for
/// `flutter_localizations` + .arb files when content grows.
class AppLocalizations {
  AppLocalizations(this.locale);

  final Locale locale;

  static const supportedLocales = [Locale('en'), Locale('mr')];

  static const Map<String, Map<String, String>> _tables = {
    'en': stringsEn,
    'mr': stringsMr,
  };

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        AppLocalizations(const Locale('en'));
  }

  /// Translate a key. Falls back to English, then to the raw key.
  String t(String key) {
    final table = _tables[locale.languageCode] ?? stringsEn;
    return table[key] ?? stringsEn[key] ?? key;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      AppLocalizations._tables.containsKey(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      AppLocalizations(locale);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
