import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/user_model.dart';
import '../../viewmodels/user_management_viewmodel.dart';

class UserManagementView extends ConsumerWidget {
  const UserManagementView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(userListStreamProvider);
    final currentAdminUid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Danh sách tài khoản',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                ElevatedButton.icon(
                  onPressed: () => _showAddUserDialog(context, ref),
                  icon: const Icon(Icons.add),
                  label: const Text('Thêm người dùng'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: usersAsync.when(
                data: (users) {
                  if (users.isEmpty) {
                    return const Center(child: Text('Chưa có người dùng nào.'));
                  }

                  return LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.vertical,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(minWidth: constraints.maxWidth),
                            child: DataTable(
                              columnSpacing: 24,
                              columns: const [
                                DataColumn(label: Text('Họ và tên')),
                                DataColumn(label: Text('Email')),
                                DataColumn(label: Text('Số điện thoại')),
                                DataColumn(label: Text('Vai trò')),
                                DataColumn(label: Text('Trạng thái')),
                                DataColumn(label: Text('Thao tác')),
                              ],
                              rows: users.map((user) {
                                final isSelf = user.uid == currentAdminUid;

                                return DataRow(
                                  cells: [
                                    // 1. Cột Họ và tên (Tối đa 220px, quá dài hiện ...)
                                    DataCell(
                                      Container(
                                        constraints: const BoxConstraints(maxWidth: 220),
                                        child: Text(
                                          user.fullName.isEmpty ? '-' : user.fullName,
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                        ),
                                      ),
                                    ),
                                    // 2. Cột Email
                                    DataCell(
                                      Container(
                                        constraints: const BoxConstraints(maxWidth: 220),
                                        child: Text(
                                          user.email,
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                        ),
                                      ),
                                    ),
                                    // 3. Cột Số điện thoại
                                    DataCell(
                                      Text(user.phone.isEmpty ? '-' : user.phone),
                                    ),
                                    // 4. Cột Vai trò
                                    DataCell(
                                      Chip(
                                        label: Text(
                                          user.role,
                                          style: TextStyle(
                                            color: user.role == 'Admin'
                                                ? Colors.red
                                                : user.role == 'Editor'
                                                ? Colors.orange
                                                : Colors.blue,
                                          ),
                                        ),
                                      ),
                                    ),
                                    // 5. Cột Trạng thái
                                    DataCell(
                                      Chip(
                                        label: Text(
                                          user.isLocked ? 'Đã khóa' : 'Hoạt động',
                                          style: TextStyle(
                                            color: user.isLocked ? Colors.red : Colors.green,
                                          ),
                                        ),
                                        backgroundColor: user.isLocked
                                            ? Colors.red.shade50
                                            : Colors.green.shade50,
                                      ),
                                    ),
                                    // 6. Cột Thao tác
                                    DataCell(
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: Icon(
                                              user.isLocked ? Icons.lock_open : Icons.lock,
                                              color: user.isLocked ? Colors.green : Colors.orange,
                                            ),
                                            tooltip: user.isLocked ? 'Mở khóa' : 'Khóa tài khoản',
                                            onPressed: () async {
                                              if (isSelf) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(
                                                    content: Text('Không hợp lệ'),
                                                    backgroundColor: Colors.red,
                                                    duration: Duration(seconds: 2),
                                                  ),
                                                );
                                                return;
                                              }

                                              await ref
                                                  .read(userManagementViewModelProvider)
                                                  .toggleLockUser(user.uid, user.isLocked);
                                            },
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.edit, color: Colors.blue),
                                            tooltip: 'Chỉnh sửa thông tin',
                                            onPressed: () => _showEditUserDialog(context, ref, user),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete, color: Colors.red),
                                            tooltip: 'Xóa người dùng',
                                            onPressed: () => _showDeleteDialog(context, ref, user, isSelf),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Center(child: Text('Lỗi tải dữ liệu: $err')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- MODAL THÊM NGƯỜI DÙNG MỚI ---
  void _showAddUserDialog(BuildContext context, WidgetRef ref) {
    final formKey = GlobalKey<FormState>();
    final fullNameController = TextEditingController();
    final emailController = TextEditingController();
    final phoneController = TextEditingController();
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
              content: SizedBox(
                width: 500,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: fullNameController,
                          decoration: const InputDecoration(
                            labelText: 'Họ và tên',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Email *',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Vui lòng nhập email';
                            }
                            if (!value.contains('@')) {
                              return 'Email không hợp lệ';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: phoneController,
                          keyboardType: TextInputType.phone,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Số điện thoại',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value != null && value.isNotEmpty) {
                              if (value.length < 9 || value.length > 11) {
                                return 'Số điện thoại phải từ 9 đến 11 chữ số';
                              }
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: passwordController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Mật khẩu *',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Vui lòng nhập mật khẩu';
                            }
                            if (value.length < 6) {
                              return 'Mật khẩu phải có ít nhất 6 ký tự';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
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
                    if (!formKey.currentState!.validate()) return;

                    setState(() => isLoading = true);

                    try {
                      await ref
                          .read(userManagementViewModelProvider)
                          .createUser(
                        email: emailController.text.trim(),
                        password: passwordController.text.trim(),
                        role: selectedRole,
                        fullName: fullNameController.text.trim(),
                        phone: phoneController.text.trim(),
                      );

                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Đã thêm người dùng ${emailController.text.trim()} thành công!',
                            ),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Lỗi: ${e.toString().replaceAll("Exception: ", "")}',
                            ),
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

  // --- MODAL CHỈNH SỬA THÔNG TIN NGƯỜI DÙNG ---
  void _showEditUserDialog(BuildContext context, WidgetRef ref, UserModel user) {
    final formKey = GlobalKey<FormState>();
    final fullNameController = TextEditingController(text: user.fullName);
    final phoneController = TextEditingController(text: user.phone);
    String currentRole = user.role;
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Chỉnh sửa người dùng (${user.email})'),
              content: SizedBox(
                width: 500,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: fullNameController,
                          decoration: const InputDecoration(
                            labelText: 'Họ và tên',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: phoneController,
                          keyboardType: TextInputType.phone,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Số điện thoại',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value != null && value.isNotEmpty) {
                              if (value.length < 9 || value.length > 11) {
                                return 'Số điện thoại phải từ 9 đến 11 chữ số';
                              }
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: currentRole,
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
                            if (val != null) setState(() => currentRole = val);
                          },
                        ),
                      ],
                    ),
                  ),
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
                    if (!formKey.currentState!.validate()) return;

                    setState(() => isLoading = true);

                    try {
                      await ref
                          .read(userManagementViewModelProvider)
                          .updateUserInfo(
                        uid: user.uid,
                        fullName: fullNameController.text.trim(),
                        phone: phoneController.text.trim(),
                        role: currentRole,
                      );

                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Cập nhật thông tin thành công!'),
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
                      : const Text('Cập nhật'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- MODAL XÁC NHẬN XÓA NGƯỜI DÙNG ---
  void _showDeleteDialog(BuildContext context, WidgetRef ref, UserModel user, bool isSelf) {
    if (isSelf) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không hợp lệ'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Xác nhận xóa'),
          content: Text('Bạn có chắc chắn muốn xóa tài khoản ${user.email}?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                await ref
                    .read(userManagementViewModelProvider)
                    .deleteUser(user.uid);
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Xóa', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }
}