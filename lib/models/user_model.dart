class UserModel {
  final String uid;
  final String fullName;
  final String email;
  final String phone;
  final String avatarUrl;
  final String role;
  final bool isLocked;
  final List<String> favoriteCategories;

  UserModel({
    required this.uid,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.avatarUrl,
    required this.role,
    required this.isLocked,
    this.favoriteCategories = const [],
  });

  factory UserModel.fromMap(Map<String, dynamic> map, String documentId) {
    return UserModel(
      uid: documentId,
      fullName: map['full_name'] ?? '',
      email: map['email'] ?? '',
      phone: map['phone'] ?? '',
      avatarUrl: map['avatar_url'] ?? '',
      role: map['role'] ?? 'Reader',
      isLocked: map['is_locked'] ?? false,
      favoriteCategories: List<String>.from(
        map['favorite_categories'] ?? const [],
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'full_name': fullName,
      'email': email,
      'phone': phone,
      'avatar_url': avatarUrl,
      'role': role,
      'is_locked': isLocked,
      'favorite_categories': favoriteCategories,
    };
  }
}
