import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../services/supabase_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/common_widgets.dart';

class EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic>? profile;

  const EditProfileScreen({super.key, this.profile});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _phoneCtrl;

  final _oldPasswordCtrl = TextEditingController();
  final _newPasswordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();

  late final String _originalEmail;
  bool _loading = false;
  bool _showPassword = false;

  @override
  void initState() {
    super.initState();
    _originalEmail = widget.profile?['email'] ?? '';
    _nameCtrl = TextEditingController(text: widget.profile?['full_name'] ?? '');
    _emailCtrl = TextEditingController(text: _originalEmail);
    _phoneCtrl = TextEditingController(text: widget.profile?['phone'] ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _oldPasswordCtrl.dispose();
    _newPasswordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  bool _isStrongPassword(String password) {
    return password.length >= 8;
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final newEmail = _emailCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();

    final oldPassword = _oldPasswordCtrl.text;
    final newPassword = _newPasswordCtrl.text;
    final confirmPassword = _confirmPasswordCtrl.text;

    if (name.isEmpty) {
      _showSnack('Please enter your full name.');
      return;
    }

    if (newEmail.isEmpty || !newEmail.contains('@')) {
      _showSnack('Please enter a valid email address.');
      return;
    }

    final changingPassword = oldPassword.isNotEmpty ||
        newPassword.isNotEmpty ||
        confirmPassword.isNotEmpty;

    if (changingPassword) {
      if (oldPassword.isEmpty) {
        _showSnack('Please enter your current password.');
        return;
      }

      if (!_isStrongPassword(newPassword)) {
        _showSnack('New password must be at least 8 characters.');
        return;
      }

      if (newPassword != confirmPassword) {
        _showSnack('New password and confirm password do not match.');
        return;
      }
    }

    setState(() => _loading = true);

    try {
      await SupabaseService.updateProfile({
        'full_name': name,
        'phone': phone,
        'email': newEmail,
      });

      final messages = <String>[];

      if (newEmail != _originalEmail) {
        await SupabaseService.client.auth.updateUser(
          UserAttributes(email: newEmail),
        );
        messages.add('Check your new email to confirm the change.');
      }

      if (changingPassword) {
        final currentEmail =
            SupabaseService.client.auth.currentUser?.email ?? _originalEmail;

        final signInResult =
            await SupabaseService.client.auth.signInWithPassword(
          email: currentEmail,
          password: oldPassword,
        );

        if (signInResult.user == null) {
          throw Exception('Current password is incorrect.');
        }

        await SupabaseService.client.auth.updateUser(
          UserAttributes(password: newPassword),
        );

        messages.add('Password updated.');
      }

      if (!mounted) return;

      context.pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            messages.isEmpty
                ? 'Profile updated successfully!'
                : messages.join(' '),
          ),
          backgroundColor: AppColors.sage,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _showSnack('Error: $e', isError: true);
    }

    if (mounted) setState(() => _loading = false);
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : AppColors.rose,
      ),
    );
  }

  Widget _sectionTitle(String title, String subtitle) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: const TextStyle(
              color: AppColors.textLight,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: AppColors.textLight),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: AppColors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide:
            BorderSide(color: AppColors.textLight.withValues(alpha: 0.2)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide:
            BorderSide(color: AppColors.textLight.withValues(alpha: 0.18)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.rose, width: 1.4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textDark),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Edit Profile',
          style: TextStyle(
            color: AppColors.textDark,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TBCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 34,
                    backgroundColor: AppColors.rose.withValues(alpha: 0.18),
                    child: Text(
                      _nameCtrl.text.trim().isNotEmpty
                          ? _nameCtrl.text.trim()[0].toUpperCase()
                          : 'U',
                      style: const TextStyle(
                        color: AppColors.roseDeep,
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Update your account details',
                    style: TextStyle(
                      color: AppColors.textMid,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            _sectionTitle(
              'Personal Information',
              'Keep your profile details accurate and up to date.',
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nameCtrl,
              decoration: _inputDecoration(
                label: 'Full Name',
                icon: Icons.person_outline,
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: _inputDecoration(
                label: 'Email Address',
                icon: Icons.email_outlined,
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: _inputDecoration(
                label: 'Phone Number',
                icon: Icons.phone_outlined,
              ),
            ),
            const SizedBox(height: 24),
            _sectionTitle(
              'Change Password',
              'Enter your current password before setting a new one.',
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _oldPasswordCtrl,
              obscureText: !_showPassword,
              decoration: _inputDecoration(
                label: 'Current Password',
                icon: Icons.lock_outline,
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _newPasswordCtrl,
              obscureText: !_showPassword,
              decoration: _inputDecoration(
                label: 'New Password',
                icon: Icons.lock_reset_outlined,
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _confirmPasswordCtrl,
              obscureText: !_showPassword,
              decoration: _inputDecoration(
                label: 'Confirm New Password',
                icon: Icons.verified_user_outlined,
                suffixIcon: IconButton(
                  icon: Icon(
                    _showPassword ? Icons.visibility_off : Icons.visibility,
                    color: AppColors.textLight,
                  ),
                  onPressed: () {
                    setState(() => _showPassword = !_showPassword);
                  },
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Password must be at least 8 characters. Leave password fields blank if you do not want to change it.',
              style: TextStyle(
                color: AppColors.textLight,
                fontSize: 12,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 26),
            TBButton(
              label: 'Save Changes',
              onPressed: _save,
              loading: _loading,
            ),
          ],
        ),
      ),
    );
  }
}
