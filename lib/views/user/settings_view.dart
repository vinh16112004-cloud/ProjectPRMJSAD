
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme_manager.dart';

class SettingsView extends StatefulWidget {
const SettingsView({super.key});

@override
State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
String _fontSize = 'Medium';
bool _isDarkMode = false;

@override
void initState() {
super.initState();
_loadSettings();
}

Future<void> _loadSettings() async {
final prefs = await SharedPreferences.getInstance();

if (!mounted) return;

setState(() {
_fontSize = prefs.getString('font_size') ?? 'Medium';
_isDarkMode = prefs.getBool('is_dark_mode') ?? false;
});
}

Future<void> _saveSetting(String key, dynamic value) async {
final prefs = await SharedPreferences.getInstance();

if (value is bool) {
await prefs.setBool(key, value);
}

if (value is String) {
await prefs.setString(key, value);
}
}

@override
Widget build(BuildContext context) {
return Scaffold(
appBar: AppBar(
title: const Text('Cài đặt ứng dụng'),
),
body: ListView(
children: [
ListTile(
leading: const Icon(Icons.text_fields),
title: const Text('Cỡ chữ đọc báo'),
subtitle: Text('Hiện tại: $_fontSize'),
trailing: DropdownButton<String>(
value: _fontSize,
items: ['Small', 'Medium', 'Large'].map((level) {
return DropdownMenuItem(
value: level,
child: Text(level),
);
}).toList(),
onChanged: (val) {
if (val != null) {
setState(() => _fontSize = val);
_saveSetting('font_size', val);
ThemeManager.changeFontSize(val);
}
},
),
),

const Divider(),

SwitchListTile(
secondary: const Icon(Icons.dark_mode),
title: const Text('Giao diện tối (Dark Mode)'),
value: _isDarkMode,
onChanged: (val) {
setState(() => _isDarkMode = val);
_saveSetting('is_dark_mode', val);
ThemeManager.toggleTheme(val);
},
),
],
),
);
}
}
