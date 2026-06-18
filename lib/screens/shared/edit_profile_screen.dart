import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
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
    _newPasswordCtrl.dispose();
    super.dispose();
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
