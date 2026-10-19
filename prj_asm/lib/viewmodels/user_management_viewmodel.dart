import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';

// 1. Khai báo StreamProvider để lấy danh sách người dùng realtime từ Firestore
final userListProvider = StreamProvider.autoDispose<List<UserModel>>((ref) {
  return FirebaseFirestore.instance.collection('users').snapshots().map(
        (snapshot) => snapshot.docs
        .map((doc) => UserModel.fromMap(doc.data(), doc.id))
        .toList(),
  );
});

class UserManagementViewModel {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Hàm thêm người dùng mới mà không làm mất phiên đăng nhập hiện tại
  Future<void> createUser({
    required String email,
    required String password,
    required String role,
  }) async {
    FirebaseApp secondaryApp = await Firebase.initializeApp(
      name: 'SecondaryApp_${DateTime.now().millisecondsSinceEpoch}',
      options: Firebase.app().options,
    );

    try {
      FirebaseAuth secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);

      UserCredential cred = await secondaryAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      String newUid = cred.user!.uid;

      await _firestore.collection('users').doc(newUid).set({
        'email': email,
        'role': role,
        'isLocked': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } finally {
      await secondaryApp.delete();
    }
  }

  // Bật/Tắt trạng thái Khóa tài khoản
  Future<void> toggleUserLockStatus(String uid, bool currentStatus) async {
    await _firestore.collection('users').doc(uid).update({
      'isLocked': !currentStatus,
    });
  }

  // Cập nhật vai trò người dùng (Admin, Editor, Reader)
  Future<void> updateUserRole(String uid, String newRole) async {
    await _firestore.collection('users').doc(uid).update({
      'role': newRole,
    });
  }
}

// 2. Khai báo Provider cho ViewModel
final userManagementViewModelProvider =
Provider((ref) => UserManagementViewModel());