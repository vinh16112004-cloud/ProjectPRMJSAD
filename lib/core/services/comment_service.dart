import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../../models/comment_model.dart';

class CommentService {
  static FirebaseFirestore? get _firestore {
    try {
      return FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  static FirebaseAuth? get _auth {
    try {
      return FirebaseAuth.instance;
    } catch (_) {
      return null;
    }
  }

  // Danh sách mock phục vụ kiểm thử môi trường test
  @visibleForTesting
  static final List<CommentModel> mockComments = [];

  @visibleForTesting
  static String? debugUserId;

  @visibleForTesting
  static String? debugUserName;

  // ==========================================
  // 1. LẤY STREAM BÌNH LUẬN THEO THỜI GIAN THỰC
  // ==========================================
  static Stream<List<CommentModel>> getCommentsStream(String articleId) {
    final firestore = _firestore;
    if (firestore == null) {
      // Trả về stream mock khi không có Firebase
      return Stream.value(_buildThreadedComments(mockComments));
    }

    return firestore
        .collection('articles')
        .doc(articleId)
        .collection('comments')
        .orderBy('created_at', descending: false)
        .snapshots()
        .map((snapshot) {
          final rawComments = snapshot.docs.map((doc) {
            return CommentModel.fromMap(doc.data(), doc.id);
          }).toList();

          return _buildThreadedComments(rawComments);
        });
  }

  // ==========================================
  // XÂY DỰNG CẤU TRÚC BÌNH LUẬN LỒNG NHAU (THREADED REPLIES)
  // ==========================================
  static List<CommentModel> _buildThreadedComments(List<CommentModel> rawList) {
    final Map<String, CommentModel> commentMap = {};
    final List<CommentModel> rootComments = [];

    // Tạo bản đồ các comment và khởi tạo danh sách replies rỗng
    for (final comment in rawList) {
      comment.replies = [];
      commentMap[comment.id] = comment;
    }

    // Ghép comment con vào comment cha tương ứng
    for (final comment in rawList) {
      if (comment.parentId != null &&
          comment.parentId!.isNotEmpty &&
          commentMap.containsKey(comment.parentId)) {
        commentMap[comment.parentId]!.replies.add(comment);
      } else {
        rootComments.add(comment);
      }
    }

    // Sắp xếp bình luận gốc mới nhất lên đầu (descending)
    rootComments.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return rootComments;
  }

  // ==========================================
  // 2. GỬI BÌNH LUẬN MỚI HOẶC TRẢ LỜI
  // ==========================================
  static Future<void> addComment({
    required String articleId,
    required String content,
    String? parentId,
    String? replyToUserName,
  }) async {
    final trimmedContent = content.trim();
    if (trimmedContent.isEmpty) {
      throw Exception('Nội dung bình luận không được để trống.');
    }

    final user = _auth?.currentUser;
    final currentUserId = user?.uid ?? debugUserId ?? 'test-user';
    String currentUserName = user?.displayName ?? debugUserName ?? '';
    String currentUserAvatar = user?.photoURL ?? '';

    // Nếu user chưa có displayName trong Auth, tra cứu Firestore profile
    final firestore = _firestore;
    if (user != null && firestore != null && currentUserName.isEmpty) {
      try {
        final profileDoc = await firestore.collection('users').doc(user.uid).get();
        if (profileDoc.exists) {
          final data = profileDoc.data();
          currentUserName = data?['full_name'] ?? '';
          if (currentUserAvatar.isEmpty) {
            currentUserAvatar = data?['avatar_url'] ?? '';
          }
        }
      } catch (_) {}
    }

    if (currentUserName.isEmpty) {
      currentUserName = user?.email?.split('@').first ?? 'Độc giả';
    }

    final newCommentMap = {
      'article_id': articleId,
      'user_id': currentUserId,
      'user_name': currentUserName,
      'user_avatar': currentUserAvatar,
      'content': trimmedContent,
      'created_at': DateTime.now().millisecondsSinceEpoch,
      'parent_id': parentId,
      'reply_to_user_name': replyToUserName,
      'likes': <String>[],
    };

    if (firestore != null) {
      await firestore
          .collection('articles')
          .doc(articleId)
          .collection('comments')
          .add(newCommentMap);
    } else {
      // Lưu vào mock test
      mockComments.add(CommentModel.fromMap(newCommentMap, 'mock-${DateTime.now().millisecondsSinceEpoch}'));
    }
  }

  // ==========================================
  // 3. THẢ CẢM XÚC / THÍCH BÌNH LUẬN
  // ==========================================
  static Future<void> toggleLikeComment({
    required String articleId,
    required String commentId,
    required String userId,
  }) async {
    final firestore = _firestore;
    if (firestore != null) {
      final commentRef = firestore
          .collection('articles')
          .doc(articleId)
          .collection('comments')
          .doc(commentId);

      final doc = await commentRef.get();
      if (!doc.exists) return;

      final data = doc.data();
      final likes = List<String>.from(data?['likes'] ?? const []);

      if (likes.contains(userId)) {
        await commentRef.update({
          'likes': FieldValue.arrayRemove([userId]),
        });
      } else {
        await commentRef.update({
          'likes': FieldValue.arrayUnion([userId]),
        });
      }
    } else {
      // Mock toggle
      final comment = mockComments.firstWhere((c) => c.id == commentId, orElse: () => mockComments.first);
      if (comment.likes.contains(userId)) {
        comment.likes.remove(userId);
      } else {
        comment.likes.add(userId);
      }
    }
  }

  // ==========================================
  // 4. XÓA BÌNH LUẬN
  // ==========================================
  static Future<void> deleteComment({
    required String articleId,
    required String commentId,
  }) async {
    final firestore = _firestore;
    if (firestore != null) {
      await firestore
          .collection('articles')
          .doc(articleId)
          .collection('comments')
          .doc(commentId)
          .delete();
    } else {
      mockComments.removeWhere((c) => c.id == commentId);
    }
  }
}
