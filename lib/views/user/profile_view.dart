import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/auth_validators.dart';
import '../../models/user_model.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/profile_viewmodel.dart';

class ProfileView extends ConsumerStatefulWidget {
  const ProfileView({super.key});

  @override
  ConsumerState<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends ConsumerState<ProfileView> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();

  final Set<String> _favoriteCategories = {};
  XFile? _avatarFile;
  Uint8List? _avatarPreview;
  bool _initialized = false;
  bool _isSaving = false;
  bool _isPickingAvatar = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  bool get _hasPasswordProvider {
    final user = FirebaseAuth.instance.currentUser;
    return user?.providerData.any((info) => info.providerId == 'password') ??
        false;
  }

  void _initialize(UserModel profile) {
    if (_initialized) return;
    _nameController.text = profile.fullName;
    _phoneController.text = profile.phone;
    _emailController.text =
        FirebaseAuth.instance.currentUser?.email ?? profile.email;
    _favoriteCategories.addAll(profile.favoriteCategories);
    _initialized = true;
  }

  Future<void> _pickAvatar() async {
    setState(() => _isPickingAvatar = true);
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 256,
        maxHeight: 256,
        imageQuality: 70,
      );
      if (file == null) return;
      if (await file.length() > ProfileViewModel.maxAvatarBytes) {
        throw Exception('Ảnh đại diện sau khi nén không được lớn hơn 500 KB.');
      }
      final bytes = await file.readAsBytes();
      if (mounted) {
        setState(() {
          _avatarFile = file;
          _avatarPreview = bytes;
        });
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(authErrorMessage(error))));
      }
    } finally {
      if (mounted) setState(() => _isPickingAvatar = false);
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      await ref
          .read(profileViewModelProvider)
          .updateProfile(
            fullName: _nameController.text,
            phone: _phoneController.text,
            favoriteCategories: _favoriteCategories.toList(),
            avatarFile: _avatarFile,
          );
      if (mounted) {
        setState(() => _avatarFile = null);
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Đã cập nhật hồ sơ.')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(authErrorMessage(error))));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _showChangePasswordDialog() async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (context) => const _ChangePasswordDialog(),
    );
    if (changed == true && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Đã đổi mật khẩu.')));
    }
  }

  Future<void> _showChangeEmailDialog() async {
    final requested = await showDialog<bool>(
      context: context,
      builder: (context) =>
          _ChangeEmailDialog(currentEmail: _emailController.text),
    );
    if (requested == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Hãy kiểm tra địa chỉ email mới để xác minh thay đổi.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateChangesProvider);
    final user = authState.valueOrNull ?? FirebaseAuth.instance.currentUser;
    if (authState.isLoading && user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Vui lòng đăng nhập lại.')),
      );
    }

    final profileState = ref.watch(userProfileProvider(user.uid));
    return Scaffold(
      appBar: AppBar(title: const Text('Hồ sơ cá nhân')),
      body: SafeArea(
        child: profileState.when(
          data: (profile) {
            if (profile == null) {
              return const Center(child: Text('Không tìm thấy hồ sơ.'));
            }
            _initialize(profile);
            return _buildProfile(profile);
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Không thể tải hồ sơ: $error'),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfile(UserModel profile) {
    ImageProvider? avatarImage;
    if (_avatarPreview != null) {
      avatarImage = MemoryImage(_avatarPreview!);
    } else if (profile.avatarUrl.startsWith('data:image/')) {
      try {
        avatarImage = MemoryImage(
          base64Decode(profile.avatarUrl.split(',').last),
        );
      } on FormatException {
        avatarImage = null;
      }
    } else if (profile.avatarUrl.isNotEmpty) {
      avatarImage = NetworkImage(profile.avatarUrl);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      CircleAvatar(
                        radius: 56,
                        backgroundImage: avatarImage,
                        child: avatarImage == null
                            ? Text(
                                profile.fullName.isEmpty
                                    ? '?'
                                    : profile.fullName[0].toUpperCase(),
                                style: const TextStyle(fontSize: 36),
                              )
                            : null,
                      ),
                      IconButton.filled(
                        tooltip: 'Đổi ảnh đại diện',
                        onPressed: _isSaving || _isPickingAvatar
                            ? null
                            : _pickAvatar,
                        icon: _isPickingAvatar
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.camera_alt_outlined),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _nameController,
                  enabled: !_isSaving,
                  decoration: const InputDecoration(
                    labelText: 'Họ tên',
                    prefixIcon: Icon(Icons.person_outline),
                    border: OutlineInputBorder(),
                  ),
                  validator: AuthValidators.fullName,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _phoneController,
                  enabled: !_isSaving,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Số điện thoại (không bắt buộc)',
                    prefixIcon: Icon(Icons.phone_outlined),
                    border: OutlineInputBorder(),
                  ),
                  validator: AuthValidators.phone,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    prefixIcon: const Icon(Icons.email_outlined),
                    border: const OutlineInputBorder(),
                    suffixIcon: _hasPasswordProvider
                        ? IconButton(
                            tooltip: 'Đổi email',
                            onPressed: _isSaving
                                ? null
                                : _showChangeEmailDialog,
                            icon: const Icon(Icons.edit_outlined),
                          )
                        : null,
                  ),
                ),
                if (!_hasPasswordProvider)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'Email và mật khẩu được quản lý bởi tài khoản Google.',
                    ),
                  ),
                const SizedBox(height: 24),
                Text(
                  'Danh mục quan tâm',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                ref
                    .watch(activeCategoriesProvider)
                    .when(
                      data: (categories) {
                        if (categories.isEmpty) {
                          return const Text('Chưa có danh mục nào.');
                        }
                        return Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: categories.map((category) {
                            final selected = _favoriteCategories.contains(
                              category.id,
                            );
                            return FilterChip(
                              label: Text(category.name),
                              selected: selected,
                              onSelected: _isSaving
                                  ? null
                                  : (value) => setState(() {
                                      if (value) {
                                        _favoriteCategories.add(category.id);
                                      } else {
                                        _favoriteCategories.remove(category.id);
                                      }
                                    }),
                            );
                          }).toList(),
                        );
                      },
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (error, stackTrace) =>
                          Text('Không thể tải danh mục: $error'),
                    ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _isSaving ? null : _saveProfile,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('Lưu thay đổi'),
                  ),
                ),
                if (_hasPasswordProvider) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _isSaving ? null : _showChangePasswordDialog,
                    icon: const Icon(Icons.lock_reset),
                    label: const Text('Đổi mật khẩu'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChangePasswordDialog extends ConsumerStatefulWidget {
  const _ChangePasswordDialog();

  @override
  ConsumerState<_ChangePasswordDialog> createState() =>
      _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends ConsumerState<_ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await ref
          .read(authViewModelProvider)
          .changePassword(
            currentPassword: _currentController.text,
            newPassword: _newController.text,
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) setState(() => _error = authErrorMessage(error));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Đổi mật khẩu'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_error != null) ...[
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                const SizedBox(height: 12),
              ],
              TextFormField(
                controller: _currentController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Mật khẩu hiện tại',
                ),
                validator: (value) => value == null || value.isEmpty
                    ? 'Vui lòng nhập mật khẩu hiện tại'
                    : null,
              ),
              TextFormField(
                controller: _newController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Mật khẩu mới'),
                validator: AuthValidators.password,
              ),
              TextFormField(
                controller: _confirmController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Xác nhận mật khẩu mới',
                ),
                validator: (value) =>
                    AuthValidators.confirmPassword(value, _newController.text),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(false),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: _isLoading ? null : _submit,
          child: _isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Xác nhận'),
        ),
      ],
    );
  }
}

