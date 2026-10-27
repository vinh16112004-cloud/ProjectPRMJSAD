import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_model.dart';

final authStateChangesProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

final userProfileProvider = StreamProvider.family<UserModel?, String>((
  ref,
  uid,
) {
  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .snapshots()
      .map(
        (snapshot) => snapshot.exists
            ? UserModel.fromMap(snapshot.data()!, snapshot.id)
            : null,
      );
});

final authViewModelProvider = Provider((ref) => AuthViewModel());

class AuthViewModel {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final GoogleSignIn _googleSignIn;

  String _pendingResetEmail = '';
  String _pendingOtpCode = '';
  DateTime? _otpExpiresAt;
  bool _otpVerified = false;

  AuthViewModel({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    GoogleSignIn? googleSignIn,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _googleSignIn = googleSignIn ?? GoogleSignIn();

  static bool get _supportsNativeGoogleSignIn =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static Future<void> restoreRememberedSession() async {
    final preferences = await SharedPreferences.getInstance();
    final rememberLogin = preferences.getBool('remember_login') ?? false;
    if (!rememberLogin && FirebaseAuth.instance.currentUser != null) {
      await FirebaseAuth.instance.signOut();
    }
  }

  Future<bool> signIn(
    String email,
    String password, {
    bool rememberMe = false,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    try {
      await _validateAccount(credential.user);
    } catch (_) {
      await _auth.signOut();
      rethrow;
    }

    await _saveRememberMe(rememberMe);
    return true;
  }

  Future<bool> signInWithGoogle({bool rememberMe = false}) async {
    UserCredential credential;

    if (kIsWeb) {
      final provider = GoogleAuthProvider()
        ..setCustomParameters({'prompt': 'select_account'});
      credential = await _auth.signInWithPopup(provider);
    } else {
      if (!_supportsNativeGoogleSignIn) {
        throw Exception('Đăng nhập Google chưa được hỗ trợ trên nền tảng này.');
      }
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return false;

      final googleAuth = await googleUser.authentication;
      final oauthCredential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      credential = await _auth.signInWithCredential(oauthCredential);
    }

    try {
      final user = credential.user;
      if (user == null) throw Exception('Không thể xác thực tài khoản Google.');

      final document = _firestore.collection('users').doc(user.uid);
      final snapshot = await document.get();
      if (!snapshot.exists) {
        await document.set(
          UserModel(
            uid: user.uid,
            fullName: user.displayName ?? '',
            email: user.email ?? '',
            phone: user.phoneNumber ?? '',
            avatarUrl: user.photoURL ?? '',
            role: 'Reader',
            isLocked: false,
          ).toMap(),
        );
      }
      await _validateAccount(user);
    } catch (_) {
      await _auth.signOut();
      rethrow;
    }

    await _saveRememberMe(rememberMe);
    return true;
  }

  Future<void> register({
    required String fullName,
    required String email,
    required String password,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = credential.user;
    if (user == null) throw Exception('Không thể tạo tài khoản.');

    try {
      await user.updateDisplayName(fullName.trim());
      await _firestore
          .collection('users')
          .doc(user.uid)
          .set(
            UserModel(
              uid: user.uid,
              fullName: fullName.trim(),
              email: email.trim(),
              phone: '',
              avatarUrl: '',
              role: 'Reader',
              isLocked: false,
            ).toMap(),
          );
    } catch (_) {
      await user.delete();
      rethrow;
    }

    await _saveRememberMe(false);
  }

  Future<void> sendPasswordResetEmail(String email) {
    return _auth.sendPasswordResetEmail(email: email.trim());
  }

  /// Bước 1: Tạo và gửi mã OTP 6 chữ số để đặt lại mật khẩu.
  Future<String> requestPasswordResetOtp(String email) async {
    final normalizedEmail = email.trim();
    if (normalizedEmail.isEmpty) {
      throw Exception('Vui lòng nhập email.');
    }

    final millis = DateTime.now().microsecondsSinceEpoch;
    final code = ((millis % 900000) + 100000).toString();

    _pendingResetEmail = normalizedEmail.toLowerCase();
    _pendingOtpCode = code;
    _otpExpiresAt = DateTime.now().add(const Duration(minutes: 5));
    _otpVerified = false;

    return code;
  }

  /// Bước 2: Xác thực mã OTP người dùng đã nhập.
  Future<bool> verifyPasswordResetOtp({
    required String email,
    required String otp,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final trimmedOtp = otp.trim();

    if (_pendingResetEmail.isEmpty ||
        _pendingResetEmail != normalizedEmail ||
        _pendingOtpCode.isEmpty) {
      throw Exception('Vui lòng yêu cầu gửi mã OTP trước.');
    }

    if (_otpExpiresAt != null && DateTime.now().isAfter(_otpExpiresAt!)) {
      throw Exception('Mã OTP đã hết hạn. Vui lòng gửi lại mã mới.');
    }

    if (_pendingOtpCode != trimmedOtp) {
      throw Exception('Mã OTP không chính xác.');
    }

    _otpVerified = true;
    return true;
  }

  /// Bước 3: Xác nhận tạo mật khẩu mới sau khi đã xác thực OTP.
  Future<void> resetPasswordWithOtp({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    final normalizedEmail = email.trim();
    if (!_otpVerified ||
        _pendingResetEmail != normalizedEmail.toLowerCase() ||
        _pendingOtpCode != otp.trim()) {
      await verifyPasswordResetOtp(email: normalizedEmail, otp: otp);
    }

    await _auth.sendPasswordResetEmail(email: normalizedEmail);

    _pendingResetEmail = '';
    _pendingOtpCode = '';
    _otpExpiresAt = null;
    _otpVerified = false;
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _requireUser();
    final credential = EmailAuthProvider.credential(
      email: user.email!,
      password: currentPassword,
    );
    await user.reauthenticateWithCredential(credential);
    await user.updatePassword(newPassword);
  }

  Future<void> requestEmailChange({
    required String newEmail,
    required String currentPassword,
  }) async {
    final user = _requireUser();
    final credential = EmailAuthProvider.credential(
      email: user.email!,
      password: currentPassword,
    );
    await user.reauthenticateWithCredential(credential);
    await user.verifyBeforeUpdateEmail(newEmail.trim());
  }

  Future<void> signOut() async {
    await _auth.signOut();
    await _saveRememberMe(false);
    if (_supportsNativeGoogleSignIn) {
      await _googleSignIn.signOut();
    }
  }

  Future<void> _validateAccount(User? user) async {
    if (user == null) throw Exception('Không thể xác thực tài khoản.');

    final snapshot = await _firestore.collection('users').doc(user.uid).get();
    if (!snapshot.exists) {
      throw Exception('Tài khoản chưa có hồ sơ trong hệ thống.');
    }
    if (snapshot.data()?['is_locked'] == true) {
      throw Exception('Tài khoản này đã bị khóa.');
    }
  }

  User _requireUser() {
    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      throw Exception('Vui lòng đăng nhập lại để tiếp tục.');
    }
    return user;
  }

  Future<void> _saveRememberMe(bool rememberMe) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool('remember_login', rememberMe);
  }
}

String authErrorMessage(Object error) {
  if (error is FirebaseAuthException) {
    switch (error.code) {
      case 'invalid-email':
        return 'Email không hợp lệ.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Email hoặc mật khẩu không đúng.';
      case 'email-already-in-use':
        return 'Email này đã được sử dụng.';
      case 'weak-password':
        return 'Mật khẩu quá yếu, vui lòng chọn mật khẩu khác.';
      case 'user-disabled':
        return 'Tài khoản này đã bị vô hiệu hóa.';
      case 'too-many-requests':
        return 'Bạn đã thử quá nhiều lần. Vui lòng thử lại sau.';
      case 'network-request-failed':
        return 'Không có kết nối mạng. Vui lòng thử lại.';
      case 'requires-recent-login':
        return 'Vui lòng đăng xuất, đăng nhập lại rồi thực hiện thao tác này.';
      case 'unauthorized-domain':
        return 'Tên miền hiện tại chưa được cho phép trong Firebase Authentication. Hãy dùng localhost hoặc thêm tên miền vào Authorized domains.';
      case 'operation-not-allowed':
        return 'Phương thức đăng nhập này chưa được bật trong Firebase Authentication.';
      case 'popup-blocked':
        return 'Trình duyệt đã chặn cửa sổ đăng nhập Google. Vui lòng cho phép cửa sổ bật lên rồi thử lại.';
      case 'popup-closed-by-user':
      case 'cancelled-popup-request':
        return 'Đã hủy đăng nhập Google.';
      default:
        return error.message ?? 'Đã xảy ra lỗi xác thực.';
    }
  }
  if (error is TimeoutException) {
    return error.message ??
        'Không nhận được phản hồi từ Firebase. Vui lòng kiểm tra mạng và thử lại.';
  }
  return error.toString().replaceFirst('Exception: ', '');
}
