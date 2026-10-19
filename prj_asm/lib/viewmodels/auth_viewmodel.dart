import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AuthViewModel {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Hàm đăng nhập và kiểm tra quyền quản trị
  Future<bool> signIn(String email, String password) async {
    try {
      // 1. Xác thực tài khoản với Firebase Auth
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // 2. Kiểm tra thông tin bổ sung trong Firestore (bảng users)
      DocumentSnapshot userDoc = await _firestore
          .collection('users')
          .doc(userCredential.user!.uid)
          .get();

      if (userDoc.exists) {
        String role = userDoc['role'] ?? 'Reader';
        bool isLocked = userDoc['isLocked'] ?? false;

        // Kiểm tra xem tài khoản có bị khóa không
        if (isLocked) {
          await _auth.signOut();
          throw Exception('Tài khoản của bạn đã bị khóa bởi quản trị viên.');
        }

        // Kiểm tra quyền hạn (Chỉ Admin hoặc Editor mới được vào CMS)
        if (role == 'Admin' || role == 'Editor') {
          return true;
        } else {
          await _auth.signOut();
          throw Exception('Bạn không có quyền truy cập vào phân hệ Quản trị (CMS).');
        }
      } else {
        await _auth.signOut();
        throw Exception('Không tìm thấy thông tin tài khoản trên hệ thống.');
      }
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