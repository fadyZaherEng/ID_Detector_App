import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class StorageService {
  //get it from this https://aistudio.google.com/api-keys?project=gen-lang-client-0389621963

  static   final String _apiKeyKey = dotenv.env['GEMINI_API_KEY']??'gemini_api_key';
  static const String _demoModeKey = 'demo_mode_enabled';

  static Future<String?> getApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_apiKeyKey) ?? 'gemini_api_key';
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
