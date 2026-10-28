  class ReadingHistoryModel {
  final String id;
  final String articleId;
  final int readAt;
  final String title;
  final String summary;
  final String content;
  final String thumbnailUrl;
  final String author;
  final String categoryId;

  ReadingHistoryModel({
    required this.id,
    required this.articleId,
    required this.readAt,
    this.title = '',
    this.summary = '',
    this.content = '',
    this.thumbnailUrl = '',
    this.author = '',
    this.categoryId = '',
  });

  factory ReadingHistoryModel.fromMap(Map<String, dynamic> map, String documentId) {
    return ReadingHistoryModel(
      id: documentId,
      articleId: map['article_id'] ?? (map['id'] ?? documentId),
      readAt: map['read_at'] ?? DateTime.now().millisecondsSinceEpoch,
      title: map['title'] ?? '',
      summary: map['summary'] ?? '',
      content: map['content'] ?? '',
      thumbnailUrl: map['thumbnail_url'] ?? '',
      author: map['author'] ?? '',
      categoryId: map['category_id'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'article_id': articleId,
      'read_at': readAt,
      'title': title,
      'summary': summary,
      'content': content,
      'thumbnail_url': thumbnailUrl,
      'author': author,
      'category_id': categoryId,
    };
  }
}
