import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../core/services/article_interaction_service.dart';
import '../../models/article_model.dart';
import 'widgets/article_comments_section.dart';

class ArticleDetailView extends StatefulWidget {
  final ArticleModel article;

  const ArticleDetailView({
    super.key,
    required this.article,
  });

  @override
  State<ArticleDetailView> createState() => _ArticleDetailViewState();
}

class _ArticleDetailViewState extends State<ArticleDetailView> {
  double _fontSize = 16.0;
  bool _isBookmarked = false;
  bool _isLiked = false;

  @override
  void initState() {
    super.initState();
    _initInteractions();
    // Tự động ghi nhận lịch sử đọc báo
    ArticleInteractionService.recordReadingHistory(widget.article);
  }

  Future<void> _initInteractions() async {
    final savedFontSize = await ArticleInteractionService.getFontSize();
    final bookmarked = await ArticleInteractionService.isBookmarked(widget.article.id);
    final liked = await ArticleInteractionService.isLiked(widget.article.id);

    if (mounted) {
      setState(() {
        _fontSize = savedFontSize;
        _isBookmarked = bookmarked;
        _isLiked = liked;
      });
    }
  }

  // ==========================================
  // 1. TĂNG / GIẢM CỠ CHỮ NHANH
  // ==========================================
  void _decreaseFontSize() {
    if (_fontSize > 13.0) {
      setState(() => _fontSize -= 1.5);
      ArticleInteractionService.saveFontSize(_fontSize);
      _showFontSizeFeedback();
    }
  }

  void _increaseFontSize() {
    if (_fontSize < 26.0) {
      setState(() => _fontSize += 1.5);
      ArticleInteractionService.saveFontSize(_fontSize);
      _showFontSizeFeedback();
    }
  }

