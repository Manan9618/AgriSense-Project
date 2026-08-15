/// Languages selectable in the app shell. UI chrome strings live here;
/// treatment-advisory text itself comes from AdvisoryService (Week 5),
/// which reads the same content/treatment_recommendations.json the backend
/// seeds TreatmentRecommendation from.
enum AppLanguage {
  english(
    code: 'en',
    displayName: 'English',
    ttsLocale: 'en-IN',
    sttLocale: 'en_IN',
  ),
  hindi(
    code: 'hi',
    displayName: 'हिन्दी',
    ttsLocale: 'hi-IN',
    sttLocale: 'hi_IN',
  ),
  gujarati(
    code: 'gu',
    displayName: 'ગુજરાતી',
    ttsLocale: 'gu-IN',
    sttLocale: 'gu_IN',
  );

  const AppLanguage({
    required this.code,
    required this.displayName,
    required this.ttsLocale,
    required this.sttLocale,
  });

  final String code;
  final String displayName;

  /// Locale flutter_tts expects (Week 8) — a full BCP-47-ish tag, not just
  /// [code], since TTS engines need it to pick the right voice.
  final String ttsLocale;

  /// Locale speech_to_text expects (Week 8) — underscore-separated, per
  /// Android's Locale convention.
  final String sttLocale;
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
    'hearAdviceIn': 'Hear Advice in {lang}',
    'listening': 'Listening…',
    'voiceCommandHint': 'Tap the mic and say "scan", "prices", or "weather"',
    'voiceCommandNotRecognized':
        'Didn\'t catch a command — try "scan" or "prices".',
    'pendingSync': '{count} scan(s) waiting to sync',
    'syncNow': 'Sync Now',
    'syncing': 'Syncing…',
    'syncSuccess': 'Synced {count} scan(s)',
    'syncPartialFailure': '{synced} synced, {failed} will retry later',
    'allSynced': 'All scans synced',
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
    'hearAdviceIn': '{lang} में सलाह सुनें',
    'listening': 'सुन रहा है…',
    'voiceCommandHint': 'माइक दबाएं और "स्कैन" या "भाव" बोलें',
    'voiceCommandNotRecognized': 'कमांड समझ नहीं आया — "स्कैन" या "भाव" कहें।',
    'pendingSync': '{count} स्कैन सिंक होना बाकी है',
    'syncNow': 'अभी सिंक करें',
    'syncing': 'सिंक हो रहा है…',
    'syncSuccess': '{count} स्कैन सिंक हो गए',
    'syncPartialFailure': '{synced} सिंक हुए, {failed} बाद में फिर कोशिश होगी',
    'allSynced': 'सभी स्कैन सिंक हो चुके हैं',
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
    'hearAdviceIn': '{lang} માં સલાહ સાંભળો',
    'listening': 'સાંભળી રહ્યું છે…',
    'voiceCommandHint': 'માઇક દબાવો અને "સ્કેન" અથવા "ભાવ" બોલો',
    'voiceCommandNotRecognized': 'આદેશ સમજાયો નહીં — "સ્કેન" અથવા "ભાવ" કહો.',
    'pendingSync': '{count} સ્કેન સિંક બાકી છે',
    'syncNow': 'હમણાં સિંક કરો',
    'syncing': 'સિંક થઈ રહ્યું છે…',
    'syncSuccess': '{count} સ્કેન સિંક થયા',
    'syncPartialFailure': '{synced} સિંક થયા, {failed} પછી ફરી પ્રયાસ થશે',
    'allSynced': 'બધા સ્કેન સિંક થઈ ગયા',
  };

  static const Map<AppLanguage, AppStrings> _byLanguage = {
    AppLanguage.english: AppStrings._(_en),
    AppLanguage.hindi: AppStrings._(_hi),
    AppLanguage.gujarati: AppStrings._(_gu),
  };

  factory AppStrings.of(AppLanguage language) => _byLanguage[language]!;

  String operator [](String key) => _values[key] ?? _en[key] ?? key;
}
