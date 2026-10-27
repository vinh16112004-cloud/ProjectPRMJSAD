import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/article_model.dart';
import '../../providers/article_provider.dart';

class EditArticleView extends ConsumerStatefulWidget {
  final ArticleModel article;
  const EditArticleView({Key? key, required this.article}) : super(key: key);

  @override
  ConsumerState<EditArticleView> createState() => _EditArticleViewState();
}

class _EditArticleViewState extends ConsumerState<EditArticleView> {
  late TextEditingController _titleController;
  late TextEditingController _summaryController;
  late TextEditingController _contentController;
  late TextEditingController _authorController;
  late TextEditingController _thumbnailController;
  late int _status;
  late bool _isHot;
  String? _selectedCategoryId;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.article.title);
    _summaryController = TextEditingController(text: widget.article.summary);
    _contentController = TextEditingController(text: widget.article.content);
    _authorController = TextEditingController(text: widget.article.author);
    _thumbnailController = TextEditingController(text: widget.article.thumbnailUrl);
    _status = widget.article.status;
    _isHot = widget.article.isHot;
    _selectedCategoryId = widget.article.categoryId; // Gán ID chuyên mục hiện tại của bài viết
  }

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
    // Lấy danh sách chuyên mục từ Firestore thông qua Riverpod
    final categoriesAsync = ref.watch(categoryListStreamProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Chỉnh sửa bài báo')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          child: ListView(
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Tiêu đề bài viết'),
              ),
              const SizedBox(height: 12),

              // Dropdown chọn chuyên mục lấy động và tự động chọn sẵn giá trị cũ
              categoriesAsync.when(
                data: (categories) {
                  if (categories.isEmpty) {
                    return const Text('Chưa có chuyên mục nào.');
                  }

                  // Kiểm tra xem chuyên mục cũ còn tồn tại không, nếu không thì lấy phần tử đầu tiên
                  bool exists = categories.any((cat) => cat.id == _selectedCategoryId);
                  if (!exists && categories.isNotEmpty) {
                    _selectedCategoryId = categories.first.id;
                  }

                  return DropdownButtonFormField<String>(
                    value: _selectedCategoryId,
                    decoration: const InputDecoration(labelText: 'Chọn chuyên mục'),
                    items: categories.map((cat) {
                      return DropdownMenuItem<String>(
                        value: cat.id,
                        child: Text(cat.name),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedCategoryId = val;
                      });
                    },
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
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _authorController,
                decoration: const InputDecoration(labelText: 'Tác giả'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _thumbnailController,
                decoration: const InputDecoration(labelText: 'URL Ảnh đại diện'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                value: _status,
                items: const [
                  DropdownMenuItem(value: 0, child: Text('Nháp')),
                  DropdownMenuItem(value: 1, child: Text('Đã xuất bản')),
                  DropdownMenuItem(value: 2, child: Text('Đã ẩn')),
                ],
                onChanged: (val) => setState(() => _status = val!),
                decoration: const InputDecoration(labelText: 'Trạng thái bài viết'),
              ),
              SwitchListTile(
                title: const Text('Bài viết nổi bật (Hot)'),
                value: _isHot,
                onChanged: (val) => setState(() => _isHot = val),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _updateArticle,
                icon: const Icon(Icons.update),
                label: const Text('Cập nhật'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _updateArticle() {
    final updatedData = {
      'title': _titleController.text.trim(),
      'summary': _summaryController.text.trim(),
      'content': _contentController.text.trim(),
      'author': _authorController.text.trim(),
      'thumbnail_url': _thumbnailController.text.trim(),
      'category_id': _selectedCategoryId ?? '', // Cập nhật chuyên mục mới được chọn
      'status': _status,
      'is_hot': _isHot,
    };

    ref.read(articleControllerProvider.notifier).updateArticle(widget.article.id, updatedData);
    Navigator.pop(context);
  }
}