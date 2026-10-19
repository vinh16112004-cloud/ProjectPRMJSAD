class CategoryModel {
  final String id;
  final String name;
  final String description;
  final String iconUrl;
  final int displayOrder;
  final bool isActive;

  CategoryModel({
    required this.id,
    required this.name,
    required this.description,
    required this.iconUrl,
    required this.displayOrder,
    required this.isActive,
  });

  factory CategoryModel.fromMap(Map<String, dynamic> map, String documentId) {
    return CategoryModel(
      id: documentId,
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      iconUrl: map['icon_url'] ?? '',
      displayOrder: map['display_order'] ?? 0,
      isActive: map['is_active'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'icon_url': iconUrl,
      'display_order': displayOrder,
      'is_active': isActive,
    };
  }
}