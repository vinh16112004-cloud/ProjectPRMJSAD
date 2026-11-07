import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/comment_model.dart';

class CommentRepository {
  final FirebaseFirestore _firestore;

  CommentRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  // Lắng nghe danh sách bình luận thời gian thực của bài viết
  Stream<List<CommentModel>> getCommentsForArticle(String articleId) {
    return _firestore
        .collection('comments')
        .where('article_id', isEqualTo: articleId)
        .snapshots()
        .map((snapshot) {
      final comments = snapshot.docs
          .map((doc) => CommentModel.fromMap(doc.data(), doc.id))
          .toList();

      // Sắp xếp theo thời gian tăng dần
      comments.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return comments;
    });
  }

  // Thêm bình luận mới hoặc câu trả lời (Reply)
  Future<CommentModel> addComment({
    required String articleId,
    required String userId,
    required String userName,
    required String userAvatar,
    required String content,
    String? parentId,
    String? replyToUserName,
  }) async {
    final newComment = CommentModel(
      id: '',
      articleId: articleId,
      userId: userId,
      userName: userName,
      userAvatar: userAvatar,
      content: content.trim(),
      createdAt: DateTime.now().millisecondsSinceEpoch,
      parentId: parentId,
      replyToUserName: replyToUserName,
      likes: const [],
    );

    final docRef = await _firestore.collection('comments').add(newComment.toMap());

    // Cập nhật số lượng bình luận trong bài viết
    try {
      await _firestore.collection('articles').doc(articleId).update({
        'comments_count': FieldValue.increment(1),
      });
    } catch (_) {}

    return CommentModel.fromMap(newComment.toMap(), docRef.id);
  }

  // Thả cảm xúc / Thích bình luận
  Future<void> toggleReaction({
    required String commentId,
    required String userId,
    required bool currentIsLiked,
  }) async {
    final docRef = _firestore.collection('comments').doc(commentId);
    if (currentIsLiked) {
      await docRef.update({
        'likes': FieldValue.arrayRemove([userId]),
      });
    } else {
      await docRef.update({
        'likes': FieldValue.arrayUnion([userId]),
      });
    }
  }

  // Xóa bình luận
  Future<void> deleteComment({
    required String commentId,
    required String articleId,
  }) async {
    await _firestore.collection('comments').doc(commentId).delete();

    // Xóa các câu trả lời con liên quan nếu có
    final subComments = await _firestore
        .collection('comments')
        .where('parent_id', isEqualTo: commentId)
        .get();

    for (final doc in subComments.docs) {
      await doc.reference.delete();
    }

    // Cập nhật lại số lượng bình luận của bài viết
    try {
      final totalDeleted = 1 + subComments.docs.length;
      await _firestore.collection('articles').doc(articleId).update({
        'comments_count': FieldValue.increment(-totalDeleted),
      });
    } catch (_) {}
  }
}
