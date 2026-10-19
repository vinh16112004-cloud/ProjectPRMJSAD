class UserModel {
  final String uid;
  final String email;
  final String role; // 'Admin', 'Editor', 'Reader'
  final bool isLocked;

  UserModel({
    required this.uid,
    required this.email,
    required this.role,
    required this.isLocked,
  });

  factory UserModel.fromMap(Map<String, dynamic> map, String id) {
    return UserModel(
      uid: id,
      email: map['email'] ?? '',
      role: map['role'] ?? 'Reader',
      isLocked: map['isLocked'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'role': role,
      'isLocked': isLocked,
    };
  }
}