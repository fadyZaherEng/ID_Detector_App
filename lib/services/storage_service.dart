import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static const String _apiKeyKey = 'gemini_api_key';
  static const String _demoModeKey = 'demo_mode_enabled';

  static Future<String?> getApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_apiKeyKey);
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
    return prefs.getBool(_demoModeKey) ?? true; // Default to true so users can test immediately
  }

  static Future<bool> setDemoModeEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.setBool(_demoModeKey, enabled);
  }
}
