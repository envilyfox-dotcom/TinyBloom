import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
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

  late TextEditingController _nameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _bioCtrl;

  File? _pickedImage;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl  = TextEditingController(text: widget.profile?['full_name']  as String? ?? '');
    _phoneCtrl = TextEditingController(text: widget.profile?['phone']       as String? ?? '');
    _bioCtrl   = TextEditingController(text: widget.profile?['bio']         as String? ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
        source: ImageSource.gallery, imageQuality: 80);
    if (picked != null) setState(() => _pickedImage = File(picked.path));
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Full name cannot be empty.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      String? avatarUrl = widget.profile?['avatar_url'] as String?;

      // Upload new avatar if picked
      if (_pickedImage != null) {
        final userId = SupabaseService.currentUser!.id;
        final filePath = 'avatars/$userId.jpg';
        final bytes = await _pickedImage!.readAsBytes();
        // Try update first (file exists), fall back to upload (new file)
        try {
          await SupabaseService.client.storage
              .from('avatars')
              .updateBinary(filePath, bytes);
        } catch (_) {
          await SupabaseService.client.storage
              .from('avatars')
              .uploadBinary(filePath, bytes);
        }
        // Add cache-busting timestamp so the UI refreshes the image
        avatarUrl = '${SupabaseService.client.storage.from('avatars').getPublicUrl(filePath)}?t=${DateTime.now().millisecondsSinceEpoch}';
      }

      // Update profiles table
      await SupabaseService.client.from('profiles').update({
        'full_name': _nameCtrl.text.trim(),
        'phone':     _phoneCtrl.text.trim(),
        'bio':       _bioCtrl.text.trim(),
        if (avatarUrl != null) 'avatar_url': avatarUrl,
      }).eq('id', SupabaseService.currentUser!.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated!')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final existingAvatar = widget.profile?['avatar_url'] as String?;

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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 8),

            // ── Avatar picker ─────────────────────────────────────
            GestureDetector(
              onTap: _pickImage,
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  CircleAvatar(
                    radius: 52,
                    backgroundColor: _pink.withOpacity(0.2),
                    backgroundImage: _pickedImage != null
                        ? FileImage(_pickedImage!) as ImageProvider
                        : (existingAvatar != null && existingAvatar.isNotEmpty
                            ? NetworkImage(existingAvatar)
                            : null),
                    child: (_pickedImage == null &&
                            (existingAvatar == null || existingAvatar.isEmpty))
                        ? const Icon(Icons.person, size: 52, color: _pink)
                        : null,
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
            const SizedBox(height: 24),

            // ── Form card ─────────────────────────────────────────
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
                  _field('Phone number', _phoneCtrl,
                      keyboardType: TextInputType.phone),
                  const SizedBox(height: 12),
                  _field('Bio', _bioCtrl, maxLines: 3),
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