  void _showFontSizeFeedback() {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Cỡ chữ hiện tại: ${_fontSize.toStringAsFixed(1)} pt'),
        duration: const Duration(milliseconds: 700),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showFontSizeDialog() {
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
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Tùy chỉnh cỡ chữ đọc báo',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(ctx),
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
                            max: 26.0,
                            divisions: 10,
                            label: '${_fontSize.toStringAsFixed(1)} pt',
                            onChanged: (val) {
                              setModalState(() => _fontSize = val);
                              setState(() => _fontSize = val);
                              ArticleInteractionService.saveFontSize(val);
                            },
                          ),
                        ),
                        const Text('A', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    Center(
                      child: Text(
                        'Độ lớn hiện tại: ${_fontSize.toStringAsFixed(1)} pt',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
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

  // ==========================================
  // 2. XỬ LÝ LIKE, BOOKMARK, SHARE
  // ==========================================
  Future<void> _handleToggleLike() async {
    final newStatus = await ArticleInteractionService.toggleLike(widget.article.id);
    if (mounted) {
      setState(() => _isLiked = newStatus);
    }
  }

  Future<void> _handleToggleBookmark() async {
    final newStatus = await ArticleInteractionService.toggleBookmark(widget.article);
    if (mounted) {
      setState(() => _isBookmarked = newStatus);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newStatus
                ? 'Đã lưu bài viết vào danh sách yêu thích'
                : 'Đã xóa bài viết khỏi danh mục yêu thích',
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
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Text(
                  'Chia sẻ bài báo',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.article.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[700], fontSize: 13),
                ),
                const SizedBox(height: 20),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.blueAccent,
                    child: Icon(Icons.copy, color: Colors.white, size: 20),
                  ),
                  title: const Text('Sao chép liên kết bài báo'),
                  subtitle: const Text('Lưu link vào bộ nhớ tạm'),
                  onTap: () {
                    Clipboard.setData(ClipboardData(
                      text: 'https://baomoi24h.vn/article/${widget.article.id}',
                    ));
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Đã sao chép liên kết bài viết!'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.deepOrangeAccent,
                    child: Icon(Icons.text_snippet, color: Colors.white, size: 20),
                  ),
                  title: const Text('Sao chép trích dẫn tóm tắt'),
                  subtitle: const Text('Sao chép tiêu đề và tóm tắt'),
                  onTap: () {
                    Clipboard.setData(ClipboardData(
                      text: '${widget.article.title}\n\n${widget.article.summary}',
                    ));
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Đã sao chép nội dung tóm tắt!'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ==========================================
  // ĐỊNH DẠNG NGÀY GIỜ ĐĂNG
  // ==========================================
  String _formatPublishDate(int timestamp) {
    if (timestamp <= 0) return 'Vừa đăng';
    final dt = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final year = dt.year;
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$day/$month/$year lúc $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Text(
          'Chi tiết bài viết',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        elevation: 0.5,
        actions: [
          // Nút giảm cỡ chữ
          IconButton(
            tooltip: 'Giảm cỡ chữ (A-)',
            icon: const Text('A-', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            onPressed: _decreaseFontSize,
          ),
          // Nút tăng cỡ chữ
          IconButton(
            tooltip: 'Tăng cỡ chữ (A+)',
            icon: const Text('A+', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            onPressed: _increaseFontSize,
          ),
          // Nút mở tùy chỉnh cỡ chữ chi tiết
          IconButton(
            tooltip: 'Tùy chỉnh cỡ chữ',
            icon: const Icon(Icons.format_size),
            onPressed: _showFontSizeDialog,
          ),
          // Bookmark nhanh trên AppBar
          IconButton(
            tooltip: _isBookmarked ? 'Bỏ lưu bài viết' : 'Lưu bài viết',
            icon: Icon(
              _isBookmarked ? Icons.bookmark : Icons.bookmark_border,
              color: _isBookmarked ? Colors.amber[800] : null,
            ),
            onPressed: _handleToggleBookmark,
          ),
        ],
      ),

      // ==========================================
      // THANH CÔNG CỤ LIKE / BOOKMARK / SHARE (BOTTOM BAR)
      // ==========================================
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          boxShadow: const [
            BoxShadow(
              color: Color(0x0F000000),
              blurRadius: 10,
              offset: Offset(0, -3),
            ),
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
              // Nút Like
              StreamBuilder<int>(
                stream: ArticleInteractionService.getLikeCountStream(widget.article.id),
                builder: (context, snapshot) {
                  final likeCount = snapshot.data ?? 0;
                  return InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: _handleToggleLike,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Row(
                        children: [
                          Icon(
                            _isLiked ? Icons.favorite : Icons.favorite_border,
                            color: _isLiked ? Colors.redAccent : Colors.grey[700],
                            size: 24,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            likeCount > 0 ? '$likeCount' : 'Thích',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: _isLiked ? Colors.redAccent : Colors.grey[800],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(width: 8),

              // Nút Bookmark
              InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: _handleToggleBookmark,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      Icon(
                        _isBookmarked ? Icons.bookmark : Icons.bookmark_outline,
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

              const Spacer(),

              // Nút Chia sẻ (Share)
              FilledButton.tonalIcon(
                onPressed: _handleShare,
                icon: const Icon(Icons.share_outlined, size: 18),
                label: const Text('Chia sẻ'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
              ),
            ],
          ),
        ),
      ),

      // ==========================================
      // THÂN BÀI VIẾT (CHI TIẾT)
      // ==========================================
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Ảnh Thumbnail chính của bài báo
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
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tiêu đề bài viết
                  Text(
                    widget.article.title,
                    style: TextStyle(
                      fontSize: _fontSize + 8.0,
                      fontWeight: FontWeight.bold,
                      height: 1.35,
                      letterSpacing: -0.3,
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Metadata: Tác giả, Ngày đăng, Thời gian đọc
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: Colors.blue.shade100,
                        child: Text(
                          widget.article.author.isNotEmpty
                              ? widget.article.author[0].toUpperCase()
                              : 'T',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade800,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.article.author.isNotEmpty
                                  ? widget.article.author
                                  : 'Ban Biên Tập',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Icon(Icons.access_time, size: 13, color: Colors.grey[600]),
                                const SizedBox(width: 4),
                                Text(
                                  _formatPublishDate(widget.article.publishedAt),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // Tóm tắt bài viết (Summary Box)
                  if (widget.article.summary.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[900] : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                        border: Border(
                          left: BorderSide(
                            color: theme.colorScheme.primary,
                            width: 4,
                          ),
                        ),
                      ),
                      child: Text(
                        widget.article.summary,
                        style: TextStyle(
                          fontSize: _fontSize + 1.0,
                          fontWeight: FontWeight.w600,
                          fontStyle: FontStyle.italic,
                          height: 1.6,
                          color: isDark ? Colors.grey[300] : Colors.grey[800],
                        ),
                      ),
                    ),

                  const Divider(height: 36, thickness: 1),

                  // Nội dung chi tiết (Rich Markdown/HTML/Text Body)
                  MarkdownBody(
                    data: widget.article.content,
                    selectable: true,
                    styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
                      p: TextStyle(
                        fontSize: _fontSize,
                        height: 1.8,
                        letterSpacing: 0.1,
                        color: isDark ? Colors.grey[200] : const Color(0xFF2C3E50),
                      ),
                      h1: TextStyle(
                        fontSize: _fontSize + 6.0,
                        fontWeight: FontWeight.bold,
                        height: 1.4,
                      ),
                      h2: TextStyle(
                        fontSize: _fontSize + 4.0,
                        fontWeight: FontWeight.bold,
                        height: 1.4,
                      ),
                      h3: TextStyle(
                        fontSize: _fontSize + 2.0,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                      blockquote: TextStyle(
                        fontSize: _fontSize,
                        fontStyle: FontStyle.italic,
                        color: isDark ? Colors.grey[400] : Colors.grey[700],
                      ),
                      listBullet: TextStyle(fontSize: _fontSize),
                    ),
                    sizedImageBuilder: (config) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            config.uri.toString(),
                            width: config.width,
                            height: config.height,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(
                              height: 160,
                              color: Colors.grey[300],
                              child: const Center(
                                child: Icon(Icons.broken_image, size: 40, color: Colors.grey),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 24),

                  const Divider(height: 36, thickness: 1),

                  // Khu vực Bình luận thời gian thực & Tương tác
                  ArticleCommentsSection(articleId: widget.article.id),

                  const SizedBox(height: 36),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
