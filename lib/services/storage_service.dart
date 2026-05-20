import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  //get it from this https://aistudio.google.com/api-keys?project=gen-lang-client-0389621963
  static const String _apiKeyKey = 'gemini_api_key';//AIzaSyCdbecd3YypiLjsfhYezjKbiGf6SBjxRCU
  static const String _demoModeKey = 'demo_mode_enabled';

  static Future<String?> getApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_apiKeyKey) ?? 'AIzaSyCdbecd3YypiLjsfhYezjKbiGf6SBjxRCU';
  }

  static Future<bool> saveApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.setString(_apiKeyKey, key);
  }

  static Future<bool> deleteApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.remove(_apiKeyKey);
  }

  static Future<bool> isDemoModeEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_demoModeKey) ?? false; // Default to false so Gemini AI is active immediately
  }

  static Future<bool> setDemoModeEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.setBool(_demoModeKey, enabled);
  }
}
