import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/category_model.dart';

// Provider lắng nghe danh sách chuyên mục thời gian thực từ Firestore
final categoryListStreamProvider = StreamProvider<List<CategoryModel>>((ref) {
  final firestore = FirebaseFirestore.instance;
  return firestore
      .collection('categories')
      .orderBy('display_order', descending: false)
      .snapshots()
      .map((snapshot) {
    return snapshot.docs
        .map((doc) => CategoryModel.fromMap(doc.data(), doc.id))
        .toList();
  });
});

// Provider cung cấp các hàm xử lý logic của Category
final categoryManagementViewModelProvider =
Provider<CategoryManagementViewModel>((ref) {
  return CategoryManagementViewModel(FirebaseFirestore.instance);
});

class CategoryManagementViewModel {
  final FirebaseFirestore _firestore;

  CategoryManagementViewModel(this._firestore);

  // 1. Thêm chuyên mục mới
  Future<void> createCategory({
    required String name,
    required String description,
    required String iconUrl,
    required int displayOrder,
    required bool isActive,
  }) async {
    try {
      final category = CategoryModel(
        id: '',
        name: name,
        description: description,
        iconUrl: iconUrl,
        displayOrder: displayOrder,
        isActive: isActive,
      );

      final data = category.toMap();
      data['created_at'] = FieldValue.serverTimestamp();

      await _firestore.collection('categories').add(data);
    } catch (e) {
      throw Exception('Không thể tạo chuyên mục: $e');
    }
  }

  // 2. Cập nhật thông tin chuyên mục
  Future<void> updateCategory({
    required String id,
    required String name,
    required String description,
    required String iconUrl,
    required int displayOrder,
    required bool isActive,
  }) async {
    try {
      final category = CategoryModel(
        id: id,
        name: name,
        description: description,
        iconUrl: iconUrl,
        displayOrder: displayOrder,
        isActive: isActive,
      );

      await _firestore.collection('categories').doc(id).update(category.toMap());
    } catch (e) {
      throw Exception('Không thể cập nhật chuyên mục: $e');
    }
  }

  // 3. Bật / Tắt trạng thái isActive
  Future<void> toggleCategoryStatus(String id, bool currentIsActive) async {
    try {
      await _firestore.collection('categories').doc(id).update({
        'is_active': !currentIsActive,
      });
    } catch (e) {
      throw Exception('Không thể thay đổi trạng thái: $e');
    }
  }

  // 4. Xóa chuyên mục
  Future<void> deleteCategory(String id) async {
    try {
      await _firestore.collection('categories').doc(id).delete();
    } catch (e) {
      throw Exception('Không thể xóa chuyên mục: $e');
    }
  }
}