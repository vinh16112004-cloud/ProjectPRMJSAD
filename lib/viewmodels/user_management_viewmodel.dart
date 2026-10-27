import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import '../models/user_model.dart';

// 1. Provider lắng nghe danh sách người dùng thời gian thực từ Firestore
final userListStreamProvider = StreamProvider<List<UserModel>>((ref) {
  final firestore = FirebaseFirestore.instance;
  return firestore.collection('users').snapshots().map((snapshot) {
    return snapshot.docs.map((doc) => UserModel.fromMap(doc.data(), doc.id)).toList();
  });
});

// 2. Provider cung cấp các hàm xử lý logic (ViewModel)
final userManagementViewModelProvider = Provider<UserManagementViewModel>((ref) {
  return UserManagementViewModel(FirebaseFirestore.instance);
});

class UserManagementViewModel {
  final FirebaseFirestore _firestore;

  UserManagementViewModel(this._firestore);

  // Tạo người dùng mới (Authentication + Firestore)
  Future<void> createUser({
    required String email,
    required String password,
    required String role,
    String fullName = '',
    String phone = '',
  }) async {
    try {
      final credential = await auth.FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final uid = credential.user?.uid;
      if (uid != null) {
        await _firestore.collection('users').doc(uid).set({
          'email': email,
          'full_name': fullName,
          'phone': phone,
          'role': role,
          'is_locked': false,
        });
      }
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  // Khóa / Mở khóa tài khoản
  Future<void> toggleLockUser(String uid, bool currentIsLocked) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'is_locked': !currentIsLocked,
      });
    } catch (e) {
      throw Exception('Không thể thay đổi trạng thái khóa: $e');
    }
  }

  // Cập nhật thông tin người dùng (Họ tên, SĐT, Role)
  Future<void> updateUserInfo({
    required String uid,
    required String fullName,
    required String phone,
    required String role,
  }) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'full_name': fullName,
        'phone': phone,
        'role': role,
      });
    } catch (e) {
      throw Exception('Không thể cập nhật thông tin người dùng: $e');
    }
  }

  // Xóa người dùng
  Future<void> deleteUser(String uid) async {
    try {
      await _firestore.collection('users').doc(uid).delete();
    } catch (e) {
      throw Exception('Không thể xóa người dùng: $e');
    }
  }
}