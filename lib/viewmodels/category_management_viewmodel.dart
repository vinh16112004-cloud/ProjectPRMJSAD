import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/category_model.dart';

// StreamProvider lấy danh sách chuyên mục thời gian thực, sắp xếp theo display_order
final categoryListProvider = StreamProvider.autoDispose<List<CategoryModel>>((ref) {
  return FirebaseFirestore.instance
      .collection('categories')
      .orderBy('display_order')
      .snapshots()
      .map(
        (snapshot) => snapshot.docs
        .map((doc) => CategoryModel.fromMap(doc.data(), doc.id))
        .toList(),
  );
});

class CategoryManagementViewModel {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Thêm chuyên mục mới
  Future<void> addCategory({
    required String name,
    required String description,
    required String iconUrl,
    required int displayOrder,
  }) async {
    await _firestore.collection('categories').add({
      'name': name,
      'description': description,
      'icon_url': iconUrl,
      'display_order': displayOrder,
      'is_active': true,
      'created_at': FieldValue.serverTimestamp(),
    });
  }

  // Cập nhật thông tin chuyên mục
  Future<void> updateCategory({
    required String id,
    required String name,
    required String description,
    required String iconUrl,
    required int displayOrder,
    required bool isActive,
  }) async {
    await _firestore.collection('categories').doc(id).update({
      'name': name,
      'description': description,
      'icon_url': iconUrl,
      'display_order': displayOrder,
      'is_active': isActive,
    });
  }

  // Bật/Tắt trạng thái hoạt động (is_active)
  Future<void> toggleCategoryStatus(String id, bool currentStatus) async {
    await _firestore.collection('categories').doc(id).update({
      'is_active': !currentStatus,
    });
  }

  // Xóa chuyên mục
  Future<void> deleteCategory(String id) async {
    await _firestore.collection('categories').doc(id).delete();
  }
}

// Provider cho CategoryManagementViewModel
final categoryManagementViewModelProvider =
Provider((ref) => CategoryManagementViewModel());