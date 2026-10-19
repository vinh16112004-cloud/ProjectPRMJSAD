import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../viewmodels/category_management_viewmodel.dart';
import '../../models/category_model.dart';

class CategoryManagementView extends ConsumerWidget {
  const CategoryManagementView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Lắng nghe dữ liệu từ Provider
    final categoryAsync = ref.watch(categoryListProvider);
    final viewModel = ref.read(categoryViewModelProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý Chuyên mục Bài báo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              // Điều hướng đến form Thêm chuyên mục
            },
          ),
        ],
      ),
      body: categoryAsync.when(
        data: (categories) {
          if (categories.isEmpty) {
            return const Center(child: Text('Chưa có chuyên mục nào.'));
          }
          return ListView.builder(
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final cat = categories[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundImage: NetworkImage(cat.imageUrl),
                  ),
                  title: Text(cat.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Số bài báo: ${cat.articleCount} | Ưu tiên: ${cat.priority}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Công tắc Ẩn/Hiện chuyên mục trên trang chủ
                      Switch(
                        value: cat.isVisible,
                        onChanged: (val) {
                          viewModel.toggleVisibility(cat.id, cat.isVisible);
                        },
                      ),
                      // Nút Xóa chuyên mục
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () {
                          // Xác nhận trước khi xóa
                          _showDeleteDialog(context, viewModel, cat.id);
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Đã xảy ra lỗi: $err')),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, CategoryViewModel viewModel, String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: const Text('Bạn có chắc chắn muốn xóa chuyên mục này không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () {
              viewModel.deleteCategory(id);
              Navigator.pop(context);
            },
            child: const Text('Xóa', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}