class ArticleModel {
  final String id;
  final String title;
  final String summary;
  final String content;
  final String categoryId;
  final String thumbnailUrl;
  final String author;
  final int status; // 0: Nháp, 1: Đã xuất bản, 2: Đã ẩn
  final bool isHot;
  final int publishedAt;

  ArticleModel({
    required this.id,
    required this.title,
    required this.summary,
    required this.content,
    required this.categoryId,
    required this.thumbnailUrl,
    required this.author,
    required this.status,
    required this.isHot,
    required this.publishedAt,
  });

  factory ArticleModel.fromMap(Map<String, dynamic> map, String documentId) {
    return ArticleModel(
      id: documentId,
      title: map['title'] ?? '',
      summary: map['summary'] ?? '',
      content: map['content'] ?? '',
      categoryId: map['category_id'] ?? '',
      thumbnailUrl: map['thumbnail_url'] ?? '',
      author: map['author'] ?? '',
      status: map['status'] ?? 1,
      isHot: map['is_hot'] ?? false,
      publishedAt: map['published_at'] ?? DateTime.now().millisecondsSinceEpoch,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'summary': summary,
      'content': content,
      'category_id': categoryId,
      'thumbnail_url': thumbnailUrl,
      'author': author,
      'status': status,
      'is_hot': isHot,
      'published_at': publishedAt,
    };
  }
}