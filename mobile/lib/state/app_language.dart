/// Languages selectable in the app shell. Full advisory-text localization
/// (the actual treatment instructions) lands in Week 5's AdvisoryMapper —
/// this just drives UI chrome strings and records the farmer's preference
/// for later weeks to use.
enum AppLanguage {
  english(code: 'en', displayName: 'English'),
  hindi(code: 'hi', displayName: 'हिन्दी'),
  gujarati(code: 'gu', displayName: 'ગુજરાતી');

  const AppLanguage({required this.code, required this.displayName});

  final String code;
  final String displayName;
}

/// UI chrome strings, keyed by [AppLanguage]. Deliberately small and
/// hand-written rather than a full ARB/intl pipeline — Week 4 only needs a
/// working language *selector*, not a translation pipeline; Week 11
/// ("Regional Language Expansion") is where this scales up properly.
class AppStrings {
  const AppStrings._(this._values);

  final Map<String, String> _values;

  static const _en = {
    'appTitle': 'AgriSense AI',
    'homeTab': 'Home',
    'weatherTab': 'Weather',
    'pricesTab': 'Prices',
    'communityTab': 'Community',
    'tapToScan': 'Tap to scan crop leaf',
    'capturePhoto': 'Capture Photo',
    'recentScans': 'Recent Scans',
    'noScansYet': 'No scans yet — capture your first crop photo above.',
    'diagnosisResult': 'Diagnosis Result',
    'confidence': 'Confidence',
    'crop': 'Crop',
    'healthy': 'Healthy',
    'diseaseDetected': 'Detected',
    'advisoryComingSoon': 'Treatment advisory — coming in Week 5.',
    'selectLanguage': 'Select language',
  };

  static const _hi = {
    'appTitle': 'AgriSense AI',
    'homeTab': 'होम',
    'weatherTab': 'मौसम',
    'pricesTab': 'भाव',
    'communityTab': 'समुदाय',
    'tapToScan': 'फसल की पत्ती स्कैन करने के लिए टैप करें',
    'capturePhoto': 'फोटो लें',
    'recentScans': 'हाल की स्कैन',
    'noScansYet': 'अभी तक कोई स्कैन नहीं — ऊपर अपनी पहली फसल फोटो लें।',
    'diagnosisResult': 'निदान परिणाम',
    'confidence': 'विश्वास',
    'crop': 'फसल',
    'healthy': 'स्वस्थ',
    'diseaseDetected': 'पहचान हुई',
    'advisoryComingSoon': 'उपचार सलाह — सप्ताह 5 में आ रही है।',
    'selectLanguage': 'भाषा चुनें',
  };

  static const _gu = {
    'appTitle': 'AgriSense AI',
    'homeTab': 'હોમ',
    'weatherTab': 'હવામાન',
    'pricesTab': 'ભાવ',
    'communityTab': 'સમુદાય',
    'tapToScan': 'પાકનું પાન સ્કેન કરવા ટેપ કરો',
    'capturePhoto': 'ફોટો લો',
    'recentScans': 'તાજેતરના સ્કેન',
    'noScansYet': 'હજુ કોઈ સ્કેન નથી — ઉપર તમારો પહેલો પાક ફોટો લો.',
    'diagnosisResult': 'નિદાન પરિણામ',
    'confidence': 'વિશ્વાસ',
    'crop': 'પાક',
    'healthy': 'સ્વસ્થ',
    'diseaseDetected': 'મળી આવ્યું',
    'advisoryComingSoon': 'સારવાર સલાહ — અઠવાડિયું 5 માં આવે છે.',
    'selectLanguage': 'ભાષા પસંદ કરો',
  };

  static const Map<AppLanguage, AppStrings> _byLanguage = {
    AppLanguage.english: AppStrings._(_en),
    AppLanguage.hindi: AppStrings._(_hi),
    AppLanguage.gujarati: AppStrings._(_gu),
  };

  factory AppStrings.of(AppLanguage language) => _byLanguage[language]!;

  String operator [](String key) => _values[key] ?? _en[key] ?? key;
}
