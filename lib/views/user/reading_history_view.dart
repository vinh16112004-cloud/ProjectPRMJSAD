import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/interaction_storage_service.dart';
import '../../models/article_model.dart';
import '../../models/category_model.dart';
import '../../providers/article_provider.dart';
import 'article_detail_view.dart';

class ReadingHistoryView extends ConsumerStatefulWidget {
  const ReadingHistoryView({super.key});

  @override
  ConsumerState<ReadingHistoryView> createState() => _ReadingHistoryViewState();
}

class _ReadingHistoryViewState extends ConsumerState<ReadingHistoryView> {
  List<Map<String, dynamic>> _historyItems = [];
  bool _isLoading = true;

  // Bộ lọc thời gian: 'Tất cả', 'Hôm nay', 'Hôm qua', '7 ngày qua', 'Cũ hơn'
  String _selectedFilter = 'Tất cả';
  final List<String> _filters = const [
    'Tất cả',
    'Hôm nay',
    'Hôm qua',
    '7 ngày qua',
    'Cũ hơn',
  ];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    final items = await InteractionStorageService.getReadingHistory();
    if (mounted) {
      setState(() {
        _historyItems = items;
        _isLoading = false;
      });
    }
  }

  // ===========================================================================
  // XÓA TỪNG MỤC & XÓA TOÀN BỘ LỊCH SỬ
  // ===========================================================================

  Future<void> _deleteSingleItem(String articleId) async {
    await InteractionStorageService.removeReadingHistoryItem(articleId);
    setState(() {
      _historyItems.removeWhere((item) => item['article_id'] == articleId);
    });

    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã xóa bài viết khỏi lịch sử đọc'),
          duration: Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _clearAllHistory() async {
    if (_historyItems.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa toàn bộ lịch sử?'),
        content: const Text(
          'Hành động này sẽ xóa toàn bộ danh sách các bài báo bạn đã đọc gần đây và không thể hoàn tác.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xóa tất cả'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await InteractionStorageService.clearReadingHistory();
      setState(() {
        _historyItems.clear();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã xóa sạch lịch sử đọc báo'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // ===========================================================================
  // LOGIC LỌC THEO THỜI GIAN
  // ===========================================================================

  bool _matchesFilter(int readAt, String filter) {
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    final startOfYesterday = DateTime(now.year, now.month, now.day - 1).millisecondsSinceEpoch;
    final sevenDaysAgo = DateTime(now.year, now.month, now.day - 7).millisecondsSinceEpoch;

    switch (filter) {
      case 'Hôm nay':
        return readAt >= startOfToday;
      case 'Hôm qua':
        return readAt >= startOfYesterday && readAt < startOfToday;
      case '7 ngày qua':
        return readAt >= sevenDaysAgo;
      case 'Cũ hơn':
        return readAt < sevenDaysAgo;
      case 'Tất cả':
      default:
        return true;
    }
  }

  String _formatReadTime(int timestamp) {
    final dt = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final startOfYesterday = DateTime(now.year, now.month, now.day - 1);

    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');

    if (dt.isAfter(startOfToday)) {
      return 'Hôm nay lúc $hour:$minute';
    } else if (dt.isAfter(startOfYesterday)) {
      return 'Hôm qua lúc $hour:$minute';
    } else {
      final day = dt.day.toString().padLeft(2, '0');
      final month = dt.month.toString().padLeft(2, '0');
      return '$hour:$minute • $day/$month/${dt.year}';
    }
  }

  // ===========================================================================
  // MỞ CHI TIẾT BÀI BÁO
  // ===========================================================================

  void _openArticleDetail(Map<String, dynamic> item) {
    final article = ArticleModel(
      id: item['article_id']?.toString() ?? '',
      title: item['title']?.toString() ?? '',
      summary: item['summary']?.toString() ?? '',
      content: item['content']?.toString() ?? item['summary']?.toString() ?? '',
      categoryId: item['category_id']?.toString() ?? '',
      thumbnailUrl: item['thumbnail_url']?.toString() ?? '',
      author: item['author']?.toString() ?? '',
      status: item['status'] is int ? item['status'] : 1,
      isHot: item['is_hot'] == true,
      publishedAt: item['published_at'] is int ? item['published_at'] : 0,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ArticleDetailView(article: article),
      ),
    ).then((_) {
      // Làm mới danh sách khi quay lại
      _loadHistory();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final categoriesAsync = ref.watch(categoryListStreamProvider);

    // Lọc danh sách theo thời gian đã chọn
    final filteredItems = _historyItems.where((item) {
      final readAt = item['read_at'] is int ? item['read_at'] as int : 0;
      return _matchesFilter(readAt, _selectedFilter);
    }).toList();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Lịch sử đọc báo'),
        actions: [
          if (_historyItems.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: 'Xóa toàn bộ lịch sử',
              onPressed: _clearAllHistory,
            ),
        ],
      ),

      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // =============================================================
                // THANH BỘ LỌC THỜI GIAN ĐỌC (FILTER CHIPS)
                // =============================================================
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
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
                      children: _filters.map((filter) {
                        final isSelected = _selectedFilter == filter;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(filter),
                            selected: isSelected,
                            onSelected: (_) {
                              setState(() {
                                _selectedFilter = filter;
                              });
                            },
                            selectedColor: Colors.blue.withValues(alpha: 0.15),
                            checkmarkColor: Colors.blue,
                            labelStyle: TextStyle(
                              color: isSelected
                                  ? Colors.blue
                                  : (isDark ? Colors.grey[300] : Colors.grey[800]),
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                            side: BorderSide(
                              color: isSelected
                                  ? Colors.blue
                                  : (isDark ? Colors.grey[700]! : Colors.grey[300]!),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),

                // Thông tin số lượng bài
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Text(
                    'Đã tìm thấy ${filteredItems.length} bài viết',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                    ),
                  ),
                ),

                // =============================================================
                // DANH SÁCH BÀI BÁO ĐÃ ĐỌC
                // =============================================================
                Expanded(
                  child: filteredItems.isEmpty
                      ? _buildEmptyState(isDark)
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: filteredItems.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final item = filteredItems[index];
                            final articleId = item['article_id']?.toString() ?? '';
                            final readAt = item['read_at'] is int ? item['read_at'] as int : 0;
                            final thumbUrl = item['thumbnail_url']?.toString() ?? '';
                            final categoryId = item['category_id']?.toString() ?? '';

                            return Dismissible(
                              key: Key('history_$articleId'),
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
                                    Icon(Icons.delete, color: Colors.white),
                                    SizedBox(width: 6),
                                    Text(
                                      'Xóa',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              onDismissed: (_) => _deleteSingleItem(articleId),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () => _openArticleDetail(item),
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
                                          child: thumbUrl.isNotEmpty
                                              ? Image.network(
                                                  thumbUrl,
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
                                                  color: Colors.blue.shade50,
                                                  child: const Icon(
                                                    Icons.newspaper,
                                                    color: Colors.blue,
                                                  ),
                                                ),
                                        ),
                                      ),

                                      const SizedBox(width: 12),

                                      // Nội dung bài viết
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            // Tên chuyên mục nếu có
                                            categoriesAsync.when(
                                              data: (categories) {
                                                final cat = categories.cast<CategoryModel?>().firstWhere(
                                                      (c) => c?.id == categoryId,
                                                      orElse: () => null,
                                                    );
                                                if (cat == null) return const SizedBox.shrink();
                                                return Padding(
                                                  padding: const EdgeInsets.only(bottom: 4),
                                                  child: Text(
                                                    cat.name,
                                                    style: TextStyle(
                                                      color: Colors.blue.shade600,
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 11,
                                                    ),
                                                  ),
                                                );
                                              },
                                              loading: () => const SizedBox.shrink(),
                                              error: (_, _) => const SizedBox.shrink(),
                                            ),

                                            // Tiêu đề bài viết
                                            Text(
                                              item['title']?.toString() ?? 'Không có tiêu đề',
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                                height: 1.3,
                                              ),
                                            ),

                                            const SizedBox(height: 8),

                                            // Thời gian đọc
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.history_toggle_off,
                                                  size: 13,
                                                  color: Colors.grey[500],
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  _formatReadTime(readAt),
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey[500],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),

                                      // Nút xóa từng bài
                                      IconButton(
                                        icon: const Icon(Icons.close, size: 18, color: Colors.grey),
                                        tooltip: 'Xóa bài này',
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        onPressed: () => _deleteSingleItem(articleId),
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
  // GIAO DIỆN KHI LỊCH SỬ TRỐNG
  // ===========================================================================

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
                color: Colors.blue.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.history,
                size: 60,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Chưa có lịch sử đọc bài',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _selectedFilter == 'Tất cả'
                  ? 'Các bài báo bạn đã xem sẽ tự động lưu vào đây để bạn tiện xem lại bất cứ lúc nào.'
                  : 'Không có bài báo nào được đọc trong khoảng thời gian "$_selectedFilter".',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[600], height: 1.5),
            ),
            if (_selectedFilter != 'Tất cả') ...[
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () => setState(() => _selectedFilter = 'Tất cả'),
                child: const Text('Xem tất cả lịch sử'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
