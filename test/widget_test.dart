import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:untitled1/viewmodels/auth_viewmodel.dart';
import 'package:untitled1/views/forgot_password_view.dart';
import 'package:untitled1/views/login_view.dart';
import 'package:untitled1/views/register_view.dart';

class MockAuthViewModel extends Mock implements AuthViewModel {}

void main() {
  late MockAuthViewModel auth;

  setUp(() {
    auth = MockAuthViewModel();
  });

  Future<void> pumpView(WidgetTester tester, Widget view) {
    return tester.pumpWidget(
      ProviderScope(
        overrides: [authViewModelProvider.overrideWithValue(auth)],
        child: MaterialApp(home: view),
      ),
    );
  }

  testWidgets('login validates required fields', (tester) async {
    await pumpView(tester, const LoginView());

    await tester.tap(find.widgetWithText(FilledButton, 'Đăng nhập'));
    await tester.pump();

    expect(find.text('Vui lòng nhập email'), findsOneWidget);
    expect(find.text('Vui lòng nhập mật khẩu'), findsOneWidget);
    verifyNever(
      () => auth.signIn(any(), any(), rememberMe: any(named: 'rememberMe')),
    );
  });

  testWidgets('login enables remember-me preference when selected', (
    tester,
  ) async {
    when(() => auth.signIn(any(), any(), rememberMe: any(named: 'rememberMe')))
        .thenAnswer((_) async => true);
    await pumpView(tester, const LoginView());

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'reader@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Mật khẩu'),
      '123456',
    );
    await tester.tap(find.text('Ghi nhớ đăng nhập'));
    await tester.tap(find.widgetWithText(FilledButton, 'Đăng nhập'));
    await tester.pump();

    verify(() => auth.signIn('reader@example.com', '123456', rememberMe: true))
        .called(1);
  });

  testWidgets('login does not remember session by default', (tester) async {
    when(() => auth.signIn(any(), any(), rememberMe: any(named: 'rememberMe')))
        .thenAnswer((_) async => true);
    await pumpView(tester, const LoginView());

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'reader@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Mật khẩu'),
      '123456',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Đăng nhập'));
    await tester.pump();

    verify(() => auth.signIn('reader@example.com', '123456', rememberMe: false))
        .called(1);
  });

  testWidgets('registration requires accepted terms', (tester) async {
    await pumpView(tester, const RegisterView());

    await tester.tap(find.widgetWithText(FilledButton, 'Đăng ký'));
    await tester.pump();

    expect(
      find.text('Bạn cần đồng ý với điều khoản để tạo tài khoản'),
      findsOneWidget,
    );
    verifyNever(
      () => auth.register(
        fullName: any(named: 'fullName'),
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    );
  });

  testWidgets('Google registration requires accepted terms', (tester) async {
    await pumpView(tester, const RegisterView());

    final button = find.widgetWithText(OutlinedButton, 'Đăng ký bằng Google');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump();

    expect(
      find.text('Bạn cần đồng ý với điều khoản để tạo tài khoản'),
      findsOneWidget,
    );
    verifyNever(() => auth.signInWithGoogle());
  });

  testWidgets('Google registration uses shared Google authentication', (
    tester,
  ) async {
    when(() => auth.signInWithGoogle()).thenAnswer((_) async => true);
    await pumpView(tester, const RegisterView());

    await tester.tap(
      find.text('Tôi đồng ý với Điều khoản sử dụng và Chính sách bảo mật'),
    );
    await tester.pump();
    final button = find.widgetWithText(OutlinedButton, 'Đăng ký bằng Google');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump();

    verify(() => auth.signInWithGoogle()).called(1);
    await tester.pumpAndSettle();
    expect(find.byType(RegisterView), findsNothing);
  });

  testWidgets(
    'forgot password completes Email -> OTP -> New Password flow',
    (tester) async {
      when(
        () => auth.requestPasswordResetOtp(any()),
      ).thenAnswer((_) async => '654321');
      when(
        () => auth.verifyPasswordResetOtp(
          email: any(named: 'email'),
          otp: any(named: 'otp'),
        ),
      ).thenAnswer((_) async => true);
      when(
        () => auth.resetPasswordWithOtp(
          email: any(named: 'email'),
          otp: any(named: 'otp'),
          newPassword: any(named: 'newPassword'),
        ),
      ).thenAnswer((_) async {});

      await pumpView(tester, const ForgotPasswordView());

      // Bước 1: Nhập Email -> Nhận mã OTP
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'reader@example.com',
      );
      await tester.tap(find.text('Nhận mã OTP'));
      await tester.pump();

      verify(
        () => auth.requestPasswordResetOtp('reader@example.com'),
      ).called(1);
      expect(find.textContaining('654321'), findsOneWidget);

      // Bước 2: Nhập mã OTP -> Xác thực OTP
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Mã OTP xác thực'),
        '654321',
      );
      await tester.tap(find.text('Xác thực OTP'));
      await tester.pump();

      verify(
        () => auth.verifyPasswordResetOtp(
          email: 'reader@example.com',
          otp: '654321',
        ),
      ).called(1);

      // Bước 3: Nhập mật khẩu mới & xác nhận -> Xác nhận đổi mật khẩu
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Mật khẩu mới'),
        'newpass123',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Xác nhận mật khẩu mới'),
        'newpass123',
      );
      await tester.tap(find.text('Xác nhận đổi mật khẩu'));
      await tester.pump();

      verify(
        () => auth.resetPasswordWithOtp(
          email: 'reader@example.com',
          otp: '654321',
          newPassword: 'newpass123',
        ),
      ).called(1);
      expect(find.text('Đặt lại mật khẩu thành công'), findsOneWidget);
    },
  );
}
