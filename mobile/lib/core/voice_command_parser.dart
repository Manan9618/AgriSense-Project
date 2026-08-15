import '../state/app_language.dart';

/// A recognized voice command's target action. Matches the bottom nav's
/// four tabs (VoiceNavigator component spec, docs/classes.md: "Voice
/// command -> App navigation action").
enum VoiceIntent { scan, prices, weather, community }

const Map<AppLanguage, Map<VoiceIntent, List<String>>> _keywords = {
  AppLanguage.english: {
    VoiceIntent.scan: ['scan', 'photo', 'capture', 'diagnose'],
    VoiceIntent.prices: ['price', 'prices', 'market', 'mandi'],
    VoiceIntent.weather: ['weather', 'forecast', 'rain'],
    VoiceIntent.community: ['community', 'question', 'ask'],
  },
  AppLanguage.hindi: {
    VoiceIntent.scan: ['स्कैन', 'फोटो', 'तस्वीर'],
    VoiceIntent.prices: ['भाव', 'बाज़ार', 'बाजार', 'मंडी'],
    VoiceIntent.weather: ['मौसम', 'बारिश'],
    VoiceIntent.community: ['समुदाय', 'सवाल'],
  },
  AppLanguage.gujarati: {
    VoiceIntent.scan: ['સ્કેન', 'ફોટો', 'તસવીર'],
    VoiceIntent.prices: ['ભાવ', 'બજાર', 'મંડી'],
    VoiceIntent.weather: ['હવામાન', 'વરસાદ'],
    VoiceIntent.community: ['સમુદાય', 'પ્રશ્ન'],
  },
};

/// Parses recognized speech into a navigation intent by keyword matching —
/// simple on purpose. Farmers speaking short, direct commands ("scan",
/// "bhaav", "mausam") don't need NLU/intent-classification overhead; a
/// keyword match is transparent (a farmer can learn exactly which words
/// work) and needs no model or network call, keeping it offline-first like
/// the rest of the app. Returns null when nothing matches, rather than
/// guessing.
VoiceIntent? parseVoiceCommand(String recognizedText, AppLanguage language) {
  final normalized = recognizedText.trim().toLowerCase();
  if (normalized.isEmpty) return null;

  final keywords = _keywords[language] ?? _keywords[AppLanguage.english]!;
  for (final entry in keywords.entries) {
    for (final keyword in entry.value) {
      if (normalized.contains(keyword.toLowerCase())) return entry.key;
    }
  }
  return null;
}
