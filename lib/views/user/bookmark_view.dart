import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../core/services/article_interaction_service.dart';
import '../../models/article_model.dart';
import 'article_detail_view.dart';

class BookmarkView extends StatefulWidget {
  const BookmarkView({super.key});

  @override
  State<BookmarkView> createState() => _BookmarkViewState();
}

class _BookmarkViewState extends State<BookmarkView> {
  List<ArticleModel> _bookmarks = [];
  Map<String, String> _categoryNames = {};
  String _selectedCategory = 'ALL';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBookmarks();
    _loadCategoryNames();
  }

  bool get _isLoggedIn => ArticleInteractionService.isUserLoggedIn;

  Future<void> _loadBookmarks() async {
    setState(() => _isLoading = true);
    final list = await ArticleInteractionService.getBookmarks();
    if (mounted) {
      setState(() {
        _bookmarks = list;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadCategoryNames() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('categories').get();
      final map = <String, String>{};
      for (final doc in snapshot.docs) {
        map[doc.id] = doc.data()['name'] ?? doc.id;
      }
      if (mounted) {
        setState(() => _categoryNames = map);
      }
    } catch (_) {}
  }

  // ==========================================
  // PHÂN LOẠI BÀI ĐÃ LƯU
  // ==========================================
  List<String> get _availableCategories {
    final catSet = <String>{};
    for (final article in _bookmarks) {
      if (article.categoryId.isNotEmpty) {
        catSet.add(article.categoryId);
      }
    }
    return catSet.toList();
  }

  List<ArticleModel> get _filteredBookmarks {
    if (_selectedCategory == 'ALL') {
      return _bookmarks;
    }
    return _bookmarks.where((b) => b.categoryId == _selectedCategory).toList();
  }

  // ==========================================
  // BỎ LƯU BÀI VIẾT
  // ==========================================
  Future<void> _handleRemoveBookmark(ArticleModel article) async {
    setState(() {
      _bookmarks.removeWhere((item) => item.id == article.id);
    });

    await ArticleInteractionService.removeBookmark(article.id);

    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã bỏ lưu bài viết "${article.title}"'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  String _formatPublishDate(int timestamp) {
    if (timestamp <= 0) return 'Đã lưu';
    final dt = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final year = dt.year;
    return '$day/$month/$year';
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoggedIn) {
      return Scaffold(
        appBar: AppBar(title: const Text('Danh sách yêu thích')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.bookmark_border, size: 72, color: Colors.blueGrey[400]),
                const SizedBox(height: 16),
                const Text(
                  'Yêu cầu đăng nhập',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Vui lòng đăng nhập tài khoản để xem và đồng bộ danh sách bài viết yêu thích đọc offline.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.pushNamed(context, '/login');
                  },
                  icon: const Icon(Icons.login),
                  label: const Text('Đăng nhập ngay'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final theme = Theme.of(context);
    final filteredList = _filteredBookmarks;
    final categories = _availableCategories;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tin đã lưu (Đọc Offline)'),
        elevation: 0.5,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadBookmarks,
              child: Column(
                children: [
                  // ==========================================
                  // BỘ LỌC PHÂN LOẠI CHUYÊN MỤC
                  // ==========================================
                  if (categories.isNotEmpty)
                    Container(
                      height: 52,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        children: [
                          ChoiceChip(
                            label: Text('Tất cả (${_bookmarks.length})'),
                            selected: _selectedCategory == 'ALL',
                            onSelected: (val) {
                              if (val) setState(() => _selectedCategory = 'ALL');
                            },
                          ),
                          const SizedBox(width: 8),
                          ...categories.map((catId) {
                            final name = _categoryNames[catId] ?? catId;
                            final count = _bookmarks.where((b) => b.categoryId == catId).length;
                            final isSelected = _selectedCategory == catId;

                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text('$name ($count)'),
                                selected: isSelected,
                                onSelected: (val) {
                                  if (val) setState(() => _selectedCategory = catId);
                                },
                              ),
                            );
                          }),
                        ],
                      ),
                    ),

                  const Divider(height: 1),

                  // ==========================================
                  // DANH SÁCH BÀI VIẾT ĐÃ LƯU
                  // ==========================================
                  Expanded(
                    child: filteredList.isEmpty
                        ? _buildEmptyState()
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: filteredList.length,
                            separatorBuilder: (context, index) => const Divider(
                              height: 1,
                              indent: 96,
                              endIndent: 16,
                            ),
                            itemBuilder: (context, index) {
                              final article = filteredList[index];
                              final categoryName = _categoryNames[article.categoryId] ?? '';

                              return Dismissible(
                                key: Key('bookmark_${article.id}'),
                                direction: DismissDirection.endToStart,
                                background: Container(
                                  color: Colors.redAccent,
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.only(right: 24),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.bookmark_remove, color: Colors.white),
                                      SizedBox(width: 6),
                                      Text(
                                        'Bỏ lưu',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                onDismissed: (_) => _handleRemoveBookmark(article),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  onTap: () {
                                    // Mở bài báo trực tiếp (hoạt động offline ngay từ dữ liệu đã lưu)
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ArticleDetailView(article: article),
                                      ),
                                    ).then((_) => _loadBookmarks());
                                  },
                                  // Ảnh đại diện
                                  leading: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      width: 72,
                                      height: 72,
                                      color: Colors.grey[200],
                                      child: article.thumbnailUrl.isNotEmpty
                                          ? Image.network(
                                              article.thumbnailUrl,
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error, stackTrace) =>
                                                  const Icon(Icons.broken_image, color: Colors.grey),
                                            )
                                          : const Icon(Icons.article_outlined, color: Colors.grey),
                                    ),
                                  ),
                                  // Tiêu đề & metadata
                                  title: Text(
                                    article.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                    ),
                                  ),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Row(
                                      children: [
                                        if (categoryName.isNotEmpty) ...[
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: theme.colorScheme.primary.withAlpha(20),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              categoryName,
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: theme.colorScheme.primary,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                        ],
                                        Text(
                                          _formatPublishDate(article.publishedAt),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Nút Bỏ lưu bài viết
                                  trailing: IconButton(
                                    tooltip: 'Bỏ lưu bài viết',
                                    icon: const Icon(
                                      Icons.bookmark_remove_outlined,
                                      color: Colors.amber,
                                      size: 22,
                                    ),
                                    onPressed: () => _handleRemoveBookmark(article),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildEmptyState() {
    final isFiltered = _selectedCategory != 'ALL';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isFiltered ? Icons.filter_alt_off : Icons.bookmark_border,
              size: 72,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              isFiltered
                  ? 'Không có bài viết đã lưu trong chuyên mục này'
                  : 'Chưa có bài viết nào được lưu',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isFiltered
                  ? 'Hãy chọn "Tất cả" hoặc chuyên mục khác để xem.'
                  : 'Hãy bấm biểu tượng Lưu tin ở các bài báo để lưu lại và đọc offline bất cứ khi nào bạn muốn.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey[500]),
            ),
            if (isFiltered) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => setState(() => _selectedCategory = 'ALL'),
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Xem tất cả bài đã lưu'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
