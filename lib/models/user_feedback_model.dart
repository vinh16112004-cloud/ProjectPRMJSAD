class UserFeedbackModel {
  final String id;
  final String type;
  final String content;
  final String? imagePath;
  final int createdAt;

  UserFeedbackModel({
    required this.id,
    required this.type,
    required this.content,
    this.imagePath,
    required this.createdAt,
  });

  factory UserFeedbackModel.fromMap(Map<String, dynamic> map, String documentId) {
    return UserFeedbackModel(
      id: documentId,
      type: map['type'] ?? '',
      content: map['content'] ?? '',
      imagePath: map['image_path'],
      createdAt: map['created_at'] ?? DateTime.now().millisecondsSinceEpoch,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'content': content,
      'image_path': imagePath,
      'created_at': createdAt,
    };
  }
}