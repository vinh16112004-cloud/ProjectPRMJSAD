import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../core/services/comment_service.dart';
import '../../../models/comment_model.dart';

class ArticleCommentsSection extends StatefulWidget {
  final String articleId;

  const ArticleCommentsSection({
    super.key,
    required this.articleId,
  });

  @override
  State<ArticleCommentsSection> createState() => _ArticleCommentsSectionState();
}

class _ArticleCommentsSectionState extends State<ArticleCommentsSection> {
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  CommentModel? _replyingToComment;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  User? get _currentUser {
    try {
      return FirebaseAuth.instance.currentUser;
    } catch (_) {
      return null;
    }
  }

  bool get _isLoggedIn {
    try {
      return FirebaseAuth.instance.currentUser != null ||
          CommentService.debugUserId != null;
    } catch (_) {
      return CommentService.debugUserId != null;
    }
  }

  String get _currentUserId {
    return _currentUser?.uid ?? CommentService.debugUserId ?? '';
  }

  // ==========================================
  // XỬ LÝ GỬI BÌNH LUẬN HOẶC TRẢ LỜI
  // ==========================================
  Future<void> _handleSubmit() async {
    if (!_isLoggedIn) {
      _showLoginRequiredDialog();
      return;
    }

    final content = _commentController.text.trim();
    if (content.isEmpty) return;

    setState(() => _isSubmitting = true);

    try {
      // Nếu đang trả lời một comment, comment con sẽ nhận parentId = comment cha
      // (nếu comment cha vốn là reply thì lấy chính parentId của nó để không bị lồng quá sâu)
      String? targetParentId;
      String? replyToName;

      if (_replyingToComment != null) {
        targetParentId = _replyingToComment!.parentId ?? _replyingToComment!.id;
        replyToName = _replyingToComment!.userName;
      }

      await CommentService.addComment(
        articleId: widget.articleId,
        content: content,
        parentId: targetParentId,
        replyToUserName: replyToName,
      );

      _commentController.clear();
      _cancelReply();
      if (mounted) {
        FocusScope.of(context).unfocus();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi gửi bình luận: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _startReply(CommentModel comment) {
    if (!_isLoggedIn) {
      _showLoginRequiredDialog();
      return;
    }

    setState(() {
      _replyingToComment = comment;
    });
    _focusNode.requestFocus();
  }

  void _cancelReply() {
    setState(() {
      _replyingToComment = null;
    });
  }

  void _showLoginRequiredDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Yêu cầu đăng nhập'),
        content: const Text(
          'Vui lòng đăng nhập tài khoản để tham gia bình luận và tương tác cùng cộng đồng.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Để sau'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pushNamed(context, '/login');
            },
            child: const Text('Đăng nhập'),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // XÓA BÌNH LUẬN
  // ==========================================
  Future<void> _confirmDeleteComment(CommentModel comment) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa bình luận?'),
        content: const Text('Bạn có chắc chắn muốn xóa bình luận này không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await CommentService.deleteComment(
        articleId: widget.articleId,
        commentId: comment.id,
      );
    }
  }

  // ==========================================
  // FORMAT THỜI GIAN
  // ==========================================
  String _formatTimeAgo(int timestamp) {
    final now = DateTime.now();
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final diff = now.difference(date);

    if (diff.inMinutes < 1) return 'Vừa xong';
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
    if (diff.inHours < 24) return '${diff.inHours} giờ trước';
    if (diff.inDays < 7) return '${diff.inDays} ngày trước';
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year;
    return '$day/$month/$year';
  }

  Widget _buildAvatar(String name, String avatarUrl, {double radius = 16}) {
    if (avatarUrl.isNotEmpty) {
      if (avatarUrl.startsWith('data:image')) {
        try {
          final base64String = avatarUrl.split(',').last;
          return CircleAvatar(
            radius: radius,
            backgroundImage: MemoryImage(base64Decode(base64String)),
          );
        } catch (_) {}
      } else {
        return CircleAvatar(
          radius: radius,
          backgroundImage: NetworkImage(avatarUrl),
        );
      }
    }

    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';
    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.blue.shade100,
      child: Text(
        initial,
        style: TextStyle(
          color: Colors.blue.shade900,
          fontWeight: FontWeight.bold,
          fontSize: radius * 0.8,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = _currentUser;
    final currentUserId = _currentUserId;

    return StreamBuilder<List<CommentModel>>(
      stream: CommentService.getCommentsStream(widget.articleId),
      builder: (context, snapshot) {
        final comments = snapshot.data ?? [];
        final totalCount = comments.fold<int>(
          0,
          (sum, c) => sum + 1 + c.replies.length,
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tiêu đề khu vực bình luận
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              child: Row(
                children: [
                  const Icon(Icons.mode_comment_outlined, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Bình luận ($totalCount)',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            // Ô nhập bình luận mới
            _buildInputBox(theme, user),

            const SizedBox(height: 16),

            // Danh sách bình luận
            if (snapshot.connectionState == ConnectionState.waiting && comments.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (comments.isEmpty)
              _buildEmptyComments()
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 18),
                itemCount: comments.length,
                separatorBuilder: (context, index) => const Divider(height: 24),
                itemBuilder: (context, index) {
                  final rootComment = comments[index];
                  return _buildCommentThread(rootComment, currentUserId, theme);
                },
              ),
          ],
        );
      },
    );
  }

  // ==========================================
  // GIAO DIỆN Ô NHẬP BÌNH LUẬN
  // ==========================================
  Widget _buildInputBox(ThemeData theme, User? user) {
    final isReplying = _replyingToComment != null;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 18),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isReplying ? theme.colorScheme.primary : Colors.grey.shade300,
          width: isReplying ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner hiển thị khi đang trả lời ai đó
          if (isReplying)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withAlpha(25),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.reply,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Đang trả lời @${_replyingToComment!.userName}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: _cancelReply,
                    child: const Icon(Icons.close, size: 16, color: Colors.grey),
                  ),
                ],
              ),
            ),

          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildAvatar(
                user?.displayName ?? user?.email ?? 'Bạn',
                user?.photoURL ?? '',
                radius: 18,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _commentController,
                  focusNode: _focusNode,
                  maxLines: null,
                  decoration: InputDecoration(
                    hintText: isReplying
                        ? 'Viết câu trả lời...'
                        : 'Chia sẻ ý kiến của bạn về bài viết...',
                    hintStyle: TextStyle(fontSize: 14, color: Colors.grey[500]),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 4),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _isSubmitting
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : IconButton(
                      icon: Icon(
                        Icons.send_rounded,
                        color: theme.colorScheme.primary,
                      ),
                      tooltip: 'Gửi bình luận',
                      onPressed: _handleSubmit,
                    ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================
  // THREAD BÌNH LUẬN GỐC & CÁC TRẢ LỜI LỒNG NHAU
  // ==========================================
  Widget _buildCommentThread(CommentModel root, String currentUserId, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Bình luận gốc
        _buildSingleCommentTile(root, currentUserId, theme, isReply: false),

        // Các bình luận trả lời (lồng nhau)
        if (root.replies.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 32, top: 10),
            child: Container(
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(
                    color: theme.colorScheme.primary.withAlpha(80),
                    width: 2,
                  ),
                ),
              ),
              padding: const EdgeInsets.only(left: 12),
              child: Column(
                children: root.replies.map((reply) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildSingleCommentTile(
                      reply,
                      currentUserId,
                      theme,
                      isReply: true,
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
      ],
    );
  }

  // ==========================================
  // TỪNG KHỐI BÌNH LUẬN (AVATAR, NỘI DUNG, THẢ CẢM XÚC, TRẢ LỜI)
  // ==========================================
  Widget _buildSingleCommentTile(
    CommentModel comment,
    String currentUserId,
    ThemeData theme, {
    required bool isReply,
  }) {
    final isLiked = comment.likes.contains(currentUserId);
    final likeCount = comment.likes.length;
    final isAuthor = currentUserId.isNotEmpty && comment.userId == currentUserId;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildAvatar(comment.userName, comment.userAvatar, radius: isReply ? 14 : 17),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hàng thông tin: Tên người dùng + Thời gian
              Row(
                children: [
                  Text(
                    comment.userName,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: isReply ? 13 : 14,
                    ),
                  ),
                  if (comment.replyToUserName != null &&
                      comment.replyToUserName!.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    Icon(Icons.arrow_right, size: 16, color: Colors.grey[500]),
                    const SizedBox(width: 2),
                    Text(
                      '@${comment.replyToUserName}',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(width: 8),
                  Text(
                    _formatTimeAgo(comment.createdAt),
                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                  ),
                  const Spacer(),
                  if (isAuthor)
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_horiz, size: 16, color: Colors.grey),
                      padding: EdgeInsets.zero,
                      onSelected: (val) {
                        if (val == 'delete') {
                          _confirmDeleteComment(comment);
                        }
                      },
                      itemBuilder: (ctx) => [
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline, size: 16, color: Colors.red),
                              SizedBox(width: 8),
                              Text('Xóa bình luận', style: TextStyle(color: Colors.red, fontSize: 13)),
                            ],
                          ),
                        ),
                      ],
                    ),
                ],
              ),

              const SizedBox(height: 4),

              // Nội dung bình luận
              Text(
                comment.content,
                style: TextStyle(
                  fontSize: isReply ? 13 : 14,
                  height: 1.4,
                  color: theme.textTheme.bodyMedium?.color,
                ),
              ),

              const SizedBox(height: 6),

              // Thanh tương tác: Thả cảm xúc & Nút Trả lời
              Row(
                children: [
                  // Thả cảm xúc / Tim
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () async {
                      if (currentUserId.isEmpty) {
                        _showLoginRequiredDialog();
                        return;
                      }
                      await CommentService.toggleLikeComment(
                        articleId: widget.articleId,
                        commentId: comment.id,
                        userId: currentUserId,
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      child: Row(
                        children: [
                          Icon(
                            isLiked ? Icons.favorite : Icons.favorite_border,
                            size: 15,
                            color: isLiked ? Colors.redAccent : Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            likeCount > 0 ? '$likeCount' : 'Thích',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isLiked ? FontWeight.bold : FontWeight.normal,
                              color: isLiked ? Colors.redAccent : Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(width: 14),

                  // Nút Trả lời (Reply)
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _startReply(comment),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      child: Row(
                        children: [
                          Icon(Icons.reply, size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            'Trả lời',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyComments() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          children: [
            Icon(Icons.chat_bubble_outline, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 10),
            Text(
              'Chưa có bình luận nào.',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 4),
            Text(
              'Hãy là người đầu tiên chia sẻ cảm nghĩ về bài viết này!',
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }
}
