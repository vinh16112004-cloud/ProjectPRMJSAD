import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:untitled1/views/admin/article_management_view.dart';
import 'package:untitled1/views/admin/category_management_view.dart';
import 'package:untitled1/views/admin/user_management_view.dart';
import 'package:untitled1/views/user/profile_view.dart';
import 'package:untitled1/views/user/user_home_view.dart';

import '../viewmodels/auth_viewmodel.dart';

class AdminDashboardView extends ConsumerStatefulWidget {
  const AdminDashboardView({super.key});

  @override
  ConsumerState<AdminDashboardView> createState() => _AdminDashboardViewState();
}

class _AdminDashboardViewState extends ConsumerState<AdminDashboardView> {
  int _selectedIndex = 0;

  final List<Widget> _pages = const [
    UserManagementView(),
    CategoryManagementView(),
    ArticleManagementView(),
  ];

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateChangesProvider);
    final currentUser =
        authState.valueOrNull ?? FirebaseAuth.instance.currentUser;
    final displayName =
        currentUser?.displayName ??
        currentUser?.email?.split('@').first ??
        'admin';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin CMS Dashboard'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const UserHomeView()),
              );
            },
            icon: const Icon(Icons.newspaper_outlined),
            label: const Text('Trang đọc báo'),
          ),
          // Menu xổ xuống "Hi, admin" tại góc phải
          PopupMenuButton<String>(
            tooltip: 'Tài khoản',
            offset: const Offset(0, 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.blue.shade100,
                    child: Text(
                      displayName.substring(0, 1).toUpperCase(),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Hi, $displayName',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  const Icon(Icons.arrow_drop_down),
                ],
              ),
            ),
            onSelected: (value) async {
              if (value == 'profile') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfileView()),
                );
              } else if (value == 'logout') {
                _showLogoutConfirmationDialog(context, ref);
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                enabled: false,
                child: Text(
                  currentUser?.email ?? '',
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem<String>(
                value: 'profile',
                child: Row(
                  children: [
                    Icon(Icons.person_outline, size: 20),
                    SizedBox(width: 8),
                    Text('Hồ sơ cá nhân'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, color: Colors.red, size: 20),
                    SizedBox(width: 8),
                    Text('Đăng xuất', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Row(
        children: [
          // Thanh Navigation Sidebar bên trái
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (int index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            labelType: NavigationRailLabelType.all,
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.people_outline),
                selectedIcon: Icon(Icons.people),
                label: Text('Quản lý User'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.category_outlined),
                selectedIcon: Icon(Icons.category),
                label: Text('Chuyên mục'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.article_outlined),
                selectedIcon: Icon(Icons.article),
                label: Text('Quản lý bài báo'),
              ),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),

          // Nội dung hiển thị theo trang được chọn
          Expanded(child: _pages[_selectedIndex]),
        ],
      ),
    );
  }

  // Dialog xác nhận đăng xuất
  void _showLogoutConfirmationDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Xác nhận đăng xuất'),
          content: const Text(
            'Bạn có chắc chắn muốn đăng xuất khỏi hệ thống?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                Navigator.pop(context);
                await ref.read(authViewModelProvider).signOut();
              },
              child: const Text(
                'Đăng xuất',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }
}
