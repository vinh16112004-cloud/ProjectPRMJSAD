class CommentModel {
  final String id;
  final String articleId;
  final String userId;
  final String userName;
  final String userAvatar;
  final String content;
  final int createdAt;
  final String? parentId; // ID của bình luận cha nếu là câu trả lời
  final String? replyToUserName; // Tên của người được trả lời
  final List<String> likes; // Danh sách UID những người đã thả tim/thích

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
  });

  int get likeCount => likes.length;

  bool isLikedBy(String uid) => likes.contains(uid);

  factory CommentModel.fromMap(Map<String, dynamic> map, String documentId) {
    return CommentModel(
      id: documentId,
      articleId: map['article_id'] ?? '',
      userId: map['user_id'] ?? '',
      userName: map['user_name'] ?? 'Độc giả',
      userAvatar: map['user_avatar'] ?? '',
      content: map['content'] ?? '',
      createdAt: map['created_at'] is int
          ? map['created_at']
          : DateTime.now().millisecondsSinceEpoch,
      parentId: map['parent_id'],
      replyToUserName: map['reply_to_user_name'],
      likes: List<String>.from(map['likes'] ?? const []),
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
