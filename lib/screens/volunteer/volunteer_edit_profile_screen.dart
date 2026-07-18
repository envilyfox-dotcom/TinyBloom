import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/supabase_service.dart';
import '../../utils/app_theme.dart';

class VolunteerEditProfileScreen extends StatefulWidget {
  final Map<String, dynamic>? profile;
  const VolunteerEditProfileScreen({super.key, this.profile});

  @override
  State<VolunteerEditProfileScreen> createState() =>
      _VolunteerEditProfileScreenState();
}

class _VolunteerEditProfileScreenState
    extends State<VolunteerEditProfileScreen> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _expertiseCtrl = TextEditingController();
  final _certificationCtrl = TextEditingController();
  final _currentPasswordCtrl = TextEditingController();
  final _newPasswordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();

  String _originalEmail = '';
  String? _photoUrl;
  bool _photoBusy = false;
  bool _saving = false;
  bool _loading = true;
  bool _showPassword = false;

  @override
  void initState() {
    super.initState();
    if (widget.profile != null) {
      _applyProfile(widget.profile!);
      _loading = false;
    } else {
      // Reached directly (URL navigation/refresh) without the `extra` map
      // that context.push() normally carries, so fetch the profile ourselves.
      _loadProfile();
    }
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await SupabaseService.getProfile();
      Map<String, dynamic>? volunteerProfile;
      try {
        volunteerProfile = await SupabaseService.getMyVolunteerProfile();
      } catch (_) {}
      _applyProfile({...?profile, ...?volunteerProfile});
    } catch (e) {
      if (mounted) _showSnack('Error loading profile: $e', isError: true);
    }
    if (mounted) setState(() => _loading = false);
  }

  void _applyProfile(Map<String, dynamic> profile) {
    _originalEmail = profile['email'] as String? ?? '';
    _nameCtrl.text = profile['full_name'] as String? ?? '';
    _emailCtrl.text = _originalEmail;
    _phoneCtrl.text = profile['phone'] as String? ?? '';
    _expertiseCtrl.text = profile['expertise'] as String? ?? '';
    _certificationCtrl.text = profile['certification'] as String? ?? '';
    _photoUrl = profile['profile_picture_url'] as String?;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _expertiseCtrl.dispose();
    _certificationCtrl.dispose();
    _currentPasswordCtrl.dispose();
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
      if (mounted) _showSnack('Error: $e', isError: true);
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
      if (mounted) _showSnack('Error: $e', isError: true);
    }
    if (mounted) setState(() => _photoBusy = false);
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final currentPassword = _currentPasswordCtrl.text;
    final newPassword = _newPasswordCtrl.text;
    final confirmPassword = _confirmPasswordCtrl.text;
    final wantsPasswordChange = currentPassword.isNotEmpty ||
        newPassword.isNotEmpty ||
        confirmPassword.isNotEmpty;

    if (name.isEmpty) {
      _showSnack('Full name cannot be empty.');
      return;
    }
    if (email.isEmpty || !email.contains('@')) {
      _showSnack('Please enter a valid email address.');
      return;
    }
    if (wantsPasswordChange) {
      if (currentPassword.isEmpty) {
        _showSnack('Please enter your current password.');
        return;
      }
      if (newPassword.length < 8) {
        _showSnack('New password must be at least 8 characters.');
        return;
      }
      if (newPassword != confirmPassword) {
        _showSnack('New password and confirmation do not match.');
        return;
      }
    }

    setState(() => _saving = true);
    try {
      await SupabaseService.updateProfile({
        'full_name': name,
        'email': email,
        'phone': _phoneCtrl.text.trim(),
      });

      await SupabaseService.updateVolunteerProfile({
        'expertise': _expertiseCtrl.text.trim(),
        'certification': _certificationCtrl.text.trim(),
      });

      String message = 'Profile updated!';
      if (email != _originalEmail) {
        await SupabaseService.client.auth
            .updateUser(UserAttributes(email: email));
        message =
            'Profile updated! Check your new email to confirm the change.';
      }

      if (wantsPasswordChange) {
        await SupabaseService.client.auth.signInWithPassword(
          email: SupabaseService.currentUser!.email!,
          password: currentPassword,
        );
        await SupabaseService.client.auth
            .updateUser(UserAttributes(password: newPassword));
        message = 'Profile and password updated!';
      }

      if (!mounted) return;
      context.pop();
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    } on AuthException catch (e) {
      _showSnack('Error: ${e.message}', isError: true);
    } catch (e) {
      _showSnack('Error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : AppColors.textLight,
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
          icon: const Icon(Icons.chevron_left,
              color: AppColors.textDark, size: 28),
          onPressed: () => context.pop(),
        ),
        title: Text('Edit Profile',
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: AppColors.textDark)),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.rose))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const SizedBox(height: 8),

                  // ── Avatar picker ─────────────────────────────────────
                  GestureDetector(
                    onTap: _photoBusy ? null : _pickPhoto,
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        CircleAvatar(
                          radius: 52,
                          backgroundColor:
                              AppColors.rose.withValues(alpha: 0.2),
                          backgroundImage:
                              _photoUrl != null && _photoUrl!.isNotEmpty
                                  ? CachedNetworkImageProvider(_photoUrl!,
                                      maxWidth: 400)
                                  : null,
                          child: _photoBusy
                              ? const CircularProgressIndicator(
                                  color: AppColors.rose)
                              : (_photoUrl == null || _photoUrl!.isEmpty
                                  ? const Icon(Icons.person,
                                      size: 52, color: AppColors.rose)
                                  : null),
                        ),
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.rose,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(Icons.camera_alt,
                              color: Colors.white, size: 14),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('Tap to change photo',
                      style: GoogleFonts.poppins(
                          fontSize: 12, color: AppColors.textLight)),
                  if (_photoUrl != null && _photoUrl!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    TextButton.icon(
                      onPressed: _photoBusy ? null : _confirmRemovePhoto,
                      icon: const Icon(Icons.delete_outline,
                          color: Colors.red, size: 18),
                      label: Text('Remove Photo',
                          style: GoogleFonts.poppins(color: Colors.red)),
                    ),
                  ],
                  const SizedBox(height: 24),

                  // ── Form card ──────────────────────────────────────────
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: AppColors.rose.withValues(alpha: 0.18)),
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Text('Personal Information',
                              style: GoogleFonts.poppins(
                                  color: AppColors.textDark,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14)),
                        ),
                        const SizedBox(height: 20),
                        _field('Full name', _nameCtrl),
                        const SizedBox(height: 12),
                        _field('Email', _emailCtrl,
                            keyboardType: TextInputType.emailAddress),
                        const SizedBox(height: 12),
                        _field('Phone number', _phoneCtrl,
                            keyboardType: TextInputType.phone),
                        const SizedBox(height: 12),
                        _field('Area of Expertise', _expertiseCtrl),
                        const SizedBox(height: 12),
                        _field('Certification/License', _certificationCtrl),
                        const SizedBox(height: 24),
                        _sectionTitle(
                          'Change Password',
                          'Enter your current password before setting a new one.',
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _currentPasswordCtrl,
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
                                _showPassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                color: AppColors.textLight,
                              ),
                              onPressed: () {
                                setState(() => _showPassword = !_showPassword);
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Password must be at least 8 characters. Leave password fields blank if you do not want to change it.',
                          style: GoogleFonts.poppins(
                            color: AppColors.textLight,
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 20),

                        // ── Save button ───────────────────────────────
                        ElevatedButton(
                          onPressed: _saving ? null : _save,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.rose,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          child: _saving
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : Text('Save Changes',
                                  style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w600)),
                        ),
                        const SizedBox(height: 8),

                        // ── Cancel button ─────────────────────────────
                        OutlinedButton(
                          onPressed: () => context.pop(),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textMid,
                            side: BorderSide(
                                color:
                                    AppColors.textLight.withValues(alpha: 0.4)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          child: Text('Cancel', style: GoogleFonts.poppins()),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
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
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: GoogleFonts.poppins(
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

  Widget _field(
    String label,
    TextEditingController ctrl, {
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.poppins(color: AppColors.textMid, fontSize: 12)),
        const SizedBox(height: 4),
        TextField(
          controller: ctrl,
          maxLines: maxLines,
          keyboardType: keyboardType,
          style: GoogleFonts.poppins(fontSize: 14, color: AppColors.textDark),
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.white,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                    color: AppColors.textLight.withValues(alpha: 0.3))),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                    color: AppColors.textLight.withValues(alpha: 0.3))),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    const BorderSide(color: AppColors.rose, width: 1.5)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
      ],
    );
  }
}
