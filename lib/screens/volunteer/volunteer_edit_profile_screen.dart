import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/supabase_service.dart';

class VolunteerEditProfileScreen extends StatefulWidget {
  final Map<String, dynamic>? profile;
  const VolunteerEditProfileScreen({super.key, this.profile});

  @override
  State<VolunteerEditProfileScreen> createState() =>
      _VolunteerEditProfileScreenState();
}

class _VolunteerEditProfileScreenState
    extends State<VolunteerEditProfileScreen> {
  static const _pink = Color(0xFFE8A0B4);
  static const _roseDark = Color(0xFF9B8B86);
  static const _cardBg = Color(0xFFCB9189);

  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _expertiseCtrl = TextEditingController();
  final _certificationCtrl = TextEditingController();

  String _originalEmail = '';
  String? _photoUrl;
  bool _photoBusy = false;
  bool _saving = false;
  bool _loading = true;

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
      if (mounted) _showSnack('Error: $e', isError: true);
    }
    if (mounted) setState(() => _photoBusy = false);
  }

  Future<void> _confirmRemovePhoto() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Photo'),
        content: const Text(
            'Are you sure you want to remove your profile photo?'),
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

    if (name.isEmpty) {
      _showSnack('Full name cannot be empty.');
      return;
    }
    if (email.isEmpty || !email.contains('@')) {
      _showSnack('Please enter a valid email address.');
      return;
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
        message = 'Profile updated! Check your new email to confirm the change.';
      }

      if (!mounted) return;
      context.pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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
        backgroundColor: isError ? Colors.red : _roseDark,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF5F7),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF5F7),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left,
              color: Color(0xFF6B4A46), size: 28),
          onPressed: () => context.pop(),
        ),
        title: Text('Edit Profile',
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: const Color(0xFF6B4A46))),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _pink))
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
                    backgroundColor: _pink.withValues(alpha: 0.2),
                    backgroundImage: _photoUrl != null && _photoUrl!.isNotEmpty
                        ? NetworkImage(_photoUrl!)
                        : null,
                    child: _photoBusy
                        ? const CircularProgressIndicator(color: _pink)
                        : (_photoUrl == null || _photoUrl!.isEmpty
                            ? const Icon(Icons.person, size: 52, color: _pink)
                            : null),
                  ),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: _pink,
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
                    fontSize: 12, color: _roseDark)),
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

            // ── Form card — mirrors the Personal Information card
            // shown on the account details screen ─────────────────
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: _cardBg,
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Text('Personal Information',
                        style: GoogleFonts.poppins(
                            color: Colors.white,
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
                  const SizedBox(height: 20),

                  // ── Save button ───────────────────────────────
                  ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6B4A46),
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
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white),
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
            style: GoogleFonts.poppins(
                color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 4),
        TextField(
          controller: ctrl,
          maxLines: maxLines,
          keyboardType: keyboardType,
          style: GoogleFonts.poppins(fontSize: 14),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
      ],
    );
  }
}
