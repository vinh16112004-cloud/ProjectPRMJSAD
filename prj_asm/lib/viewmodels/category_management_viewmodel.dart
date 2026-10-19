import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/category_model.dart';

// Provider cung cấp dữ liệu danh sách chuyên mục thời gian thực từ Firestore
final categoryListProvider = StreamProvider.autoDispose<List<CategoryModel>>((ref) {
  return FirebaseFirestore.instance
      .collection('categories')
      .orderBy('priority')
      .snapshots()
      .map((snapshot) => snapshot.docs
      .map((doc) => CategoryModel.fromMap(doc.data(), doc.id))
      .toList());
});

// ViewModel xử lý logic thêm, sửa, xóa, ẩn/hiện chuyên mục
class CategoryViewModel {
  final Ref ref;
  CategoryViewModel(this.ref);

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Thêm chuyên mục mới
  Future<void> addCategory(CategoryModel category) async {
    await _firestore.collection('categories').add(category.toMap());
  }

  // Cập nhật chuyên mục
  Future<void> updateCategory(CategoryModel category) async {
    await _firestore.collection('categories').doc(category.id).update(category.toMap());
  }

  // Xóa chuyên mục
  Future<void> deleteCategory(String categoryId) async {
    await _firestore.collection('categories').doc(categoryId).delete();
  }

  // Công tắc ẩn/hiện chuyên mục trên trang chủ
  Future<void> toggleVisibility(String categoryId, bool currentStatus) async {
    await _firestore.collection('categories').doc(categoryId).update({
      'isVisible': !currentStatus,
    });
  }
}

final categoryViewModelProvider = Provider((ref) => CategoryViewModel(ref));