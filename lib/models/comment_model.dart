import 'package:cloud_firestore/cloud_firestore.dart';

class CommentModel {
  final String id;
  final String articleId;
  final String userId;
  final String userName;
  final String userAvatar;
  final String content;
  final int createdAt;
  final String? parentId;
  final String? replyToUserName;
  final List<String> likes;
  List<CommentModel> replies;

  CommentModel({
    required this.id,
    required this.articleId,
    required this.userId,
    required this.userName,
    required this.userAvatar,
    required this.content,
    required this.createdAt,
    this.parentId,
    this.replyToUserName,
    this.likes = const [],
    this.replies = const [],
  });

  factory CommentModel.fromMap(Map<String, dynamic> map, String documentId) {
    int parsedCreatedAt;
    final rawCreated = map['created_at'];
    if (rawCreated is int) {
      parsedCreatedAt = rawCreated;
    } else if (rawCreated is Timestamp) {
      parsedCreatedAt = rawCreated.millisecondsSinceEpoch;
    } else {
      parsedCreatedAt = DateTime.now().millisecondsSinceEpoch;
    }

    return CommentModel(
      id: documentId,
      articleId: map['article_id'] ?? '',
      userId: map['user_id'] ?? '',
      userName: map['user_name'] ?? 'Người dùng',
      userAvatar: map['user_avatar'] ?? '',
      content: map['content'] ?? '',
      createdAt: parsedCreatedAt,
      parentId: map['parent_id'],
      replyToUserName: map['reply_to_user_name'],
      likes: List<String>.from(map['likes'] ?? const []),
      replies: [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'article_id': articleId,
      'user_id': userId,
      'user_name': userName,
      'user_avatar': userAvatar,
      'content': content,
      'created_at': createdAt,
      'parent_id': parentId,
      'reply_to_user_name': replyToUserName,
      'likes': likes,
    };
  }
}