class _ChangeEmailDialog extends ConsumerStatefulWidget {
  final String currentEmail;

  const _ChangeEmailDialog({required this.currentEmail});

  @override
  ConsumerState<_ChangeEmailDialog> createState() => _ChangeEmailDialogState();
}

class _ChangeEmailDialogState extends ConsumerState<_ChangeEmailDialog> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  late final TextEditingController _emailController;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.currentEmail);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_emailController.text.trim() == widget.currentEmail) {
      setState(() => _error = 'Email mới phải khác email hiện tại.');
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await ref
          .read(authViewModelProvider)
          .requestEmailChange(
            newEmail: _emailController.text,
            currentPassword: _passwordController.text,
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) setState(() => _error = authErrorMessage(error));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Đổi email'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Firebase sẽ gửi liên kết xác minh đến email mới trước khi thay đổi có hiệu lực.',
              ),
              const SizedBox(height: 16),
              if (_error != null) ...[
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                const SizedBox(height: 12),
              ],
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email mới'),
                validator: AuthValidators.email,
              ),
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Mật khẩu hiện tại',
                ),
                validator: (value) => value == null || value.isEmpty
                    ? 'Vui lòng nhập mật khẩu hiện tại'
                    : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(false),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: _isLoading ? null : _submit,
          child: _isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Gửi xác minh'),
        ),
      ],
    );
  }
}
