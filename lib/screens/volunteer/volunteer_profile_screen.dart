import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/auth_provider.dart';
import '../../services/supabase_service.dart';

class VolunteerProfileScreen extends StatefulWidget {
  const VolunteerProfileScreen({super.key});

  @override
  State<VolunteerProfileScreen> createState() => _VolunteerProfileScreenState();
}

class _VolunteerProfileScreenState extends State<VolunteerProfileScreen> {
  static const _pink = Color(0xFFE8A0B4);
  static const _roseDark = Color(0xFF9B8B86);
  static const _cardBg = Color(0xFFCB9189);

  Map<String, dynamic>? _profile;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final p = await SupabaseService.getProfile();
      if (mounted) setState(() { _profile = p; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final name = _profile?['full_name'] as String? ?? auth.profile?['full_name'] as String? ?? 'Volunteer';
    final email = auth.user?.email ?? '';
    final avatarUrl = _profile?['avatar_url'] as String?;
    final bio = _profile?['bio'] as String? ?? '';
    final phone = _profile?['phone'] as String? ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFFFF5F7),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF5F7),
        elevation: 0,
        title: Text('My Profile',
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: const Color(0xFF6B4A46))),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: () async {
              await context.read<AuthProvider>().signOut();
            },
            child: Text('Logout',
                style: GoogleFonts.poppins(color: _roseDark, fontSize: 13)),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _pink))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  // Avatar
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: _pink.withValues(alpha: 0.2),
                    backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                        ? CachedNetworkImageProvider(avatarUrl)
                        : null,
                    child: avatarUrl == null || avatarUrl.isEmpty
                        ? const Icon(Icons.person, size: 50, color: _pink)
                        : null,
                  ),
                  const SizedBox(height: 12),
                  Text(name,
                      style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF6B4A46))),
                  Text('Volunteer',
                      style: GoogleFonts.poppins(fontSize: 13, color: _roseDark)),
                  const SizedBox(height: 24),
                  // Info card
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: _cardBg,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Personal Information',
                            style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 14)),
                        const SizedBox(height: 16),
                        _infoRow('Full name', name),
                        _infoRow('Email', email),
                        if (phone.isNotEmpty) _infoRow('Phone', phone),
                        if (bio.isNotEmpty) _infoRow('Bio', bio),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => context.push(
                                    '/volunteer/edit-profile',
                                    extra: _profile),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  side: const BorderSide(color: Colors.white),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8)),
                                ),
                                child: Text('Edit',
                                    style: GoogleFonts.poppins()),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () =>
                                    context.push('/change-password'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF6B4A46),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8)),
                                ),
                                child: Text('Change Password',
                                    style:
                                        GoogleFonts.poppins(fontSize: 12)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: GoogleFonts.poppins(
                  color: Colors.white70, fontSize: 11)),
          const SizedBox(height: 2),
          Text(value,
              style: GoogleFonts.poppins(color: Colors.white, fontSize: 14)),
        ],
      ),
    );
  }
}
