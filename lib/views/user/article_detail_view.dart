import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/article_content_parser.dart';
import '../../core/services/interaction_storage_service.dart';
import '../../models/article_model.dart';
import '../../models/category_model.dart';
import '../../providers/article_provider.dart';
import 'widgets/comment_section_widget.dart';

class ArticleDetailView extends ConsumerStatefulWidget {
  final ArticleModel article;

  const ArticleDetailView({
    super.key,
    required this.article,
  });

  @override
  ConsumerState<ArticleDetailView> createState() => _ArticleDetailViewState();
}

class _ArticleDetailViewState extends ConsumerState<ArticleDetailView> {
  final GlobalKey _commentSectionKey = GlobalKey();

  // Trạng thái tương tác
  bool _isLiked = false;
  int _likeCount = 0;
  bool _isBookmarked = false;

  // Cỡ chữ đọc báo (mặc định 16.0, phạm vi từ 13.0 -> 25.0)
  double _fontSize = 16.0;

  @override
  void initState() {
    super.initState();
    _initializeState();
  }

  Future<void> _initializeState() async {
    // 1. Tự động ghi nhận lịch sử đọc báo
    InteractionStorageService.recordArticleRead(widget.article);

    // 2. Tải cỡ chữ đã lưu
    final savedFontSize = await InteractionStorageService.getArticleFontSize();

    // 3. Tải trạng thái Like & Bookmark (Chỉ kích hoạt nếu đã đăng nhập)
    final currentUser = FirebaseAuth.instance.currentUser;
    final isLiked = currentUser != null
        ? await InteractionStorageService.isArticleLiked(widget.article.id)
        : false;
    final isBookmarked = currentUser != null
        ? await InteractionStorageService.isArticleBookmarked(widget.article.id)
        : false;
    final likeCount = await InteractionStorageService.getLikeCount(widget.article.id);

    if (mounted) {
      setState(() {
        _fontSize = savedFontSize;
        _isLiked = isLiked;
        _likeCount = likeCount;
        _isBookmarked = isBookmarked;
      });
    }
  }

  // ===========================================================================
  // XỬ LÝ TƯƠNG TÁC: LIKE, BOOKMARK, SHARE, CỠ CHỮ
  // ===========================================================================

