import 'package:flutter/foundation.dart';

import 'app_language.dart';

class LanguageProvider extends ChangeNotifier {
  LanguageProvider({AppLanguage initial = AppLanguage.english})
    : _language = initial;

  AppLanguage _language;
  AppLanguage get language => _language;
  AppStrings get strings => AppStrings.of(_language);

  void setLanguage(AppLanguage language) {
    if (language == _language) return;
    _language = language;
    notifyListeners();
  }
}
