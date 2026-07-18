import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
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
  String? _photoUrl;
  bool _photoBusy = false;
  bool _showPassword = false;

  @override
  void initState() {
    super.initState();
    _originalEmail = widget.profile?['email'] ?? '';
    _nameCtrl = TextEditingController(text: widget.profile?['full_name'] ?? '');
    _emailCtrl = TextEditingController(text: _originalEmail);
    _phoneCtrl = TextEditingController(text: widget.profile?['phone'] ?? '');
    _photoUrl = widget.profile?['profile_picture_url'] as String?;
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

  Future<void> _pickPhoto() async {
    final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery, maxWidth: 512, imageQuality: 80);
    if (picked == null) return;

    setState(() => _photoBusy = true);
    try {
      final bytes = await picked.readAsBytes();
      final ext =
          picked.path.contains('.') ? picked.path.split('.').last : 'jpg';
      final url = await SupabaseService.uploadProfilePicture(
          bytes, ext.length <= 4 ? ext : 'jpg');
      if (mounted) setState(() => _photoUrl = url);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
    if (mounted) setState(() => _photoBusy = false);
  }

  Future<void> _confirmRemovePhoto() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Photo'),
        content:
            const Text('Are you sure you want to remove your profile photo?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) await _removePhoto();
  }

  Future<void> _removePhoto() async {
    setState(() => _photoBusy = true);
    try {
      await SupabaseService.removeProfilePicture();
      if (mounted) setState(() => _photoUrl = null);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
    if (mounted) setState(() => _photoBusy = false);
  }

  bool _isStrongPassword(String password) => password.length >= 8;

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
            Center(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(
                    radius: 44,
                    backgroundColor: AppColors.rose.withValues(alpha: 0.15),
                    backgroundImage: _photoUrl != null
                        ? CachedNetworkImageProvider(_photoUrl!, maxWidth: 400)
                        : null,
                    child: _photoBusy
                        ? const CircularProgressIndicator(color: AppColors.rose)
                        : (_photoUrl == null
                            ? Text(
                                _nameCtrl.text.isNotEmpty
                                    ? _nameCtrl.text[0].toUpperCase()
                                    : 'U',
                                style: const TextStyle(
                                    color: AppColors.roseDeep,
                                    fontSize: 30,
                                    fontWeight: FontWeight.w700))
                            : null),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: _photoBusy ? null : _pickPhoto,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.rose,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.white, width: 2),
                        ),
                        child: const Icon(Icons.camera_alt,
                            color: Colors.white, size: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_photoUrl != null) ...[
              const SizedBox(height: 6),
              Center(
                child: TextButton.icon(
                  onPressed: _photoBusy ? null : _confirmRemovePhoto,
                  icon: const Icon(Icons.delete_outline,
                      color: Colors.red, size: 18),
                  label: const Text('Remove Photo',
                      style: TextStyle(color: Colors.red)),
                ),
              ),
            ],
            const SizedBox(height: 16),
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
