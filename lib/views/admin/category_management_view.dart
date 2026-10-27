import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/category_model.dart';
import '../../viewmodels/category_management_viewmodel.dart';

class CategoryManagementView extends ConsumerWidget {
  const CategoryManagementView({super.key});

  // Hàm phụ trợ giải mã link Google Images (imgurl=...) thành URL ảnh gốc (.jpg, .png...)
  String _fixImageUrl(String rawUrl) {
    if (rawUrl.contains('imgurl=')) {
      try {
        final uri = Uri.parse(rawUrl);
        final realUrl = uri.queryParameters['imgurl'];
        if (realUrl != null && realUrl.isNotEmpty) {
          return Uri.decodeFull(realUrl);
        }
      } catch (_) {}
    }
    return rawUrl;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoryListStreamProvider);

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
                  'Danh sách chuyên mục',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                ElevatedButton.icon(
                  onPressed: () => _showAddCategoryDialog(context, ref),
                  icon: const Icon(Icons.add),
                  label: const Text('Thêm chuyên mục'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: categoriesAsync.when(
                data: (categories) {
                  if (categories.isEmpty) {
                    return const Center(child: Text('Chưa có chuyên mục nào.'));
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
                              columnSpacing: 28,
                              columns: const [
                                DataColumn(label: Text('ID (Bấm xem chi tiết)')),
                                DataColumn(label: Text('Tên chuyên mục')),
                                DataColumn(label: Text('Trạng thái (isActive)')),
                                DataColumn(label: Text('Thao tác')),
                              ],
                              rows: categories.map((category) {
                                return DataRow(
                                  cells: [
                                    // 1. Cột ID - Click để xem chi tiết
                                    DataCell(
                                      InkWell(
                                        onTap: () => _showCategoryDetailDialog(context, category),
                                        child: Text(
                                          category.id,
                                          style: const TextStyle(
                                            color: Colors.blue,
                                            decoration: TextDecoration.underline,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                    // 2. Cột Tên chuyên mục (Name)
                                    DataCell(
                                      Container(
                                        constraints: const BoxConstraints(maxWidth: 220),
                                        child: Text(
                                          category.name,
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                        ),
                                      ),
                                    ),
                                    // 3. Cột Trạng thái (isActive)
                                    DataCell(
                                      Chip(
                                        label: Text(
                                          category.isActive ? 'Hoạt động' : 'Tắt',
                                          style: TextStyle(
                                            color: category.isActive ? Colors.green : Colors.grey,
                                          ),
                                        ),
                                        backgroundColor: category.isActive
                                            ? Colors.green.shade50
                                            : Colors.grey.shade200,
                                      ),
                                    ),
                                    // 4. Cột Thao tác
                                    DataCell(
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: Icon(
                                              category.isActive ? Icons.visibility : Icons.visibility_off,
                                              color: category.isActive ? Colors.green : Colors.grey,
                                            ),
                                            tooltip: category.isActive ? 'Ẩn chuyên mục' : 'Hiện chuyên mục',
                                            onPressed: () async {
                                              await ref
                                                  .read(categoryManagementViewModelProvider)
                                                  .toggleCategoryStatus(category.id, category.isActive);
                                            },
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.edit, color: Colors.blue),
                                            tooltip: 'Chỉnh sửa',
                                            onPressed: () => _showEditCategoryDialog(context, ref, category),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete, color: Colors.red),
                                            tooltip: 'Xóa',
                                            onPressed: () => _showDeleteCategoryDialog(context, ref, category),
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

  // --- MODAL XEM CHI TIẾT CHUYÊN MỤC ---
  void _showCategoryDetailDialog(BuildContext context, CategoryModel category) {
    final fixedIconUrl = _fixImageUrl(category.iconUrl);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Chi tiết: ${category.name}'),
          content: SizedBox(
            width: 550,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildDetailRow('ID:', category.id),
                  const Divider(),
                  _buildDetailRow('Tên chuyên mục:', category.name),
                  const Divider(),

                  // 1. Hiển thị Icon Chuyên mục
                  const Text('Icon chuyên mục:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  if (fixedIconUrl.isNotEmpty) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        fixedIconUrl,
                        height: 120,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => Container(
                          padding: const EdgeInsets.all(8),
                          color: Colors.red.shade50,
                          child: const Row(
                            children: [
                              Icon(Icons.broken_image, color: Colors.red),
                              SizedBox(width: 8),
                              Text('Không thể tải hình ảnh từ URL này', style: TextStyle(color: Colors.red)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ] else ...[
                    const Text('Chưa có icon', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic,)),
                  ],
                  const Divider(),

                  // 2. Nội dung Mô tả (Hỗ trợ Render Markdown + Render Hình ảnh)
                  const Text(
                    'Mô tả (Markdown):',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: category.description.trim().isEmpty
                        ? const Text('Không có mô tả', style: TextStyle(color: Colors.grey))
                        : MarkdownBody(
                      data: category.description,
                      selectable: true,
                      imageBuilder: (uri, title, alt) {
                        final cleanedUrl = _fixImageUrl(uri.toString());
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              cleanedUrl,
                              errorBuilder: (context, error, stackTrace) =>
                              const Text('[Lỗi tải hình ảnh]', style: TextStyle(color: Colors.red)),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const Divider(),
                  _buildDetailRow('Thứ tự (displayOrder):', '${category.displayOrder}'),
                  const Divider(),
                  _buildDetailRow('Trạng thái (isActive):', category.isActive ? 'Hoạt động' : 'Tắt'),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Đóng'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 160,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  // --- MODAL THÊM CHUYÊN MỤC MỚI ---
  void _showAddCategoryDialog(BuildContext context, WidgetRef ref) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    final iconUrlController = TextEditingController();
    final displayOrderController = TextEditingController(text: '0');
    bool isActive = true;
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return DefaultTabController(
              length: 2,
              child: AlertDialog(
                title: const Text('Thêm chuyên mục mới'),
                content: SizedBox(
                  width: 550,
                  child: Form(
                    key: formKey,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextFormField(
                            controller: nameController,
                            decoration: const InputDecoration(
                              labelText: 'Tên chuyên mục *',
                              border: OutlineInputBorder(),
                            ),
                            validator: (val) =>
                            val == null || val.trim().isEmpty ? 'Vui lòng nhập tên chuyên mục' : null,
                          ),
                          const SizedBox(height: 16),

                          // Tab Soạn thảo & Xem trước Markdown
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const TabBar(
                                labelColor: Colors.blue,
                                unselectedLabelColor: Colors.grey,
                                tabs: [
                                  Tab(icon: Icon(Icons.edit_note), text: 'Soạn thảo Markdown'),
                                  Tab(icon: Icon(Icons.remove_red_eye), text: 'Xem trước (Preview)'),
                                ],
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                height: 180,
                                child: TabBarView(
                                  children: [
                                    TextFormField(
                                      controller: descriptionController,
                                      maxLines: null,
                                      expands: true,
                                      textAlignVertical: TextAlignVertical.top,
                                      decoration: const InputDecoration(
                                        hintText: 'Nhập nội dung Markdown...\nVí dụ ảnh: ![mô tả](https://link-anh.jpg)',
                                        border: OutlineInputBorder(),
                                      ),
                                      onChanged: (val) => setState(() {}),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade50,
                                        border: Border.all(color: Colors.grey.shade300),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: SingleChildScrollView(
                                        child: descriptionController.text.trim().isEmpty
                                            ? const Text('Chưa có nội dung xem trước',
                                            style: TextStyle(color: Colors.grey))
                                            : MarkdownBody(
                                          data: descriptionController.text,
                                          selectable: true,
                                          imageBuilder: (uri, title, alt) {
                                            final cleanedUrl = _fixImageUrl(uri.toString());
                                            return Padding(
                                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                                              child: Image.network(cleanedUrl),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: iconUrlController,
                            decoration: const InputDecoration(
                              labelText: 'Icon URL',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: displayOrderController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            decoration: const InputDecoration(
                              labelText: 'Thứ tự hiển thị (Display Order)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 16),
                          SwitchListTile(
                            title: const Text('Trạng thái hoạt động (isActive)'),
                            value: isActive,
                            onChanged: (val) => setState(() => isActive = val),
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
                        await ref.read(categoryManagementViewModelProvider).createCategory(
                          name: nameController.text.trim(),
                          description: descriptionController.text.trim(),
                          iconUrl: iconUrlController.text.trim(),
                          displayOrder: int.tryParse(displayOrderController.text.trim()) ?? 0,
                          isActive: isActive,
                        );
                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Thêm chuyên mục thành công!'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Lỗi: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      } finally {
                        if (context.mounted) setState(() => isLoading = false);
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
              ),
            );
          },
        );
      },
    );
  }

  // --- MODAL CHỈNH SỬA CHUYÊN MỤC ---
  void _showEditCategoryDialog(BuildContext context, WidgetRef ref, CategoryModel category) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: category.name);
    final descriptionController = TextEditingController(text: category.description);
    final iconUrlController = TextEditingController(text: category.iconUrl);
    final displayOrderController = TextEditingController(text: category.displayOrder.toString());
    bool isActive = category.isActive;
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return DefaultTabController(
              length: 2,
              child: AlertDialog(
                title: Text('Chỉnh sửa chuyên mục (${category.name})'),
                content: SizedBox(
                  width: 550,
                  child: Form(
                    key: formKey,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextFormField(
                            controller: nameController,
                            decoration: const InputDecoration(
                              labelText: 'Tên chuyên mục *',
                              border: OutlineInputBorder(),
                            ),
                            validator: (val) =>
                            val == null || val.trim().isEmpty ? 'Vui lòng nhập tên' : null,
                          ),
                          const SizedBox(height: 16),

                          // Tab Soạn thảo & Xem trước Markdown
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const TabBar(
                                labelColor: Colors.blue,
                                unselectedLabelColor: Colors.grey,
                                tabs: [
                                  Tab(icon: Icon(Icons.edit_note), text: 'Soạn thảo Markdown'),
                                  Tab(icon: Icon(Icons.remove_red_eye), text: 'Xem trước (Preview)'),
                                ],
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                height: 180,
                                child: TabBarView(
                                  children: [
                                    TextFormField(
                                      controller: descriptionController,
                                      maxLines: null,
                                      expands: true,
                                      textAlignVertical: TextAlignVertical.top,
                                      decoration: const InputDecoration(
                                        hintText: 'Nhập nội dung Markdown...',
                                        border: OutlineInputBorder(),
                                      ),
                                      onChanged: (val) => setState(() {}),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade50,
                                        border: Border.all(color: Colors.grey.shade300),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: SingleChildScrollView(
                                        child: descriptionController.text.trim().isEmpty
                                            ? const Text('Chưa có nội dung xem trước',
                                            style: TextStyle(color: Colors.grey))
                                            : MarkdownBody(
                                          data: descriptionController.text,
                                          selectable: true,
                                          imageBuilder: (uri, title, alt) {
                                            final cleanedUrl = _fixImageUrl(uri.toString());
                                            return Padding(
                                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                                              child: Image.network(cleanedUrl),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: iconUrlController,
                            decoration: const InputDecoration(
                              labelText: 'Icon URL',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: displayOrderController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            decoration: const InputDecoration(
                              labelText: 'Thứ tự hiển thị',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 16),
                          SwitchListTile(
                            title: const Text('Trạng thái hoạt động (isActive)'),
                            value: isActive,
                            onChanged: (val) => setState(() => isActive = val),
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
                        await ref.read(categoryManagementViewModelProvider).updateCategory(
                          id: category.id,
                          name: nameController.text.trim(),
                          description: descriptionController.text.trim(),
                          iconUrl: iconUrlController.text.trim(),
                          displayOrder: int.tryParse(displayOrderController.text.trim()) ?? 0,
                          isActive: isActive,
                        );
                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Cập nhật thành công!'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Lỗi: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      } finally {
                        if (context.mounted) setState(() => isLoading = false);
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
              ),
            );
          },
        );
      },
    );
  }

  // --- MODAL XÓA CHUYÊN MỤC ---
  void _showDeleteCategoryDialog(BuildContext context, WidgetRef ref, CategoryModel category) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Xác nhận xóa'),
          content: Text('Bạn có chắc chắn muốn xóa chuyên mục "${category.name}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                await ref.read(categoryManagementViewModelProvider).deleteCategory(category.id);
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