import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeManager {
  static final ValueNotifier<ThemeMode> themeModeNotifier = ValueNotifier(ThemeMode.light);
  // Thêm quản lý cỡ chữ ('Small', 'Medium', 'Large')
  static final ValueNotifier<String> fontSizeNotifier = ValueNotifier('Medium');
  static Future<void> loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool('is_dark_mode') ?? false;
    themeModeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;
  }

  static Future<void> toggleTheme(bool isDark) async {
    themeModeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_dark_mode', isDark);
  }
  // Hàm thay đổi và lưu cỡ chữ
  static Future<void> changeFontSize(String size) async {
    fontSizeNotifier.value = size;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('font_size', size);
  }
}