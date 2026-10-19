import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prj_asm/viewmodels/user_management_viewmodel.dart';


class UserManagementView extends ConsumerWidget {
  const UserManagementView({Key? key}) : super(key: key);

  // Hàm hiển thị Dialog tạo người dùng mới
  void _showAddUserDialog(BuildContext context, WidgetRef ref) {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    String selectedRole = 'Reader';
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Thêm người dùng mới'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: emailController,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Mật khẩu',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedRole,
                      decoration: const InputDecoration(
                        labelText: 'Vai trò (Role)',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Admin', child: Text('Admin')),
                        DropdownMenuItem(value: 'Editor', child: Text('Editor')),
                        DropdownMenuItem(value: 'Reader', child: Text('Reader')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => selectedRole = val);
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Hủy'),
                ),
                ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                    final email = emailController.text.trim();
                    final password = passwordController.text.trim();

                    if (email.isEmpty || password.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Vui lòng điền đầy đủ thông tin'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                      return;
                    }

                    setState(() => isLoading = true);

                    try {
                      await ref
                          .read(userManagementViewModelProvider)
                          .createUser(
                        email: email,
                        password: password,
                        role: selectedRole,
                      );

                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Đã thêm người dùng $email thành công!'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Lỗi: ${e.toString().replaceAll("Exception: ", "")}'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    } finally {
                      if (context.mounted) {
                        setState(() => isLoading = false);
                      }
                    }
                  },
                  child: isLoading
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : const Text('Tạo mới'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userListAsync = ref.watch(userListProvider);
    final userVm = ref.read(userManagementViewModelProvider);

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            // Thanh Tiêu đề + Nút Thêm người dùng
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Quản lý Người dùng',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _showAddUserDialog(context, ref),
                  icon: const Icon(Icons.add),
                  label: const Text('Thêm người dùng'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Danh sách người dùng
            Expanded(
              child: userListAsync.when(
                data: (users) {
                  if (users.isEmpty) {
                    return const Center(child: Text('Chưa có người dùng nào.'));
                  }
                  return Card(
                    elevation: 2,
                    child: ListView.separated(
                      itemCount: users.length,
                      separatorBuilder: (context, index) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final user = users[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: user.isLocked ? Colors.red : Colors.blue,
                            child: Icon(
                              user.isLocked ? Icons.lock : Icons.person,
                              color: Colors.white,
                            ),
                          ),
                          title: Text(
                            user.email,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              decoration: user.isLocked ? TextDecoration.lineThrough : null,
                            ),
                          ),
                          subtitle: Text('ID: ${user.uid}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              DropdownButton<String>(
                                value: user.role,
                                items: const [
                                  DropdownMenuItem(value: 'Admin', child: Text('Admin')),
                                  DropdownMenuItem(value: 'Editor', child: Text('Editor')),
                                  DropdownMenuItem(value: 'Reader', child: Text('Reader')),
                                ],
                                onChanged: (newRole) {
                                  if (newRole != null) {
                                    userVm.updateUserRole(user.uid, newRole);
                                  }
                                },
                              ),
                              const SizedBox(width: 16),
                              IconButton(
                                icon: Icon(
                                  user.isLocked ? Icons.lock_open : Icons.lock_outline,
                                  color: user.isLocked ? Colors.green : Colors.red,
                                ),
                                tooltip: user.isLocked ? 'Mở khóa' : 'Khóa',
                                onPressed: () {
                                  userVm.toggleUserLockStatus(user.uid, user.isLocked);
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Center(child: Text('Lỗi: $err')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}