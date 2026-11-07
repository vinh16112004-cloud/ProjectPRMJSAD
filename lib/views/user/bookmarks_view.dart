import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/interaction_storage_service.dart';
import '../../models/article_model.dart';
import '../../models/category_model.dart';
import '../../providers/article_provider.dart';
import 'article_detail_view.dart';

class BookmarksView extends ConsumerStatefulWidget {
  const BookmarksView({super.key});

  @override
  ConsumerState<BookmarksView> createState() => _BookmarksViewState();
}

class _BookmarksViewState extends ConsumerState<BookmarksView> {
  List<ArticleModel> _savedArticles = [];
  bool _isLoading = true;

  // Tìm kiếm trong danh sách đã lưu
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isSearchOpen = false;

  // Phân loại theo chuyên mục
  String _selectedCategoryId = 'ALL';

  @override
  void initState() {
    super.initState();
    _loadBookmarks();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadBookmarks() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() {
          _savedArticles = [];
          _isLoading = false;
        });
      }
      return;
    }

    setState(() => _isLoading = true);
    final articles = await InteractionStorageService.getBookmarkedArticles();
    if (mounted) {
      setState(() {
        _savedArticles = articles;
        _isLoading = false;
      });
    }
  }

  // ===========================================================================
  // BỎ LƯU BÀI VIẾT (UN-BOOKMARK) CÓ HOÀN TÁC (UNDO)
  // ===========================================================================

  Future<void> _removeBookmark(ArticleModel article, int index) async {
    await InteractionStorageService.removeBookmark(article.id);
    setState(() {
      _savedArticles.removeWhere((item) => item.id == article.id);
    });

    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã bỏ lưu: "${article.title}"'),
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'Hoàn tác',
            textColor: Colors.amberAccent,
            onPressed: () async {
              await InteractionStorageService.toggleBookmark(article);
              setState(() {
                _savedArticles.insert(index.clamp(0, _savedArticles.length), article);
              });
            },
          ),
        ),
      );
    }
  }

  Future<void> _clearAllBookmarks() async {
    if (_savedArticles.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bỏ lưu toàn bộ?'),
        content: const Text(
          'Bạn có chắc chắn muốn bỏ lưu tất cả các bài viết trong danh sách yêu thích?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Bỏ lưu tất cả'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      for (final a in _savedArticles) {
        await InteractionStorageService.removeBookmark(a.id);
      }
      setState(() {
        _savedArticles.clear();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã dọn sạch danh sách bài viết yêu thích'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // ===========================================================================
  // GIAO DIỆN CHÍNH
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final categoriesAsync = ref.watch(categoryListStreamProvider);

    // Lọc danh sách theo chuyên mục và từ khóa tìm kiếm
    final filteredArticles = _savedArticles.where((article) {
      final matchesCategory = _selectedCategoryId == 'ALL' || article.categoryId == _selectedCategoryId;
      final matchesSearch = _searchQuery.isEmpty ||
          article.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          article.summary.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCategory && matchesSearch;
    }).toList();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: _isSearchOpen
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Tìm trong bài viết đã lưu...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                onChanged: (val) {
                  setState(() => _searchQuery = val);
                },
              )
            : const Text('Danh sách yêu thích'),
        actions: [
          // Nút mở/đóng tìm kiếm
          IconButton(
            icon: Icon(_isSearchOpen ? Icons.close : Icons.search),
            tooltip: _isSearchOpen ? 'Đóng tìm kiếm' : 'Tìm kiếm bài đã lưu',
            onPressed: () {
              setState(() {
                _isSearchOpen = !_isSearchOpen;
                if (!_isSearchOpen) {
                  _searchController.clear();
                  _searchQuery = '';
                }
              });
            },
          ),

          // Nút bỏ lưu toàn bộ
          if (_savedArticles.isNotEmpty && !_isSearchOpen)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: 'Bỏ lưu tất cả',
              onPressed: _clearAllBookmarks,
            ),
        ],
      ),

      body: FirebaseAuth.instance.currentUser == null
          ? _buildRequireLoginState(isDark)
          : _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // =============================================================
                // THANH BANNER THÔNG TIN ĐỌC OFFLINE
                // =============================================================
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: isDark ? Colors.blue.shade900 : Colors.blue.shade50,
                  child: Row(
                    children: [
                      Icon(
                        Icons.offline_pin_outlined,
                        size: 18,
                        color: isDark ? Colors.blue.shade200 : Colors.blue.shade700,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Tất cả bài viết đã lưu đều sẵn sàng đọc offline mọi lúc.',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.blue.shade200 : Colors.blue.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // =============================================================
                // PHÂN LOẠI THEO CHUYÊN MỤC (CATEGORY CHIPS)
                // =============================================================
                if (_savedArticles.isNotEmpty)
                  categoriesAsync.when(
                    data: (categories) {
                      // Tập hợp các ID chuyên mục có trong danh sách đã lưu
                      final savedCategoryIds = _savedArticles.map((a) => a.categoryId).toSet();
                      final activeCategories = categories.where((c) => savedCategoryIds.contains(c.id)).toList();

                      return Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.grey[900] : Colors.white,
                          border: Border(
                            bottom: BorderSide(
                              color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
                            ),
                          ),
                        ),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: [
                              // Chip "Tất cả"
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: FilterChip(
                                  label: Text('Tất cả (${_savedArticles.length})'),
                                  selected: _selectedCategoryId == 'ALL',
                                  onSelected: (_) {
                                    setState(() => _selectedCategoryId = 'ALL');
                                  },
                                  selectedColor: Colors.amber.withValues(alpha: 0.2),
                                  checkmarkColor: Colors.amber[800],
                                  labelStyle: TextStyle(
                                    color: _selectedCategoryId == 'ALL'
                                        ? Colors.amber[900]
                                        : (isDark ? Colors.grey[300] : Colors.grey[800]),
                                    fontWeight: _selectedCategoryId == 'ALL' ? FontWeight.bold : FontWeight.normal,
                                  ),
                                  side: BorderSide(
                                    color: _selectedCategoryId == 'ALL'
                                        ? Colors.amber[800]!
                                        : (isDark ? Colors.grey[700]! : Colors.grey[300]!),
                                  ),
                                ),
                              ),

                              // Các chuyên mục cụ thể
                              ...activeCategories.map((cat) {
                                final isSelected = _selectedCategoryId == cat.id;
                                final count = _savedArticles.where((a) => a.categoryId == cat.id).length;

                                return Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: FilterChip(
                                    label: Text('${cat.name} ($count)'),
                                    selected: isSelected,
                                    onSelected: (_) {
                                      setState(() => _selectedCategoryId = cat.id);
                                    },
                                    selectedColor: Colors.amber.withValues(alpha: 0.2),
                                    checkmarkColor: Colors.amber[800],
                                    labelStyle: TextStyle(
                                      color: isSelected
                                          ? Colors.amber[900]
                                          : (isDark ? Colors.grey[300] : Colors.grey[800]),
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    ),
                                    side: BorderSide(
                                      color: isSelected
                                          ? Colors.amber[800]!
                                          : (isDark ? Colors.grey[700]! : Colors.grey[300]!),
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (_, _) => const SizedBox.shrink(),
                  ),

                // Số lượng bài hiển thị
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Text(
                    'Đang hiển thị ${filteredArticles.length} bài viết',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                    ),
                  ),
                ),

                // =============================================================
                // DANH SÁCH CÁC BÀI BÁO ĐÃ LƯU
                // =============================================================
                Expanded(
                  child: filteredArticles.isEmpty
                      ? _buildEmptyState(isDark)
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: filteredArticles.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final article = filteredArticles[index];

                            return Dismissible(
                              key: Key('bookmark_${article.id}'),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 20),
                                decoration: BoxDecoration(
                                  color: Colors.redAccent,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
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
                              onDismissed: (_) => _removeBookmark(article, index),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ArticleDetailView(article: article),
                                    ),
                                  ).then((_) => _loadBookmarks());
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.grey[900] : Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.03),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Ảnh bài viết
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: SizedBox(
                                          width: 90,
                                          height: 80,
                                          child: article.thumbnailUrl.isNotEmpty
                                              ? Image.network(
                                                  article.thumbnailUrl,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (_, _, _) => Container(
                                                    color: Colors.grey[300],
                                                    child: const Icon(
                                                      Icons.newspaper,
                                                      color: Colors.grey,
                                                    ),
                                                  ),
                                                )
                                              : Container(
                                                  color: Colors.amber.shade50,
                                                  child: const Icon(
                                                    Icons.bookmark,
                                                    color: Colors.amber,
                                                  ),
                                                ),
                                        ),
                                      ),

                                      const SizedBox(width: 12),

                                      // Thông tin bài viết
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            // Chuyên mục
                                            categoriesAsync.when(
                                              data: (categories) {
                                                final cat = categories.cast<CategoryModel?>().firstWhere(
                                                      (c) => c?.id == article.categoryId,
                                                      orElse: () => null,
                                                    );
                                                if (cat == null) return const SizedBox.shrink();
                                                return Padding(
                                                  padding: const EdgeInsets.only(bottom: 4),
                                                  child: Text(
                                                    cat.name,
                                                    style: TextStyle(
                                                      color: Colors.amber.shade900,
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 11,
                                                    ),
                                                  ),
                                                );
                                              },
                                              loading: () => const SizedBox.shrink(),
                                              error: (_, _) => const SizedBox.shrink(),
                                            ),

                                            // Tiêu đề
                                            Text(
                                              article.title,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                                height: 1.3,
                                              ),
                                            ),

                                            const SizedBox(height: 6),

                                            // Tác giả & biểu tượng Offline
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    article.author.isNotEmpty ? article.author : 'Ban biên tập',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.grey[600],
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                Row(
                                                  children: [
                                                    Icon(
                                                      Icons.offline_pin,
                                                      size: 14,
                                                      color: Colors.green.shade600,
                                                    ),
                                                    const SizedBox(width: 3),
                                                    Text(
                                                      'Offline',
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        color: Colors.green.shade700,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),

                                      // Nút Bỏ lưu bài viết (Un-bookmark button)
                                      IconButton(
                                        icon: const Icon(
                                          Icons.bookmark_remove_outlined,
                                          size: 22,
                                          color: Colors.redAccent,
                                        ),
                                        tooltip: 'Bỏ lưu bài viết',
                                        onPressed: () => _removeBookmark(article, index),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  // ===========================================================================
  // GIAO DIỆN TRẠNG THÁI TRỐNG
  // ===========================================================================

  Widget _buildRequireLoginState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.bookmark_border, size: 64, color: Colors.amber[800]),
            ),
            const SizedBox(height: 20),
            Text(
              'Yêu cầu đăng nhập',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Vui lòng đăng nhập tài khoản để lưu và xem danh sách bài viết yêu thích của bạn.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[600], height: 1.5),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              icon: const Icon(Icons.login),
              label: const Text('Đăng nhập ngay'),
              onPressed: () {
                Navigator.pushNamed(context, '/login').then((_) => _loadBookmarks());
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.bookmark_border_rounded,
                size: 60,
                color: Colors.amber[800],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _searchQuery.isNotEmpty
                  ? 'Không tìm thấy bài viết phù hợp'
                  : 'Danh sách yêu thích trống',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isNotEmpty
                  ? 'Thử tìm kiếm với từ khóa khác trong các bài đã lưu.'
                  : 'Khi đọc báo, bấm vào biểu tượng Bookmark để lưu bài viết đọc lại offline bất cứ lúc nào.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[600], height: 1.5),
            ),
            const SizedBox(height: 20),
            if (_searchQuery.isNotEmpty)
              OutlinedButton(
                onPressed: () {
                  setState(() {
                    _searchController.clear();
                    _searchQuery = '';
                  });
                },
                child: const Text('Xóa bộ lọc tìm kiếm'),
              ),
          ],
        ),
      ),
    );
  }
}