  void _showRequireLoginDialog({required String actionName}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.lock_outline, color: Colors.blue),
            SizedBox(width: 8),
            Text('Yêu cầu đăng nhập', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Text(
          'Vui lòng đăng nhập tài khoản để có thể $actionName.',
          style: const TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Để sau'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.login, size: 18),
            label: const Text('Đăng nhập'),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pushNamed(context, '/login');
            },
          ),
        ],
      ),
    );
  }

  Future<void> _handleToggleLike() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showRequireLoginDialog(actionName: 'thích bài viết');
      return;
    }

    final nextStatus = !_isLiked;
    setState(() {
      _isLiked = nextStatus;
      _likeCount = nextStatus ? _likeCount + 1 : (_likeCount > 0 ? _likeCount - 1 : 0);
    });

    final updatedStatus = await InteractionStorageService.toggleLike(widget.article.id);

    if (mounted && updatedStatus != _isLiked) {
      setState(() {
        _isLiked = updatedStatus;
      });
    }

    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isLiked ? 'Đã thích bài viết ❤️' : 'Đã bỏ thích bài viết'),
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _handleToggleBookmark() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showRequireLoginDialog(actionName: 'lưu bài viết vào danh sách yêu thích');
      return;
    }

    final isSaved = await InteractionStorageService.toggleBookmark(widget.article);

    if (mounted) {
      setState(() {
        _isBookmarked = isSaved;
      });

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                isSaved ? Icons.bookmark : Icons.bookmark_border,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isSaved
                      ? 'Đã lưu bài viết vào mục Yêu thích 📑'
                      : 'Đã xóa bài viết khỏi mục Yêu thích',
                ),
              ),
            ],
          ),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _handleShare() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Chia sẻ bài viết',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  widget.article.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black87),
                ),
                const Divider(height: 24),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.blueAccent,
                    child: Icon(Icons.link, color: Colors.white),
                  ),
                  title: const Text('Sao chép liên kết'),
                  subtitle: const Text('Lưu link bài viết vào bộ nhớ tạm'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await Clipboard.setData(
                      ClipboardData(
                        text: 'https://baomoi24h.vn/article/${widget.article.id}',
                      ),
                    );
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Đã sao chép liên kết bài viết!'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                ),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.green,
                    child: Icon(Icons.copy_all, color: Colors.white),
                  ),
                  title: const Text('Sao chép trích dẫn & Tiêu đề'),
                  subtitle: const Text('Sao chép tóm tắt để gửi tin nhắn'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await Clipboard.setData(
                      ClipboardData(
                        text: '${widget.article.title}\n\n${widget.article.summary}\n\n(Nguồn: Báo Mới 24h)',
                      ),
                    );
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Đã sao chép nội dung tóm tắt!'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Tăng/giảm cỡ chữ nhanh
  void _changeFontSizeDelta(double delta) {
    final nextSize = (_fontSize + delta).clamp(13.0, 25.0);
    setState(() {
      _fontSize = nextSize;
    });
    InteractionStorageService.saveArticleFontSize(nextSize);
  }

  void _showFontSizeSelector() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Cỡ chữ đọc báo',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${_fontSize.toStringAsFixed(1)} pt',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Text('A', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                        Expanded(
                          child: Slider(
                            value: _fontSize,
                            min: 13.0,
                            max: 25.0,
                            divisions: 8,
                            label: '${_fontSize.toStringAsFixed(1)} pt',
                            onChanged: (val) {
                              setModalState(() {});
                              setState(() {
                                _fontSize = val;
                              });
                              InteractionStorageService.saveArticleFontSize(val);
                            },
                          ),
                        ),
                        const Text('A', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        OutlinedButton(
                          onPressed: () {
                            setModalState(() {});
                            setState(() => _fontSize = 14.0);
                            InteractionStorageService.saveArticleFontSize(14.0);
                          },
                          child: const Text('Nhỏ (14)'),
                        ),
                        FilledButton.tonal(
                          onPressed: () {
                            setModalState(() {});
                            setState(() => _fontSize = 16.0);
                            InteractionStorageService.saveArticleFontSize(16.0);
                          },
                          child: const Text('Vừa (16)'),
                        ),
                        OutlinedButton(
                          onPressed: () {
                            setModalState(() {});
                            setState(() => _fontSize = 19.0);
                            InteractionStorageService.saveArticleFontSize(19.0);
                          },
                          child: const Text('Lớn (19)'),
                        ),
                        OutlinedButton(
                          onPressed: () {
                            setModalState(() {});
                            setState(() => _fontSize = 22.0);
                            InteractionStorageService.saveArticleFontSize(22.0);
                          },
                          child: const Text('Rất lớn (22)'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ===========================================================================
  // ĐỊNH DẠNG NGÀY & THỜI GIAN ĐỌC
  // ===========================================================================

  String _formatPublishedDate(int millis) {
    if (millis <= 0) return 'Vừa đăng';
    final dt = DateTime.fromMillisecondsSinceEpoch(millis);
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final year = dt.year.toString();
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$hour:$minute • $day/$month/$year';
  }

  String _estimateReadingTime(String content) {
    final wordCount = content.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).length;
    final minutes = (wordCount / 180).ceil();
    return minutes <= 1 ? '1 phút đọc' : '$minutes phút đọc';
  }

  // ===========================================================================
  // GIAO DIỆN CHÍNH
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final categoriesAsync = ref.watch(categoryListStreamProvider);

    // Chuẩn hóa nội dung Text / HTML / Markdown
    final parsedMarkdownContent = ArticleContentParser.parseToMarkdown(widget.article.content);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFFAF9F6),
      appBar: AppBar(
        title: const Text('Báo Mới 24h'),
        elevation: 0.5,
        actions: [
          // Nút giảm cỡ chữ nhanh A-
          IconButton(
            icon: const Text(
              'A-',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            tooltip: 'Giảm cỡ chữ',
            onPressed: () => _changeFontSizeDelta(-1.5),
          ),
          // Nút tăng cỡ chữ nhanh A+
          IconButton(
            icon: const Text(
              'A+',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            tooltip: 'Tăng cỡ chữ',
            onPressed: () => _changeFontSizeDelta(1.5),
          ),
          // Menu chọn cỡ chữ chi tiết
          IconButton(
            icon: const Icon(Icons.format_size),
            tooltip: 'Tùy chỉnh cỡ chữ',
            onPressed: _showFontSizeSelector,
          ),
          // Nút Bookmark trên thanh AppBar
          IconButton(
            icon: Icon(
              _isBookmarked ? Icons.bookmark : Icons.bookmark_border,
              color: _isBookmarked ? Colors.amber[700] : null,
            ),
            tooltip: _isBookmarked ? 'Bỏ lưu bài viết' : 'Lưu bài viết',
            onPressed: _handleToggleBookmark,
          ),
          // Nút Share
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Chia sẻ bài viết',
            onPressed: _handleShare,
          ),
        ],
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 90),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Ảnh bìa bài viết
            if (widget.article.thumbnailUrl.isNotEmpty)
              ClipRRect(
                child: Image.network(
                  widget.article.thumbnailUrl,
                  width: double.infinity,
                  height: 260,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 200,
                      color: Colors.grey[300],
                      child: const Center(
                        child: Icon(Icons.broken_image, size: 50, color: Colors.grey),
                      ),
                    );
                  },
                ),
              ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Nhãn Chuyên mục & Thời gian đọc
                  Row(
                    children: [
                      categoriesAsync.when(
                        data: (categories) {
                          final category = categories.cast<CategoryModel?>().firstWhere(
                                (c) => c?.id == widget.article.categoryId,
                                orElse: () => null,
                              );
                          final catName = category?.name ?? 'Thời sự';

                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.blue.shade900 : Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              catName,
                              style: TextStyle(
                                color: isDark ? Colors.blue.shade200 : Colors.blue.shade700,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          );
                        },
                        loading: () => const SizedBox.shrink(),
                        error: (_, _) => const SizedBox.shrink(),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '•  ${_estimateReadingTime(widget.article.content)}',
                        style: TextStyle(
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // 1. TIÊU ĐỀ BÀI VIẾT
                  Text(
                    widget.article.title,
                    style: TextStyle(
                      fontSize: _fontSize + 8,
                      fontWeight: FontWeight.bold,
                      height: 1.35,
                      letterSpacing: -0.3,
                    ),
                  ),

                  const SizedBox(height: 14),

                  // 2. TÁC GIẢ & NGÀY ĐĂNG
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: Colors.blue.shade100,
                        child: const Icon(Icons.person, color: Colors.blue, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.article.author.isNotEmpty ? widget.article.author : 'Ban biên tập',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(Icons.access_time, size: 12, color: Colors.grey[600]),
                              const SizedBox(width: 4),
                              Text(
                                _formatPublishedDate(widget.article.publishedAt),
                                style: TextStyle(color: Colors.grey[600], fontSize: 12),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // ĐOẠN TÓM TẮT / SAPO
                  if (widget.article.summary.isNotEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[900] : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                        border: Border(
                          left: BorderSide(
                            color: Colors.blue.shade600,
                            width: 4,
                          ),
                        ),
                      ),
                      child: Text(
                        widget.article.summary,
                        style: TextStyle(
                          fontSize: _fontSize + 1,
                          fontWeight: FontWeight.w600,
                          height: 1.6,
                          color: isDark ? Colors.grey[200] : const Color(0xFF334155),
                        ),
                      ),
                    ),

                  const SizedBox(height: 22),
                  const Divider(height: 1),
                  const SizedBox(height: 20),

                  // 3. NỘI DUNG CHI TIẾT (Text / HTML / Ảnh qua MarkdownBody)
                  MarkdownBody(
                    data: parsedMarkdownContent,
                    selectable: true,
                    styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
                      p: TextStyle(
                        fontSize: _fontSize,
                        height: 1.8,
                        letterSpacing: 0.15,
                        color: isDark ? Colors.grey[200] : const Color(0xFF1E293B),
                      ),
                      h1: TextStyle(
                        fontSize: _fontSize + 6,
                        fontWeight: FontWeight.bold,
                        height: 1.4,
                      ),
                      h2: TextStyle(
                        fontSize: _fontSize + 4,
                        fontWeight: FontWeight.bold,
                        height: 1.4,
                      ),
                      h3: TextStyle(
                        fontSize: _fontSize + 2,
                        fontWeight: FontWeight.bold,
                        height: 1.4,
                      ),
                      strong: const TextStyle(fontWeight: FontWeight.bold),
                      em: const TextStyle(fontStyle: FontStyle.italic),
                      blockquote: TextStyle(
                        fontSize: _fontSize,
                        fontStyle: FontStyle.italic,
                        color: Colors.grey[600],
                      ),
                      blockquoteDecoration: BoxDecoration(
                        color: isDark ? Colors.grey[850] : Colors.grey[100],
                        borderRadius: BorderRadius.circular(4),
                        border: Border(
                          left: BorderSide(color: Colors.blue.shade400, width: 4),
                        ),
                      ),
                    ),
                    sizedImageBuilder: (config) {
                      final url = config.uri.toString();
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Column(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.network(
                                url,
                                width: config.width ?? double.infinity,
                                height: config.height,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    height: 160,
                                    color: Colors.grey[300],
                                    alignment: Alignment.center,
                                    child: const Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.broken_image, color: Colors.grey, size: 40),
                                        SizedBox(height: 4),
                                        Text(
                                          'Không thể tải hình ảnh bài viết',
                                          style: TextStyle(color: Colors.grey, fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                            if (config.alt != null && config.alt!.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                config.alt!,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: _fontSize - 2,
                                  fontStyle: FontStyle.italic,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 28),
                  const Divider(thickness: 1),
                  const SizedBox(height: 20),

                  // 4. PHẦN BÌNH LUẬN THỜI GIAN THỰC (REALTIME COMMENTS)
                  CommentSectionWidget(
                    key: _commentSectionKey,
                    articleId: widget.article.id,
                  ),

                  const SizedBox(height: 36),
                ],
              ),
            ),
          ],
        ),
      ),

      // =======================================================================
      // THANH CÔNG CỤ LIKE / BOOKMARK / SHARE / CỠ CHỮ CỐ ĐỊNH Ở ĐÁY MÀN HÌNH
      // =======================================================================
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: SafeArea(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // Nút Thích (Like)
              InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: _handleToggleLike,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Row(
                    children: [
                      Icon(
                        _isLiked ? Icons.favorite : Icons.favorite_border,
                        color: _isLiked ? Colors.red : Colors.grey[700],
                        size: 24,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _likeCount > 0 ? '$_likeCount' : 'Thích',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: _isLiked ? Colors.red : Colors.grey[800],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Nút Bookmark (Lưu bài viết)
              InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: _handleToggleBookmark,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Row(
                    children: [
                      Icon(
                        _isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                        color: _isBookmarked ? Colors.amber[800] : Colors.grey[700],
                        size: 24,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _isBookmarked ? 'Đã lưu' : 'Lưu tin',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: _isBookmarked ? Colors.amber[800] : Colors.grey[800],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Nút Bình luận (Comments)
              InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () {
                  if (_commentSectionKey.currentContext != null) {
                    Scrollable.ensureVisible(
                      _commentSectionKey.currentContext!,
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeInOut,
                    );
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: Row(
                    children: [
                      Icon(Icons.chat_bubble_outline, color: Colors.grey[700], size: 22),
                      const SizedBox(width: 4),
                      Text(
                        'Bình luận',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[800],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Nút Cỡ chữ nhanh
              InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: _showFontSizeSelector,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Row(
                    children: [
                      Icon(Icons.text_fields, color: Colors.grey[700], size: 24),
                      const SizedBox(width: 4),
                      Text(
                        '${_fontSize.toInt()}pt',
                        style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey[800]),
                      ),
                    ],
                  ),
                ),
              ),

              // Nút Chia sẻ (Share)
              IconButton(
                icon: const Icon(Icons.share_outlined),
                tooltip: 'Chia sẻ',
                onPressed: _handleShare,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
