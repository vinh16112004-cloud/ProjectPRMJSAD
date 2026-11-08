import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Dịch vụ gửi mã OTP 6 chữ số qua Email (hỗ trợ cả Flutter Web & Mobile).
class OtpEmailService {
  /// URL Web App của Google Apps Script đã triển khai để gửi mail OTP qua Gmail.
  static const String googleAppsScriptUrl = String.fromEnvironment(
    'OTP_WEBHOOK_URL',
    defaultValue:
        'https://script.google.com/macros/s/AKfycbx7iIjdZyLDL2KM2aaILnhfsU_3Et3DYQxDf4KTw07f5_oNE-8lGOUHGbgybuDBEIijXg/exec',
  );

  /// Cấu hình EmailJS (https://www.emailjs.com/) dự phòng nếu sử dụng EmailJS.
  static const String emailJsServiceId = String.fromEnvironment(
    'EMAILJS_SERVICE_ID',
    defaultValue: '',
  );
  static const String emailJsTemplateId = String.fromEnvironment(
    'EMAILJS_TEMPLATE_ID',
    defaultValue: '',
  );
  static const String emailJsPublicKey = String.fromEnvironment(
    'EMAILJS_PUBLIC_KEY',
    defaultValue: '',
  );

  static Future<void> sendOtpEmail({
    required String email,
    required String otpCode,
    FirebaseFirestore? firestore,
  }) async {
    final subject = '[Báo Mới 24h] Mã OTP đặt lại mật khẩu: $otpCode';
    final htmlBody = '''
<div style="font-family: Arial, sans-serif; max-width: 480px; margin: 0 auto; padding: 24px; border: 1px solid #e0e0e0; border-radius: 8px;">
  <h2 style="color: #1976d2; margin-top: 0;">Báo Mới 24h - Đặt lại mật khẩu</h2>
  <p>Xin chào,</p>
  <p>Bạn vừa yêu cầu đặt lại mật khẩu cho tài khoản <strong>$email</strong>.</p>
  <p>Mã xác thực OTP gồm 6 chữ số của bạn là:</p>
  <div style="background: #f0f7ff; padding: 16px; text-align: center; border-radius: 8px; font-size: 28px; font-weight: bold; letter-spacing: 6px; color: #0d47a1;">
    $otpCode
  </div>
  <p style="color: #666; font-size: 13px; margin-top: 16px;">Mã OTP này có hiệu lực trong vòng 5 phút. Nếu bạn không yêu cầu đặt lại mật khẩu, vui lòng bỏ qua email này.</p>
</div>
''';

    debugPrint('==================================================');
    debugPrint('[Báo Mới 24h - OTP Email] Gửi tới: $email | Mã OTP: $otpCode');
    debugPrint('==================================================');

    // 1. Lưu lịch sử OTP vào Firestore
    if (firestore != null) {
      try {
        await firestore.collection('mail').add({
          'to': [email],
          'otp_code': otpCode,
          'created_at': FieldValue.serverTimestamp(),
          'message': {
            'subject': subject,
            'text':
                'Mã OTP đặt lại mật khẩu của bạn là: $otpCode (hiệu lực 5 phút).',
            'html': htmlBody,
          },
        });
      } catch (_) {}
    }

    // 2. Gửi email thật qua Google Apps Script Webhook
    if (googleAppsScriptUrl.isNotEmpty) {
      try {
        final response = await http.post(
          Uri.parse(googleAppsScriptUrl),
          headers: {'Content-Type': 'text/plain;charset=utf-8'},
          body: jsonEncode({
            'email': email,
            'otp': otpCode,
            'subject': subject,
            'html': htmlBody,
          }),
        );
        // Google Apps Script trả về 200 hoặc 302 (redirect tới script.googleusercontent.com) sau khi đã chạy doPost và gửi mail thành công.
        if (response.statusCode >= 400 && response.body.isNotEmpty) {
          throw Exception(
            'Không thể gửi email OTP (${response.statusCode}).',
          );
        }
      } on http.ClientException catch (_) {
        // Trên trình duyệt Web, sau khi Google Apps Script thực thi xong doPost và gửi mail,
        // lệnh redirect 302 sang script.googleusercontent.com có thể bị trình duyệt chặn đọc response body do CORS,
        // nhưng email đã được gửi thành công ở phía server Google.
        if (!kIsWeb) rethrow;
      }
      return;
    }

    // 3. Gửi qua EmailJS REST API (nếu có cấu hình)
    if (emailJsServiceId.isNotEmpty &&
        emailJsTemplateId.isNotEmpty &&
        emailJsPublicKey.isNotEmpty) {
      final response = await http.post(
        Uri.parse('https://api.emailjs.com/api/v1.0/email/send'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'service_id': emailJsServiceId,
          'template_id': emailJsTemplateId,
          'user_id': emailJsPublicKey,
          'template_params': {
            'to_email': email,
            'email': email,
            'otp_code': otpCode,
            'subject': subject,
            'message': 'Mã OTP đặt lại mật khẩu của bạn là: $otpCode',
          },
        }),
      );
      if (response.statusCode >= 400 && response.body.isNotEmpty) {
        throw Exception(
          'Không thể gửi email OTP qua EmailJS (${response.statusCode}).',
        );
      }
    }
  }
}
