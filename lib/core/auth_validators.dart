class AuthValidators {
  static final RegExp _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
  static final RegExp _phonePattern = RegExp(r'^(?:\+84|0)\d{9}$');

  static String? email(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Vui lòng nhập email';
    if (!_emailPattern.hasMatch(email)) return 'Email không hợp lệ';
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) return 'Vui lòng nhập mật khẩu';
    if (value.length < 6) return 'Mật khẩu phải có ít nhất 6 ký tự';
    return null;
  }

  static String? confirmPassword(String? value, String password) {
    final error = AuthValidators.password(value);
    if (error != null) return error;
    if (value != password) return 'Mật khẩu xác nhận không khớp';
    return null;
  }

  static String? fullName(String? value) {
    final fullName = value?.trim() ?? '';
    if (fullName.isEmpty) return 'Vui lòng nhập họ tên';
    if (fullName.length < 2) return 'Họ tên phải có ít nhất 2 ký tự';
    return null;
  }

  static String? phone(String? value) {
    final phone = value?.trim() ?? '';
    if (phone.isEmpty) return null;
    if (!_phonePattern.hasMatch(phone)) {
      return 'Số điện thoại không hợp lệ';
    }
    return null;
  }
}
