import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart'; // <-- Thêm package này
import 'package:untitled1/firebase_options.dart';
import 'package:untitled1/theme_manager.dart';
import 'package:untitled1/views/admin_dashboard_view.dart';

import 'viewmodels/auth_viewmodel.dart';

import 'views/login_view.dart';
import 'views/user/user_home_view.dart'; // Import trang người dùng của bạn ở đây
import 'views/user/search_view.dart';
import 'views/user/settings_view.dart';
import 'views/user/feedback_view.dart';
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ThemeManager.loadTheme();
  // Xóa dấu # trên URL của Flutter Web (biến /#/admin thành /admin)
  usePathUrlStrategy();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeManager.themeModeNotifier,
      builder: (context, currentThemeMode, child) {
        // Lắng nghe thêm cỡ chữ toàn cục
        return ValueListenableBuilder<String>(
          valueListenable: ThemeManager.fontSizeNotifier,
          builder: (context, currentFontSize, child) {

            // Quy đổi cỡ chữ ra hệ số tỉ lệ (TextScaleFactor)
            double textScale = 1.0;
            if (currentFontSize == 'Small') textScale = 0.85;
            if (currentFontSize == 'Large') textScale = 1.15;

            return MaterialApp(
              title: 'Báo Mới 24h',
              debugShowCheckedModeBanner: false,
              theme: ThemeData(brightness: Brightness.light, useMaterial3: true),
              darkTheme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
              themeMode: currentThemeMode,

              // Áp dụng tỉ lệ cỡ chữ cho toàn bộ ứng dụng
              builder: (context, widget) {
                return MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear(textScale),
                  ),
                  child: widget!,
                );
              },

              initialRoute: '/',
              routes: {
                '/': (context) => const AuthWrapper(),
                '/admin': (context) => const AdminDashboardView(),
                '/user': (context) => const UserHomeView(),
                '/user/search': (context) => SearchView(),
                '/user/settings': (context) => SettingsView(),
                '/user/feedback': (context) => FeedbackView(),
              },
            );
          },
        );
      },
    );
  }
}

// Widget mẫu cho trang người dùng (Bạn hãy thay thế bằng View thực tế của bạn)
class PlaceholderUserView extends StatelessWidget {
  const PlaceholderUserView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Trang Người Dùng')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Đây là giao diện dành cho người dùng!'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.pushReplacementNamed(context, '/admin'),
              child: const Text('Quay lại trang quản trị'),
            ),
          ],
        ),
      ),
    );
  }
}

// Widget AuthWrapper giữ nguyên như trước
class AuthWrapper extends ConsumerWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateChangesProvider);

    return authState.when(
      data: (user) {
        if (user != null) {
          return const AdminDashboardView();
        } else {
          return const LoginView();
        }
      },
      loading: () => const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      ),
      error: (error, stackTrace) => Scaffold(
        body: Center(
          child: Text('Lỗi xác thực: $error'),
        ),
      ),
    );
  }
}
