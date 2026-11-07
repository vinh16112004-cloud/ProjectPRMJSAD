import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/comment_model.dart';
import '../../../viewmodels/auth_viewmodel.dart';
import '../../../viewmodels/comment_viewmodel.dart';

class CommentSectionWidget extends ConsumerStatefulWidget {
  final String articleId;

  const CommentSectionWidget({
    super.key,
    required this.articleId,
  });

  @override
  ConsumerState<CommentSectionWidget> createState() => _CommentSectionWidgetState();
}

class _CommentSectionWidgetState extends ConsumerState<CommentSectionWidget> {
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  CommentModel? _replyingTo;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _startReply(CommentModel parentComment) {
    setState(() {
      _replyingTo = parentComment;
    });
    _focusNode.requestFocus();
  }

  void _cancelReply() {
    setState(() {
      _replyingTo = null;
    });
  }

  void _showRequireLoginDialog(BuildContext context, {required String actionName}) {
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

  Future<void> _submitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    final authUser = FirebaseAuth.instance.currentUser;
    if (authUser == null) {
      _showRequireLoginDialog(context, actionName: 'bình luận bài viết');
      return;
    }

    final String currentUserId = authUser.uid;
    final String currentUserName = authUser.displayName?.isNotEmpty == true
        ? authUser.displayName!
        : (authUser.email?.split('@').first ?? 'Độc giả');
    final String currentUserAvatar = authUser.photoURL ?? '';

    setState(() => _isSubmitting = true);

    try {
      await ref.read(commentViewModelProvider).sendComment(
            articleId: widget.articleId,
            userId: currentUserId,
            userName: currentUserName,
            userAvatar: currentUserAvatar,
            content: text,
            parentId: _replyingTo?.id,
            replyToUserName: _replyingTo?.userName,
          );

      _commentController.clear();
      _cancelReply();
      _focusNode.unfocus();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bình luận của bạn đã được đăng!'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Không thể gửi bình luận: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _handleDeleteComment(CommentModel comment) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa bình luận'),
        content: const Text('Bạn có chắc chắn muốn xóa bình luận này?'),
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
      try {
        await ref.read(commentViewModelProvider).deleteComment(
              commentId: comment.id,
              articleId: widget.articleId,
            );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã xóa bình luận')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Lỗi khi xóa: $e')),
          );
        }
      }
    }
  }

  String _formatTimeAgo(int timestamp) {
    final now = DateTime.now();
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final diff = now.difference(date);

    if (diff.inSeconds < 60) return 'Vừa xong';
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
    if (diff.inHours < 24) return '${diff.inHours} giờ trước';
    if (diff.inDays < 7) return '${diff.inDays} ngày trước';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final commentsAsync = ref.watch(articleCommentsStreamProvider(widget.articleId));
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currentUser = ref.watch(authStateChangesProvider).valueOrNull ?? FirebaseAuth.instance.currentUser;
    final currentUid = currentUser?.uid ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // =====================================================================
        // TIÊU ĐỀ PHẦN BÌNH LUẬN
        // =====================================================================
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.chat_bubble_outline, size: 20, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  'Bình luận',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(width: 6),
                commentsAsync.when(
                  data: (comments) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.blue.shade900 : Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${comments.length}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.blue.shade200 : Colors.blue.shade700,
                      ),
                    ),
                  ),
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => const SizedBox.shrink(),
                ),
              ],
            ),
          ],
        ),

        const SizedBox(height: 16),

        // =====================================================================
        // Ô NHẬP BÌNH LUẬN MỚI
        // =====================================================================
        Container(
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thanh thông báo khi đang trả lời ai đó
              if (_replyingTo != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.reply, size: 16, color: Colors.blue),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Đang trả lời @${_replyingTo!.userName}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      InkWell(
                        onTap: _cancelReply,
                        child: const Icon(Icons.close, size: 16, color: Colors.grey),
                      ),
                    ],
                  ),
                ),

              // Trường nhập nội dung
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.blue.shade100,
                    backgroundImage: currentUser?.photoURL != null && currentUser!.photoURL!.isNotEmpty
                        ? NetworkImage(currentUser.photoURL!)
                        : null,
                    child: currentUser?.photoURL == null || currentUser!.photoURL!.isEmpty
                        ? Text(
                            (currentUser?.displayName ?? currentUser?.email ?? 'U').substring(0, 1).toUpperCase(),
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                          )
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      focusNode: _focusNode,
                      minLines: 1,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: _replyingTo != null
                            ? 'Viết câu trả lời của bạn...'
                            : 'Chia sẻ ý kiến của bạn về bài viết...',
                        hintStyle: TextStyle(fontSize: 14, color: Colors.grey[500]),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 6),
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
                          icon: const Icon(Icons.send_rounded, color: Colors.blue),
                          onPressed: _submitComment,
                          tooltip: 'Gửi bình luận',
                        ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // =====================================================================
        // DANH SÁCH BÌNH LUẬN THỜI GIAN THỰC
        // =====================================================================
        commentsAsync.when(
          data: (comments) {
            if (comments.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[900] : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(Icons.speaker_notes_outlined, size: 40, color: Colors.grey[400]),
                    const SizedBox(height: 8),
                    Text(
                      'Chưa có bình luận nào.',
                      style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Hãy là người đầu tiên chia sẻ cảm nghĩ về bài viết này!',
                      style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                    ),
                  ],
                ),
              );
            }

            // Phân chia bình luận gốc (top-level) và câu trả lời (replies)
            final topLevelComments = comments.where((c) => c.parentId == null || c.parentId!.isEmpty).toList();
            // Đảo ngược bình luận gốc mới nhất lên trên
            topLevelComments.sort((a, b) => b.createdAt.compareTo(a.createdAt));

            final repliesMap = <String, List<CommentModel>>{};
            for (final comment in comments) {
              if (comment.parentId != null && comment.parentId!.isNotEmpty) {
                repliesMap.putIfAbsent(comment.parentId!, () => []).add(comment);
              }
            }

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: topLevelComments.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final parent = topLevelComments[index];
                final replies = repliesMap[parent.id] ?? [];

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Bình luận gốc
                    _buildCommentItem(
                      comment: parent,
                      isDark: isDark,
                      currentUid: currentUid,
                      isReply: false,
                    ),

                    // Danh sách các câu trả lời con thụt lề
                    if (replies.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(left: 36, top: 8),
                        child: Column(
                          children: replies.map((reply) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _buildCommentItem(
                                comment: reply,
                                isDark: isDark,
                                currentUid: currentUid,
                                isReply: true,
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                  ],
                );
              },
            );
          },
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (err, _) => Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('Lỗi tải bình luận: $err', style: const TextStyle(color: Colors.red)),
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // WIDGET HIỂN THỊ MỘT BÌNH LUẬN (ITEM)
  // ===========================================================================

  Widget _buildCommentItem({
    required CommentModel comment,
    required bool isDark,
    required String currentUid,
    required bool isReply,
  }) {
    final isLiked = comment.isLikedBy(currentUid);
    final isOwner = currentUid.isNotEmpty && comment.userId == currentUid;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? (isReply ? Colors.grey[850] : Colors.grey[900])
            : (isReply ? const Color(0xFFF8FAFC) : Colors.white),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Avatar, Tên, Thời gian & Nút Xóa
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: isReply ? Colors.indigo.shade100 : Colors.blue.shade100,
                backgroundImage: comment.userAvatar.isNotEmpty ? NetworkImage(comment.userAvatar) : null,
                child: comment.userAvatar.isEmpty
                    ? Text(
                        comment.userName.substring(0, 1).toUpperCase(),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isReply ? Colors.indigo : Colors.blue,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      comment.userName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      _formatTimeAgo(comment.createdAt),
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
              if (isOwner)
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18, color: Colors.grey),
                  tooltip: 'Xóa bình luận',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => _handleDeleteComment(comment),
                ),
            ],
          ),

          const SizedBox(height: 8),

          // Nội dung bình luận
          RichText(
            text: TextSpan(
              style: TextStyle(
                fontSize: 14,
                height: 1.45,
                color: isDark ? Colors.grey[200] : const Color(0xFF1E293B),
              ),
              children: [
                if (comment.replyToUserName != null && comment.replyToUserName!.isNotEmpty)
                  TextSpan(
                    text: '@${comment.replyToUserName} ',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                TextSpan(text: comment.content),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Action row: Thả cảm xúc & Trả lời
          Row(
            children: [
              // Nút thả cảm xúc / Thích bình luận
              InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () async {
                  if (currentUid.isEmpty) {
                    _showRequireLoginDialog(context, actionName: 'thả cảm xúc bình luận');
                    return;
                  }
                  await ref.read(commentViewModelProvider).toggleReaction(
                        commentId: comment.id,
                        userId: currentUid,
                        currentIsLiked: isLiked,
                      );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Row(
                    children: [
                      Icon(
                        isLiked ? Icons.favorite : Icons.favorite_border,
                        size: 16,
                        color: isLiked ? Colors.red : Colors.grey[600],
                      ),
                      if (comment.likeCount > 0) ...[
                        const SizedBox(width: 4),
                        Text(
                          '${comment.likeCount}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isLiked ? Colors.red : Colors.grey[600],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // Nút Trả lời (Reply)
              InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  if (currentUid.isEmpty) {
                    _showRequireLoginDialog(context, actionName: 'trả lời bình luận');
                    return;
                  }
                  _startReply(comment);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Row(
                    children: [
                      Icon(Icons.reply, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        'Trả lời',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
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
    );
  }
}
