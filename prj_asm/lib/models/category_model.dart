class CategoryModel {
  final String id;
  final String name;
  final String description;
  final String imageUrl;
  final String? parentId;
  final int articleCount;
  final bool isVisible;
  final int priority;

  CategoryModel({
    required this.id,
    required this.name,
    required this.description,
    required this.imageUrl,
    this.parentId,
    required this.articleCount,
    required this.isVisible,
    required this.priority,
  });

  factory CategoryModel.fromMap(Map<String, dynamic> map, String id) {
    return CategoryModel(
      id: id,
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      imageUrl: map['imageUrl'] ?? '',
      parentId: map['parentId'],
      articleCount: map['articleCount'] ?? 0,
      isVisible: map['isVisible'] ?? true,
      priority: map['priority'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'imageUrl': imageUrl,
      'parentId': parentId,
      'articleCount': articleCount,
      'isVisible': isVisible,
      'priority': priority,
    };
  }
}