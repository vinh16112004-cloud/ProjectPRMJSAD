import 'package:shared_preferences/shared_preferences.dart';

class ConfigPreferences {
  static const String _keyNotifications = 'settings_notifications';
  static const String _keyDarkMode = 'settings_dark_mode';

  // Lưu trạng thái cấu hình thông báo
  static Future<void> setNotificationEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyNotifications, value);
  }

  // Đọc trạng thái cấu hình thông báo
  static Future<bool> getNotificationEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyNotifications) ?? true; // Mặc định là bật
  }
}