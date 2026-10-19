import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prj_asm/views/admin/category_management_view.dart';
import 'package:prj_asm/views/admin/user_management_view.dart';

// Provider theo dõi Tab hiện tại
final selectedTabProvider = StateProvider<int>((ref) => 0);

class AdminDashboardView extends ConsumerWidget {
  const AdminDashboardView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = ref.watch(selectedTabProvider);

    // Danh sách 2 màn hình quản lý
    final List<Widget> pages = [
      const CategoryManagementView(), // Tab 0: Quản lý chuyên mục
      const UserManagementView(),     // Tab 1: Quản lý người dùng
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('HỆ THỐNG QUẢN TRỊ CMS'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Đăng xuất',
            onPressed: () {
              // Điều hướng quay lại trang đăng nhập
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
          ),
        ],
      ),
      body: Row(
        children: [
          // NavigationRail cho giao diện Web Admin
          NavigationRail(
            selectedIndex: selectedIndex,
            onDestinationSelected: (int index) {
              ref.read(selectedTabProvider.notifier).state = index;
            },
            labelType: NavigationRailLabelType.all,
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.category_outlined),
                selectedIcon: Icon(Icons.category),
                label: Text('Chuyên mục'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.people_outline),
                selectedIcon: Icon(Icons.people),
                label: Text('Người dùng'),
              ),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),
          // Màn hình nội dung theo Tab được chọn
          Expanded(
            child: pages[selectedIndex],
          ),
        ],
      ),
    );
  }
}