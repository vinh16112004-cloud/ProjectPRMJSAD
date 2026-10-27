import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/article_model.dart';
import '../../providers/article_provider.dart';

class AddArticleView extends ConsumerStatefulWidget {
  const AddArticleView({Key? key}) : super(key: key);

  @override
  ConsumerState<AddArticleView> createState() => _AddArticleViewState();
}

class _AddArticleViewState extends ConsumerState<AddArticleView> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _summaryController = TextEditingController();
  final _contentController = TextEditingController();
  final _authorController = TextEditingController();
  final _thumbnailController = TextEditingController();

  String? _selectedCategoryId; // Biến lưu categoryId được chọn
  bool _isHot = false;

  @override
  void dispose() {
    _titleController.dispose();
    _summaryController.dispose();
    _contentController.dispose();
    _authorController.dispose();
    _thumbnailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Lắng nghe danh sách chuyên mục từ Firestore
    final categoriesAsync = ref.watch(categoryListStreamProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Thêm bài báo mới')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Tiêu đề bài viết'),
                validator: (v) => v!.isEmpty ? 'Không được để trống' : null,
              ),
              const SizedBox(height: 12),

              // Dropdown chọn chuyên mục lấy động từ Firestore
              categoriesAsync.when(
                data: (categories) {
                  if (categories.isEmpty) {
                    return const Text('Chưa có chuyên mục nào. Vui lòng tạo chuyên mục trước!');
                  }

                  // Nếu chưa chọn, mặc định lấy ID của chuyên mục đầu tiên
                  _selectedCategoryId ??= categories.first.id;

                  return DropdownButtonFormField<String>(
                    value: _selectedCategoryId,
                    decoration: const InputDecoration(labelText: 'Chọn chuyên mục'),
                    items: categories.map((cat) {
                      return DropdownMenuItem<String>(
                        value: cat.id,
                        child: Text(cat.name),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedCategoryId = value;
                      });
                    },
                    validator: (v) => v == null ? 'Vui lòng chọn chuyên mục' : null,
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Text('Lỗi tải chuyên mục: $err'),
              ),

              const SizedBox(height: 12),
              TextFormField(
                controller: _summaryController,
                decoration: const InputDecoration(labelText: 'Tóm tắt'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _contentController,
                decoration: const InputDecoration(labelText: 'Nội dung chi tiết'),
                maxLines: 5,
                validator: (v) => v!.isEmpty ? 'Không được để trống' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _authorController,
                decoration: const InputDecoration(labelText: 'Tác giả / Biên tập viên'),
                validator: (v) => v!.isEmpty ? 'Không được để trống' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _thumbnailController,
                decoration: const InputDecoration(labelText: 'URL Ảnh đại diện (Thumbnail)'),
              ),
              SwitchListTile(
                title: const Text('Bài viết nổi bật (Hot)'),
                value: _isHot,
                onChanged: (val) => setState(() => _isHot = val),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _saveArticle(0), // 0: Lưu nháp
                    icon: const Icon(Icons.save),
                    label: const Text('Lưu nháp'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _saveArticle(1), // 1: Xuất bản
                    icon: const Icon(Icons.publish),
                    label: const Text('Xuất bản'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _saveArticle(int status) {
    if (_formKey.currentState!.validate() && _selectedCategoryId != null) {
      final newArticle = ArticleModel(
        id: '', // Firestore tự sinh ID
        title: _titleController.text.trim(),
        summary: _summaryController.text.trim(),
        content: _contentController.text.trim(),
        categoryId: _selectedCategoryId!, // Lưu ID chuyên mục đã chọn
        thumbnailUrl: _thumbnailController.text.trim(),
        author: _authorController.text.trim(),
        status: status,
        isHot: _isHot,
        publishedAt: DateTime.now().millisecondsSinceEpoch,
      );

      ref.read(articleControllerProvider.notifier).addArticle(newArticle);
      Navigator.pop(context);
    }
  }
}