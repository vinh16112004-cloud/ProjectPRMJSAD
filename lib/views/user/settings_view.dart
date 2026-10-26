import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme_manager.dart'; // Hoặc đường dẫn tương ứng tới theme_manager.dart
class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  bool _isNotificationEnabled = true;
  String _fontSize = 'Medium';
  bool _isDarkMode = false;
  double _cacheSizeMB = 12.5;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isNotificationEnabled = prefs.getBool('is_notification_enabled') ?? true;
      _fontSize = prefs.getString('font_size') ?? 'Medium';
      _isDarkMode = prefs.getBool('is_dark_mode') ?? false;
    });
  }

  Future<void> _saveSetting(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is bool) await prefs.setBool(key, value);
    if (value is String) await prefs.setString(key, value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cài đặt ứng dụng')),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('Thông báo tin tức'),
            value: _isNotificationEnabled,
            onChanged: (val) {
              setState(() => _isNotificationEnabled = val);
              _saveSetting('is_notification_enabled', val);
            },
          ),
          const Divider(),
          ListTile(
            title: const Text('Cỡ chữ đọc báo'),
            subtitle: Text('Hiện tại: $_fontSize'),
            trailing: DropdownButton<String>(
              value: _fontSize,
              items: ['Small', 'Medium', 'Large'].map((level) {
                return DropdownMenuItem(value: level, child: Text(level));
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() => _fontSize = val);
                  _saveSetting('font_size', val);
                  // Kích hoạt đổi cỡ chữ toàn ứng dụng lập tức
                  ThemeManager.changeFontSize(val);
                }
              },
            ),
          ),
          const Divider(),
          SwitchListTile(
            title: const Text('Giao diện tối (Dark Mode)'),
            value: _isDarkMode,
            onChanged: (val) {
              setState(() => _isDarkMode = val);
              _saveSetting('is_dark_mode', val);
              // === THÊM DÒNG NÀY ĐỂ KÍCH HOẠT ĐỔI MÀU TOÀN APP ===
              ThemeManager.toggleTheme(val);
            },
          ),
          const Divider(),
          ListTile(
            title: const Text('Bộ nhớ đệm (Cache)'),
            subtitle: Text('${_cacheSizeMB.toStringAsFixed(1)} MB'),
            trailing: TextButton(
              onPressed: () {
                setState(() => _cacheSizeMB = 0.0);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Đã xóa cache thành công!')),
                );
              },
              child: const Text('Xóa Cache', style: TextStyle(color: Colors.red)),
            ),
          ),
        ],
      ),
    );
  }
}