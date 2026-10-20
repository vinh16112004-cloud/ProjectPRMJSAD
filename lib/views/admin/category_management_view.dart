import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:untitled1/models/category_model.dart';
import 'package:untitled1/viewmodels/category_management_viewmodel.dart';


class CategoryManagementView extends ConsumerWidget {
  const CategoryManagementView({Key? key}) : super(key: key);

  // Hàm hiển thị Dialog Thêm / Sửa Chuyên mục
  void _showCategoryDialog(BuildContext context, WidgetRef ref, {CategoryModel? category}) {
    final nameController = TextEditingController(text: category?.name ?? '');
    final descController = TextEditingController(text: category?.description ?? '');
    final iconController = TextEditingController(text: category?.iconUrl ?? '');
    final orderController = TextEditingController(text: category?.displayOrder.toString() ?? '0');
    bool isActive = category?.isActive ?? true;
    bool isLoading = false;

    final isEditing = category != null;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(isEditing ? 'Sửa chuyên mục' : 'Thêm chuyên mục mới'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Tên chuyên mục',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descController,
                      decoration: const InputDecoration(
                        labelText: 'Mô tả',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: iconController,
                      decoration: const InputDecoration(
                        labelText: 'Icon URL',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: orderController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Thứ tự hiển thị (displayOrder)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      title: const Text('Trạng thái hoạt động'),
                      value: isActive,
                      onChanged: (val) {
                        setState(() => isActive = val);
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
                    final name = nameController.text.trim();
                    if (name.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Tên chuyên mục không được để trống'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                      return;
                    }

                    final displayOrder = int.tryParse(orderController.text.trim()) ?? 0;

                    setState(() => isLoading = true);

                    try {
                      final vm = ref.read(categoryManagementViewModelProvider);
                      if (isEditing) {
                        await vm.updateCategory(
                          id: category.id,
                          name: name,
                          description: descController.text.trim(),
                          iconUrl: iconController.text.trim(),
                          displayOrder: displayOrder,
                          isActive: isActive,
                        );
                      } else {
                        await vm.addCategory(
                          name: name,
                          description: descController.text.trim(),
                          iconUrl: iconController.text.trim(),
                          displayOrder: displayOrder,
                        );
                      }

                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(isEditing ? 'Cập nhật thành công!' : 'Thêm mới thành công!'),
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
                      : Text(isEditing ? 'Lưu thay đổi' : 'Tạo mới'),
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
    final categoryListAsync = ref.watch(categoryListProvider);
    final categoryVm = ref.read(categoryManagementViewModelProvider);

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            // Tiêu đề + Nút thêm chuyên mục
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Quản lý Chuyên mục',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _showCategoryDialog(context, ref),
                  icon: const Icon(Icons.add),
                  label: const Text('Thêm chuyên mục'),
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

            // Danh sách hiển thị dạng bảng/card
            Expanded(
              child: categoryListAsync.when(
                data: (categories) {
                  if (categories.isEmpty) {
                    return const Center(child: Text('Chưa có chuyên mục nào.'));
                  }
                  return Card(
                    elevation: 2,
                    child: ListView.separated(
                      itemCount: categories.length,
                      separatorBuilder: (context, index) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final category = categories[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: category.isActive ? Colors.blue : Colors.grey,
                            child: Text(
                              '${category.displayOrder}',
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          title: Text(
                            category.name,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              decoration: category.isActive ? null : TextDecoration.lineThrough,
                            ),
                          ),
                          subtitle: Text(
                            'Mô tả: ${category.description.isNotEmpty ? category.description : "Không có"}',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Bật/Tắt Active trực tiếp
                              Switch(
                                value: category.isActive,
                                onChanged: (val) {
                                  categoryVm.toggleCategoryStatus(category.id, category.isActive);
                                },
                              ),
                              const SizedBox(width: 8),
                              // Nút Sửa
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.blue),
                                tooltip: 'Sửa',
                                onPressed: () => _showCategoryDialog(context, ref, category: category),
                              ),
                              // Nút Xóa
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                tooltip: 'Xóa',
                                onPressed: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Xác nhận xóa'),
                                      content: Text('Bạn có chắc chắn muốn xóa chuyên mục "${category.name}" không?'),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(context, false),
                                          child: const Text('Hủy'),
                                        ),
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                          onPressed: () => Navigator.pop(context, true),
                                          child: const Text('Xóa'),
                                        ),
                                      ],
                                    ),
                                  );

                                  if (confirm == true) {
                                    await categoryVm.deleteCategory(category.id);
                                  }
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