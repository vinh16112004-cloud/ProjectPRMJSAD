import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/article_model.dart';
import '../../providers/article_provider.dart';
import 'add_article_view.dart';
import 'edit_article_view.dart';

class ArticleManagementView extends ConsumerStatefulWidget {
  const ArticleManagementView({Key? key}) : super(key: key);

  @override
  ConsumerState<ArticleManagementView> createState() => _ArticleManagementViewState();
}

class _ArticleManagementViewState extends ConsumerState<ArticleManagementView> {
  String searchQuery = '';
  int? selectedStatusFilter; // null: Tất cả, 0: Nháp, 1: Đã xuất bản, 2: Đã ẩn

  @override
  Widget build(BuildContext context) {
    final articleAsync = ref.watch(articleStreamProvider);
    final categoriesAsync = ref.watch(categoryListStreamProvider); // Lấy danh sách chuyên mục để tra cứu tên

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lí bài báo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AddArticleView()),
              );
            },
          )
        ],
      ),
      body: Column(
        children: [
          // Thanh tìm kiếm và bộ lọc trạng thái
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: 'Tìm kiếm bài viết...',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) => setState(() => searchQuery = value),
                  ),
                ),
                const SizedBox(width: 8),
                DropdownButton<int?>(
                  value: selectedStatusFilter,
                  hint: const Text('Trạng thái'),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('Tất cả')),
                    DropdownMenuItem(value: 0, child: Text('Nháp')),
                    DropdownMenuItem(value: 1, child: Text('Xuất bản')),
                    DropdownMenuItem(value: 2, child: Text('Đã ẩn')),
                  ],
                  onChanged: (value) => setState(() => selectedStatusFilter = value),
                ),
              ],
            ),
          ),
          // Danh sách bài báo kết hợp ánh xạ tên chuyên mục
          Expanded(
            child: articleAsync.when(
              data: (articles) {
                return categoriesAsync.when(
                  data: (categories) {
                    // Tạo Map tra cứu nhanh tên chuyên mục từ ID
                    final Map<String, String> categoryMap = {
                      for (var cat in categories) cat.id: cat.name
                    };

                    // Lọc dữ liệu theo từ khóa và trạng thái
                    final filteredList = articles.where((article) {
                      final matchesSearch = article.title.toLowerCase().contains(searchQuery.toLowerCase()) ||
                          article.author.toLowerCase().contains(searchQuery.toLowerCase());
                      final matchesStatus = selectedStatusFilter == null || article.status == selectedStatusFilter;
                      return matchesSearch && matchesStatus;
                    }).toList();

                    if (filteredList.isEmpty) {
                      return const Center(child: Text('Không tìm thấy bài báo nào.'));
                    }

                    return ListView.builder(
                      itemCount: filteredList.length,
                      itemBuilder: (context, index) {
                        final article = filteredList[index];
                        final categoryName = categoryMap[article.categoryId] ?? 'Chưa phân loại';

                        return ListTile(
                          leading: article.thumbnailUrl.isNotEmpty
                              ? Image.network(article.thumbnailUrl, width: 50, height: 50, fit: BoxFit.cover)
                              : const Icon(Icons.article),
                          title: Text(article.title),
                          subtitle: Text('Chuyên mục: $categoryName | Tác giả: ${article.author}\nTrạng thái: ${_getStatusText(article.status)}'),
                          isThreeLine: true,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.blue),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => EditArticleView(article: article)),
                                  );
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _confirmDelete(context, ref, article.id),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, _) => Center(child: Text('Lỗi tải chuyên mục: $err')),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Lỗi: $err')),
            ),
          ),
        ],
      ),
    );
  }

  String _getStatusText(int status) {
    switch (status) {
      case 0: return 'Nháp';
      case 1: return 'Đã xuất bản';
      case 2: return 'Đã ẩn';
      default: return 'Không rõ';
    }
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: const Text('Bạn có chắc chắn muốn xóa bài báo này không?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
          TextButton(
            onPressed: () {
              ref.read(articleControllerProvider.notifier).deleteArticle(id);
              Navigator.pop(context);
            },
            child: const Text('Xóa', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}