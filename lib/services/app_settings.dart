import 'package:shared_preferences/shared_preferences.dart';

class AppSettings {
  static const String _soundEnabledKey = 'sound_enabled';
  static const String _vibrationEnabledKey = 'vibration_enabled';
  
  static bool _soundEnabled = true;
  static bool _vibrationEnabled = true;
  
  static bool get soundEnabled => _soundEnabled;
  static bool get vibrationEnabled => _vibrationEnabled;
  
  static Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _soundEnabled = prefs.getBool(_soundEnabledKey) ?? true;
    _vibrationEnabled = prefs.getBool(_vibrationEnabledKey) ?? true;
    print('🔧 설정 로드: 사운드=$_soundEnabled, 진동=$_vibrationEnabled');
  }
  
  static Future<void> setSoundEnabled(bool enabled) async {
    _soundEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_soundEnabledKey, enabled);
    print('🔊 사운드 설정: $enabled');
  }
  
  static Future<void> setVibrationEnabled(bool enabled) async {
    _vibrationEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_vibrationEnabledKey, enabled);
    print('📳 진동 설정: $enabled');
  }
} 