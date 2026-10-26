class ReadingHistoryModel {
  final String id;
  final String articleId;
  final int readAt;

  ReadingHistoryModel({
    required this.id,
    required this.articleId,
    required this.readAt,
  });

  factory ReadingHistoryModel.fromMap(Map<String, dynamic> map, String documentId) {
    return ReadingHistoryModel(
      id: documentId,
      articleId: map['article_id'] ?? '',
      readAt: map['read_at'] ?? DateTime.now().millisecondsSinceEpoch,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'article_id': articleId,
      'read_at': readAt,
    };
  }
}