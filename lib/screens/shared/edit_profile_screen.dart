import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/supabase_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/common_widgets.dart';

// ── Edit Profile ──────────────────────────────────────────────────
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
  final _newPasswordCtrl = TextEditingController();
  late final String _originalEmail;
  bool _loading = false;
  String? _photoUrl;
  bool _photoBusy = false;

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
    _newPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picked = await ImagePicker()
        .pickImage(source: ImageSource.gallery, maxWidth: 512, imageQuality: 80);
    if (picked == null) return;

    setState(() => _photoBusy = true);
    try {
      final bytes = await picked.readAsBytes();
      final ext = picked.path.contains('.') ? picked.path.split('.').last : 'jpg';
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

  Future<void> _save() async {
    final newEmail = _emailCtrl.text.trim();
    final newPassword = _newPasswordCtrl.text;
    if (newEmail.isEmpty || !newEmail.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid email address.')));
      return;
    }
    if (newPassword.isNotEmpty && newPassword.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('New password must be at least 6 characters.')));
      return;
    }

    setState(() => _loading = true);
    final messages = <String>[];
    try {
      await SupabaseService.updateProfile({
        'full_name': _nameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'email': newEmail,
      });

      final emailChanged = newEmail != _originalEmail;
      if (emailChanged) {
        try {
          await SupabaseService.client.auth.updateUser(UserAttributes(email: newEmail));
          messages.add('Check your new email to confirm the change.');
        } catch (e) {
          messages.add('Could not update login email: $e');
        }
      }

      if (newPassword.isNotEmpty) {
        try {
          await SupabaseService.client.auth.updateUser(UserAttributes(password: newPassword));
          messages.add('Password updated.');
        } catch (e) {
          messages.add('Could not update password: $e');
        }
      }

      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(messages.isEmpty ? 'Profile updated!' : messages.join(' '))));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Center(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(
                    radius: 44,
                    backgroundColor: AppColors.rose.withValues(alpha: 0.15),
                    backgroundImage:
                        _photoUrl != null ? NetworkImage(_photoUrl!) : null,
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
              TextButton.icon(
                onPressed: _photoBusy ? null : _removePhoto,
                icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                label: const Text('Remove Photo', style: TextStyle(color: Colors.red)),
              ),
            ],
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Full Name',
                prefixIcon: Icon(Icons.person_outline, color: AppColors.textLight)),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.email_outlined, color: AppColors.textLight)),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                prefixIcon: Icon(Icons.phone_outlined, color: AppColors.textLight)),
            ),
            const SizedBox(height: 24),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Change Password',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textDark)),
            ),
            const SizedBox(height: 4),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Leave blank to keep your current password.',
                style: TextStyle(color: AppColors.textLight, fontSize: 12)),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _newPasswordCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'New Password',
                prefixIcon: Icon(Icons.lock_outline, color: AppColors.textLight)),
            ),
            const SizedBox(height: 24),
            TBButton(label: 'Save Changes', onPressed: _save, loading: _loading),
          ],
        ),
      ),
    );
  }
}
