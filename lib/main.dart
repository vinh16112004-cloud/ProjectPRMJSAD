import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:untitled1/firebase_options.dart';
import 'package:untitled1/views/admin_dashboard_view.dart';

import 'viewmodels/auth_viewmodel.dart';
import 'views/login_view.dart';
// ... import các file khác của bạn

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform, // Giữ nguyên cấu hình Firebase của bạn
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
    return MaterialApp(
      title: 'Flutter Web Admin CMS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const AuthWrapper(), // Dùng AuthWrapper làm màn hình gốc
    );
  }
}

// Widget trung gian kiểm tra trạng thái đăng nhập khi load trang
class AuthWrapper extends ConsumerWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateChangesProvider);

    return authState.when(
      data: (user) {
        if (user != null) {
          // Đã đăng nhập -> Vào trang quản trị
          return const AdminDashboardView();
        } else {
          // Chưa đăng nhập -> Vào trang Login
          return const LoginView();
        }
      },
      // TRẠNG THÁI QUAN TRỌNG: Khi đang load phiên từ trình duyệt, hiện vòng xoay thay vì đá về Login
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