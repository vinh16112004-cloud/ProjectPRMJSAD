class UserModel {
  final String uid;
  final String fullName;
  final String email;
  final String phone;
  final String avatarUrl;
  final String role; // 'Admin', 'Editor', 'Reader'
  final bool isLocked;

  UserModel({
    required this.uid,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.avatarUrl,
    required this.role,
    required this.isLocked,
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
    );
    //hi
  }

  Map<String, dynamic> toMap() {
    return {
      'full_name': fullName,
      'email': email,
      'phone': phone,
      'avatar_url': avatarUrl,
      'role': role,
      'is_locked': isLocked,
    };
  }
}