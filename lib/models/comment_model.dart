class CommentModel {
  final String id;
  final String articleId;
  final String userId;
  final String userName;
  final String userAvatar;
  final String content;
  final int createdAt;

  CommentModel({
    required this.id,
    required this.articleId,
    required this.userId,
    required this.userName,
    required this.userAvatar,
    required this.content,
    required this.createdAt,
  });

  factory CommentModel.fromMap(Map<String, dynamic> map, String documentId) {
    return CommentModel(
      id: documentId,
      articleId: map['article_id'] ?? '',
      userId: map['user_id'] ?? '',
      userName: map['user_name'] ?? '',
      userAvatar: map['user_avatar'] ?? '',
      content: map['content'] ?? '',
      createdAt: map['created_at'] ?? DateTime.now().millisecondsSinceEpoch,
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
    };
  }
}