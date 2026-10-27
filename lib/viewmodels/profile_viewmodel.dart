import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../models/category_model.dart';

final profileViewModelProvider = Provider((ref) => ProfileViewModel());

final activeCategoriesProvider = StreamProvider<List<CategoryModel>>((ref) {
  return FirebaseFirestore.instance
      .collection('categories')
      .where('is_active', isEqualTo: true)
      .snapshots()
      .map((snapshot) {
        final categories = snapshot.docs
            .map((doc) => CategoryModel.fromMap(doc.data(), doc.id))
            .toList();
        categories.sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
        return categories;
      });
});

class ProfileViewModel {
  static const maxAvatarBytes = 500 * 1024;
  static const _requestTimeout = Duration(seconds: 20);

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  ProfileViewModel({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  Future<void> updateProfile({
    required String fullName,
    required String phone,
    required List<String> favoriteCategories,
    XFile? avatarFile,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Vui lòng đăng nhập lại để tiếp tục.');

    String? avatarData;
    if (avatarFile != null) {
      if (await avatarFile.length() > maxAvatarBytes) {
        throw Exception('Ảnh đại diện sau khi nén không được lớn hơn 500 KB.');
      }
      final bytes = await avatarFile.readAsBytes();
      final mimeType = avatarFile.mimeType ?? 'image/jpeg';
      avatarData = 'data:$mimeType;base64,${base64Encode(bytes)}';
    }

    await user
        .updateDisplayName(fullName.trim())
        .timeout(
          _requestTimeout,
          onTimeout: () => throw TimeoutException(
            'Firebase Auth không phản hồi khi cập nhật họ tên.',
          ),
        );

    await _firestore
        .collection('users')
        .doc(user.uid)
        .update(<String, dynamic>{
          'full_name': fullName.trim(),
          'email': user.email,
          'phone': phone.trim(),
          'favorite_categories': favoriteCategories,
          'avatar_url': ?avatarData,
        })
        .timeout(
          _requestTimeout,
          onTimeout: () => throw TimeoutException(
            'Cloud Firestore không phản hồi khi lưu hồ sơ. Hãy kiểm tra mạng hoặc Firestore Rules.',
          ),
        );
  }
}
