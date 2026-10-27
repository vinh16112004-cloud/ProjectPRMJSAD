import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/auth_validators.dart';
import '../viewmodels/auth_viewmodel.dart';

enum _ResetStep { email, otp, newPassword, completed }

class ForgotPasswordView extends ConsumerStatefulWidget {
  const ForgotPasswordView({super.key});

  @override
  ConsumerState<ForgotPasswordView> createState() => _ForgotPasswordViewState();
}

class _ForgotPasswordViewState extends ConsumerState<ForgotPasswordView> {
  final _emailFormKey = GlobalKey<FormState>();
  final _otpFormKey = GlobalKey<FormState>();
  final _passwordFormKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  _ResetStep _step = _ResetStep.email;
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;
  String? _generatedOtpPreview;

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _requestOtp() async {
    if (!(_emailFormKey.currentState?.validate() ?? true)) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final otpCode = await ref
          .read(authViewModelProvider)
          .requestPasswordResetOtp(_emailController.text);
      if (mounted) {
        setState(() {
          _generatedOtpPreview = otpCode;
          _step = _ResetStep.otp;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _errorMessage = authErrorMessage(error));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyOtp() async {
    if (!(_otpFormKey.currentState?.validate() ?? true)) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await ref
          .read(authViewModelProvider)
          .verifyPasswordResetOtp(
            email: _emailController.text,
            otp: _otpController.text,
          );
      if (mounted) {
        setState(() => _step = _ResetStep.newPassword);
      }
    } catch (error) {
      if (mounted) setState(() => _errorMessage = authErrorMessage(error));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submitNewPassword() async {
    if (!(_passwordFormKey.currentState?.validate() ?? true)) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await ref
          .read(authViewModelProvider)
          .resetPasswordWithOtp(
            email: _emailController.text,
            otp: _otpController.text,
            newPassword: _newPasswordController.text,
          );
      if (mounted) {
        setState(() => _step = _ResetStep.completed);
      }
    } catch (error) {
      if (mounted) setState(() => _errorMessage = authErrorMessage(error));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quên mật khẩu')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_step != _ResetStep.completed) ...[
                      _buildStepIndicator(context),
                      const SizedBox(height: 20),
                    ],
                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    switch (_step) {
                      _ResetStep.email => _buildEmailStep(),
                      _ResetStep.otp => _buildOtpStep(context),
                      _ResetStep.newPassword => _buildNewPasswordStep(),
                      _ResetStep.completed => _buildSuccess(),
                    },
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepIndicator(BuildContext context) {
    final activeIndex = switch (_step) {
      _ResetStep.email => 0,
      _ResetStep.otp => 1,
      _ResetStep.newPassword => 2,
      _ResetStep.completed => 3,
    };

    Widget buildBadge(int index, String label) {
      final isDone = index < activeIndex;
      final isCurrent = index == activeIndex;
      final colors = Theme.of(context).colorScheme;

      return Expanded(
        child: Column(
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: isDone || isCurrent
                  ? colors.primary
                  : colors.surfaceContainerHighest,
              foregroundColor: isDone || isCurrent
                  ? colors.onPrimary
                  : colors.onSurfaceVariant,
              child: isDone
                  ? const Icon(Icons.check, size: 16)
                  : Text('${index + 1}', style: const TextStyle(fontSize: 12)),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      );
    }

    return Row(
      children: [
        buildBadge(0, 'Nhập Email'),
        buildBadge(1, 'Mã OTP'),
        buildBadge(2, 'Mật khẩu mới'),
      ],
    );
  }

  Widget _buildEmailStep() {
    return Form(
      key: _emailFormKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.lock_reset, size: 56, color: Colors.blue),
          const SizedBox(height: 16),
          const Text(
            'Bước 1: Nhập email đã đăng ký để nhận mã OTP xác thực đặt lại mật khẩu.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.email_outlined),
              border: OutlineInputBorder(),
            ),
            validator: AuthValidators.email,
            onFieldSubmitted: (_) => _isLoading ? null : _requestOtp(),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _isLoading ? null : _requestOtp,
            child: _isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('Nhận mã OTP'),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildOtpStep(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Form(
      key: _otpFormKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.verified_user_outlined, size: 56, color: Colors.blue),
          const SizedBox(height: 16),
          Text(
            'Bước 2: Nhập mã OTP gồm 6 chữ số đã gửi tới ${_emailController.text.trim()}.',
            textAlign: TextAlign.center,
          ),
          if (_generatedOtpPreview != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: colors.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Mã OTP xác thực của bạn: $_generatedOtpPreview',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colors.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          TextFormField(
            controller: _otpController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            decoration: const InputDecoration(
              labelText: 'Mã OTP xác thực',
              prefixIcon: Icon(Icons.pin_outlined),
              border: OutlineInputBorder(),
              counterText: '',
            ),
            validator: AuthValidators.otp,
            onFieldSubmitted: (_) => _isLoading ? null : _verifyOtp(),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _isLoading ? null : _verifyOtp,
            child: _isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('Xác thực OTP'),
                  ),
          ),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: _isLoading
                    ? null
                    : () => setState(() {
                        _errorMessage = null;
                        _step = _ResetStep.email;
                      }),
                child: const Text('Đổi email'),
              ),
              TextButton(
                onPressed: _isLoading ? null : _requestOtp,
                child: const Text('Gửi lại mã OTP'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNewPasswordStep() {
    return Form(
      key: _passwordFormKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.password_outlined, size: 56, color: Colors.blue),
          const SizedBox(height: 16),
          const Text(
            'Bước 3: Tạo mật khẩu mới và xác nhận cho tài khoản của bạn.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _newPasswordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: 'Mật khẩu mới',
              prefixIcon: const Icon(Icons.lock_outline),
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                tooltip: 'Hiện hoặc ẩn mật khẩu',
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            validator: AuthValidators.password,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _confirmPasswordController,
            obscureText: _obscurePassword,
            decoration: const InputDecoration(
              labelText: 'Xác nhận mật khẩu mới',
              prefixIcon: Icon(Icons.lock_reset),
              border: OutlineInputBorder(),
            ),
            validator: (value) => AuthValidators.confirmPassword(
              value,
              _newPasswordController.text,
            ),
            onFieldSubmitted: (_) => _isLoading ? null : _submitNewPassword(),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _isLoading ? null : _submitNewPassword,
            child: _isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('Xác nhận đổi mật khẩu'),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccess() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.mark_email_read_outlined,
          size: 64,
          color: Colors.green,
        ),
        const SizedBox(height: 16),
        Text(
          'Đặt lại mật khẩu thành công',
          style: Theme.of(context).textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          'Yêu cầu tạo mật khẩu mới cho ${_emailController.text.trim()} đã được xác thực bằng OTP. Liên kết đồng bộ bảo mật cũng đã được gửi tới email của bạn.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Quay lại đăng nhập'),
        ),
      ],
    );
  }
}
