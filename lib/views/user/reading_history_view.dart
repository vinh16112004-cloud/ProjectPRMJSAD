import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../core/services/article_interaction_service.dart';
import '../../models/article_model.dart';
import '../../models/reading_history_model.dart';
import 'article_detail_view.dart';

enum HistoryTimeFilter {
  all('Tất cả'),
  today('Hôm nay'),
  yesterday('Hôm qua'),
  week('7 ngày qua'),
  older('Cũ hơn');

  final String label;
  const HistoryTimeFilter(this.label);
}

class ReadingHistoryView extends StatefulWidget {
  const ReadingHistoryView({super.key});

  @override
  State<ReadingHistoryView> createState() => _ReadingHistoryViewState();
}

class _ReadingHistoryViewState extends State<ReadingHistoryView> {
  List<ReadingHistoryModel> _historyList = [];
  bool _isLoading = true;
  HistoryTimeFilter _selectedFilter = HistoryTimeFilter.all;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    final list = await ArticleInteractionService.getReadingHistory();
    if (mounted) {
      setState(() {
        _historyList = list;
        _isLoading = false;
      });
    }
  }

  // ==========================================
  // BỘ LỌC THEO MỐC THỜI GIAN
  // ==========================================
  List<ReadingHistoryModel> get _filteredHistoryList {
    if (_selectedFilter == HistoryTimeFilter.all) {
      return _historyList;
    }

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final yesterdayStart = todayStart.subtract(const Duration(days: 1));
    final weekStart = todayStart.subtract(const Duration(days: 7));

    return _historyList.where((item) {
      final date = DateTime.fromMillisecondsSinceEpoch(item.readAt);

      switch (_selectedFilter) {
        case HistoryTimeFilter.today:
          return date.isAfter(todayStart) || date.isAtSameMomentAs(todayStart);

        case HistoryTimeFilter.yesterday:
          return (date.isAfter(yesterdayStart) || date.isAtSameMomentAs(yesterdayStart)) &&
              date.isBefore(todayStart);

        case HistoryTimeFilter.week:
          return (date.isAfter(weekStart) || date.isAtSameMomentAs(weekStart)) &&
              date.isBefore(yesterdayStart);

        case HistoryTimeFilter.older:
          return date.isBefore(weekStart);

        case HistoryTimeFilter.all:
          return true;
      }
    }).toList();
  }

  // ==========================================
  // XÓA TỪNG BÀI VIẾT
  // ==========================================
  Future<void> _deleteItem(ReadingHistoryModel item) async {
    final articleId = item.articleId;
    setState(() {
      _historyList.removeWhere((h) => h.articleId == articleId);
    });

    await ArticleInteractionService.deleteHistoryItem(articleId);

    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã xóa "${item.title.isNotEmpty ? item.title : 'bài viết'}" khỏi lịch sử'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ==========================================
  // XÓA TẤT CẢ LỊCH SỬ
  // ==========================================
  Future<void> _confirmClearAll() async {
    if (_historyList.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa toàn bộ lịch sử?'),
        content: const Text(
          'Hành động này sẽ xóa toàn bộ danh sách các bài báo bạn đã đọc trên thiết bị và tài khoản.',
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
      setState(() {
        _historyList.clear();
      });
      await ArticleInteractionService.clearAllHistory();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã xóa sạch toàn bộ lịch sử đọc báo'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // ==========================================
  // ĐIỀU HƯỚNG MỞ CHI TIẾT BÀI BÁO
  // ==========================================
  Future<void> _openArticle(ReadingHistoryModel item) async {
    // 1. Thử lấy bài viết mới nhất từ Firestore nếu có mạng
    try {
      final doc = await FirebaseFirestore.instance
          .collection('articles')
          .doc(item.articleId)
          .get();
      if (doc.exists && mounted) {
        final article = ArticleModel.fromMap(doc.data()!, doc.id);
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ArticleDetailView(article: article)),
        ).then((_) => _loadHistory());
        return;
      }
    } catch (_) {}

    // 2. Nếu offline hoặc doc không tồn tại, mở từ cache lịch sử
    if (!mounted) return;
    final cachedArticle = ArticleModel(
      id: item.articleId,
      title: item.title,
      summary: item.summary,
      content: item.content.isNotEmpty ? item.content : item.summary,
      categoryId: item.categoryId,
      thumbnailUrl: item.thumbnailUrl,
      author: item.author,
      status: 1,
      isHot: false,
      publishedAt: item.readAt,
    );

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ArticleDetailView(article: cachedArticle)),
    ).then((_) => _loadHistory());
  }

  // ==========================================
  // FORMAT THỜI GIAN ĐỌC BÀI
  // ==========================================
  String _formatTimeAgo(int timestamp) {
    final now = DateTime.now();
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final diff = now.difference(date);

    if (diff.inMinutes < 1) return 'Vừa xong';
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
    if (diff.inHours < 24 && now.day == date.day) {
      final hour = date.hour.toString().padLeft(2, '0');
      final minute = date.minute.toString().padLeft(2, '0');
      return 'Hôm nay lúc $hour:$minute';
    }

    final yesterday = now.subtract(const Duration(days: 1));
    if (yesterday.year == date.year &&
        yesterday.month == date.month &&
        yesterday.day == date.day) {
      final hour = date.hour.toString().padLeft(2, '0');
      final minute = date.minute.toString().padLeft(2, '0');
      return 'Hôm qua lúc $hour:$minute';
    }

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year;
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$day/$month/$year lúc $hour:$minute';
  }

  bool get _isLoggedIn => ArticleInteractionService.isUserLoggedIn;

  @override
  Widget build(BuildContext context) {
    if (!_isLoggedIn) {
      return Scaffold(
        appBar: AppBar(title: const Text('Lịch sử đọc báo')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_person_outlined, size: 72, color: Colors.blueGrey[400]),
                const SizedBox(height: 16),
                const Text(
                  'Yêu cầu đăng nhập',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tính năng Lịch sử đọc báo chỉ dành cho tài khoản đã đăng nhập để đồng bộ và bảo mật dữ liệu.',
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
    final filteredList = _filteredHistoryList;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lịch sử đọc báo'),
        actions: [
          if (_historyList.isNotEmpty)
            IconButton(
              tooltip: 'Xóa toàn bộ lịch sử',
              icon: const Icon(Icons.delete_sweep_outlined, color: Colors.redAccent),
              onPressed: _confirmClearAll,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadHistory,
              child: Column(
                children: [
                  // ==========================================
                  // THANH CHỌN BỘ LỌC THỜI GIAN
                  // ==========================================
                  Container(
                    height: 52,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      scrollDirection: Axis.horizontal,
                      itemCount: HistoryTimeFilter.values.length,
                      separatorBuilder: (context, index) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final filter = HistoryTimeFilter.values[index];
                        final isSelected = _selectedFilter == filter;

                        return ChoiceChip(
                          label: Text(filter.label),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() => _selectedFilter = filter);
                            }
                          },
                        );
                      },
                    ),
                  ),

                  const Divider(height: 1),

                  // ==========================================
                  // DANH SÁCH BÀI BÁO ĐÃ ĐỌC
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
                              final item = filteredList[index];

                              return Dismissible(
                                key: Key('history_${item.articleId}'),
                                direction: DismissDirection.endToStart,
                                background: Container(
                                  color: Colors.redAccent,
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.only(right: 24),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.delete_outline, color: Colors.white),
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
                                onDismissed: (_) => _deleteItem(item),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  onTap: () => _openArticle(item),
                                  // Ảnh đại diện bài viết
                                  leading: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      width: 72,
                                      height: 72,
                                      color: Colors.grey[200],
                                      child: item.thumbnailUrl.isNotEmpty
                                          ? Image.network(
                                              item.thumbnailUrl,
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error, stackTrace) => const Icon(
                                                Icons.article_outlined,
                                                color: Colors.grey,
                                              ),
                                            )
                                          : const Icon(
                                              Icons.article_outlined,
                                              color: Colors.grey,
                                            ),
                                    ),
                                  ),
                                  // Tiêu đề & tác giả
                                  title: Text(
                                    item.title.isNotEmpty ? item.title : 'Bài viết không có tiêu đề',
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
                                        if (item.author.isNotEmpty) ...[
                                          Flexible(
                                            child: Text(
                                              item.author,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: theme.colorScheme.primary,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                          const Text(' • ', style: TextStyle(color: Colors.grey)),
                                        ],
                                        Icon(
                                          Icons.access_time,
                                          size: 13,
                                          color: Colors.grey[600],
                                        ),
                                        const SizedBox(width: 3),
                                        Text(
                                          _formatTimeAgo(item.readAt),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Nút xóa từng bài
                                  trailing: IconButton(
                                    tooltip: 'Xóa khỏi lịch sử',
                                    icon: const Icon(
                                      Icons.close,
                                      size: 20,
                                      color: Colors.grey,
                                    ),
                                    onPressed: () => _deleteItem(item),
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
    final isFiltered = _selectedFilter != HistoryTimeFilter.all;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isFiltered ? Icons.filter_list_off : Icons.history_toggle_off,
              size: 72,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              isFiltered
                  ? 'Không có bài báo nào trong mục "${_selectedFilter.label}"'
                  : 'Bạn chưa có lịch sử đọc báo nào',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isFiltered
                  ? 'Hãy thử chọn mốc thời gian khác để xem bài đã đọc.'
                  : 'Các bài viết bạn đã mở đọc sẽ tự động hiển thị tại đây.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey[500]),
            ),
            if (isFiltered) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => setState(() => _selectedFilter = HistoryTimeFilter.all),
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Xem tất cả'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
