/// Languages selectable in the app shell. UI chrome strings live here;
/// treatment-advisory text itself comes from AdvisoryService (Week 5),
/// which reads the same content/treatment_recommendations.json the backend
/// seeds TreatmentRecommendation from.
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
    'selectLanguage': 'Select language',
    'urgency': 'Urgency',
    'urgencyLow': 'Low',
    'urgencyMedium': 'Medium',
    'urgencyHigh': 'High',
    'recommendedTreatment': 'Recommended Treatment',
    'priceComparison': 'Price Comparison',
    'selectCrop': 'Crop',
    'state': 'State',
    'district': 'District (optional)',
    'comparePrices': 'Compare Prices',
    'sampleDataWarning': 'Sample data — live market feed not yet connected.',
    'noPricesFound': 'No prices found for this crop/location.',
    'perQuintal': '/quintal',
    'bestPrice': 'Best price',
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
    'selectLanguage': 'भाषा चुनें',
    'urgency': 'गंभीरता',
    'urgencyLow': 'कम',
    'urgencyMedium': 'मध्यम',
    'urgencyHigh': 'अधिक',
    'recommendedTreatment': 'अनुशंसित उपचार',
    'priceComparison': 'भाव तुलना',
    'selectCrop': 'फसल',
    'state': 'राज्य',
    'district': 'ज़िला (वैकल्पिक)',
    'comparePrices': 'भाव तुलना करें',
    'sampleDataWarning': 'नमूना डेटा — लाइव बाज़ार फ़ीड अभी जुड़ा नहीं है।',
    'noPricesFound': 'इस फसल/स्थान के लिए कोई भाव नहीं मिला।',
    'perQuintal': '/क्विंटल',
    'bestPrice': 'सबसे अच्छा भाव',
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
    'selectLanguage': 'ભાષા પસંદ કરો',
    'urgency': 'ગંભીરતા',
    'urgencyLow': 'ઓછી',
    'urgencyMedium': 'મધ્યમ',
    'urgencyHigh': 'વધુ',
    'recommendedTreatment': 'ભલામણ કરેલ સારવાર',
    'priceComparison': 'ભાવ સરખામણી',
    'selectCrop': 'પાક',
    'state': 'રાજ્ય',
    'district': 'જિલ્લો (વૈકલ્પિક)',
    'comparePrices': 'ભાવ સરખાવો',
    'sampleDataWarning': 'નમૂના ડેટા — લાઇવ બજાર ફીડ હજુ જોડાયેલ નથી.',
    'noPricesFound': 'આ પાક/સ્થાન માટે કોઈ ભાવ મળ્યો નથી.',
    'perQuintal': '/ક્વિન્ટલ',
    'bestPrice': 'શ્રેષ્ઠ ભાવ',
  };

  static const Map<AppLanguage, AppStrings> _byLanguage = {
    AppLanguage.english: AppStrings._(_en),
    AppLanguage.hindi: AppStrings._(_hi),
    AppLanguage.gujarati: AppStrings._(_gu),
  };

  factory AppStrings.of(AppLanguage language) => _byLanguage[language]!;

  String operator [](String key) => _values[key] ?? _en[key] ?? key;
}
