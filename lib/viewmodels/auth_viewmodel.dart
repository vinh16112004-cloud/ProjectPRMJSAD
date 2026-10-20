import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AuthViewModel {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Hàm đăng nhập và kiểm tra quyền Admin
  Future<bool> signIn(String email, String password) async {
    try {
      // 1. Xác thực tài khoản với Firebase Auth
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      String uid = userCredential.user!.uid;

      // 2. Lấy thông tin tài khoản từ Firestore collection 'users'
      DocumentSnapshot userDoc =
      await _firestore.collection('users').doc(uid).get();

      if (!userDoc.exists) {
        await _auth.signOut();
        throw Exception("Tài khoản chưa được cấu hình phân quyền trong hệ thống.");
      }

      Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;

      // 3. Kiểm tra xem tài khoản có bị khóa không (Dùng key 'is_locked')
      bool isLocked = userData['is_locked'] ?? false;
      if (isLocked) {
        await _auth.signOut();
        throw Exception("Tài khoản này đã bị khóa.");
      }

      // 4. Kiểm tra quyền hạn (Bắt buộc phải là Admin)
      String role = userData['role'] ?? 'Reader';
      if (role != 'Admin') {
        await _auth.signOut();
        throw Exception(
            "Truy cập bị từ chối! Chỉ tài khoản có quyền Admin mới được phép vào.");
      }

      return true;
    } catch (e) {
      rethrow;
    }
  }

  // Hàm đăng xuất
  Future<void> signOut() async {
    await _auth.signOut();
  }
}

final authViewModelProvider = Provider((ref) => AuthViewModel());