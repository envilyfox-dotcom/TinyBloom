import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/auth_provider.dart';
import '../../services/supabase_service.dart';
import '../../utils/app_theme.dart';

class VolunteerProfileScreen extends StatefulWidget {
  const VolunteerProfileScreen({super.key});

  @override
  State<VolunteerProfileScreen> createState() =>
      _VolunteerProfileScreenState();
}

class _VolunteerProfileScreenState extends State<VolunteerProfileScreen> {
  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _volunteerProfile;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final p = await SupabaseService.getProfile();
      Map<String, dynamic>? vp;
      try {
        vp = await SupabaseService.getMyVolunteerProfile();
      } catch (_) {}
      if (mounted) {
        setState(() {
          _profile = p;
          _volunteerProfile = vp;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Delete Profile ────────────────────────────────────────────
  void _deleteProfile(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete Profile',
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600, color: Colors.red.shade400)),
        content: Text(
            'This will permanently delete your account and all your data. This cannot be undone.',
            style: GoogleFonts.poppins(fontSize: 14, color: AppColors.textLight)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: GoogleFonts.poppins(color: AppColors.textLight)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await SupabaseService.client
                    .from('profiles')
                    .delete()
                    .eq('id', SupabaseService.currentUser!.id);
                if (context.mounted) {
                  await context.read<AuthProvider>().signOut();
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade400,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Delete Account',
                style: GoogleFonts.poppins(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ── Logout ────────────────────────────────────────────────────
  void _logout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Logout',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Text('Are you sure you want to logout?',
            style: GoogleFonts.poppins(fontSize: 14, color: AppColors.textLight)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: GoogleFonts.poppins(color: AppColors.textLight)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await context.read<AuthProvider>().signOut();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.rose,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Logout',
                style: GoogleFonts.poppins(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final name = _profile?['full_name'] as String? ??
        auth.profile?['full_name'] as String? ??
        'Volunteer';
    final email = auth.user?.email ?? '';
    final phone = _profile?['phone'] as String? ?? '';
    final expertise = _volunteerProfile?['expertise'] as String? ?? '';
    final certification = _volunteerProfile?['certification'] as String? ?? '';
    final avatarUrl = _profile?['profile_picture_url'] as String?;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        // ← goes to home (not pop) because Profile is a tab, not a pushed screen
        leading: IconButton(
          icon: const Icon(Icons.chevron_left,
              color: AppColors.textDark, size: 28),
          onPressed: () => context.go('/home'),
        ),
        actions: [
          TextButton(
            onPressed: () => _logout(context),
            child: Text('Logout',
                style: GoogleFonts.poppins(
                    color: AppColors.textLight,
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.rose))
          : RefreshIndicator(
              color: AppColors.rose,
              onRefresh: _load,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 8),
                child: Column(
                  children: [
                    // ── Title ────────────────────────────────────
                    Text('Account Details',
                        style: GoogleFonts.poppins(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark)),
                    const SizedBox(height: 20),

                    // ── Avatar ───────────────────────────────────
                    CircleAvatar(
                      radius: 52,
                      backgroundColor: AppColors.rose.withValues(alpha: 0.2),
                      backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                          ? CachedNetworkImageProvider(avatarUrl)
                          : null,
                      child: avatarUrl == null || avatarUrl.isEmpty
                          ? const Icon(Icons.person,
                              size: 52, color: AppColors.rose)
                          : null,
                    ),
                    const SizedBox(height: 24),

                    // ── Info card ──────────────────────────────────
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
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Text('Personal Information',
                                style: GoogleFonts.poppins(
                                    color: AppColors.textDark,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14)),
                          ),
                          const SizedBox(height: 16),
                          _infoRow('Full name:', name),
                          _infoRow('Email:', email),
                          if (phone.isNotEmpty)
                            _infoRow('Phone number:', phone),
                          if (expertise.isNotEmpty)
                            _infoRow('Area of Expertise:', expertise),
                          if (certification.isNotEmpty)
                            _infoRow('Certification/License:', certification),
                          const SizedBox(height: 16),

                          // ── Edit / Change Password ────────────
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => context.push(
                                      '/volunteer/edit-profile',
                                      extra: {...?_profile, ...?_volunteerProfile}
                                  ).then((_) => _load()),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.rose,
                                    side: BorderSide(color: AppColors.rose),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(8)),
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
                                    backgroundColor: AppColors.rose,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(8)),
                                  ),
                                  child: Text('Change Password',
                                      style: GoogleFonts.poppins(
                                          fontSize: 12)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── Delete Profile ────────────────────────────
                    _optionTile(
                      icon: Icons.delete_outline,
                      label: 'Delete Profile',
                      color: Colors.red.shade400,
                      onTap: () => _deleteProfile(context),
                    ),

                    // ── Logout ────────────────────────────────────
                    _optionTile(
                      icon: Icons.logout,
                      label: 'Logout',
                      color: Colors.red.shade300,
                      onTap: () => _logout(context),
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
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
                  color: AppColors.textDark,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(value,
              style: GoogleFonts.poppins(
                  color: AppColors.textMid, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _optionTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    final c = color ?? AppColors.textDark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
                color: AppColors.rose.withValues(alpha: 0.08),
                blurRadius: 6,
                offset: const Offset(0, 2))
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: c, size: 20),
            const SizedBox(width: 12),
            Text(label,
                style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: c,
                    fontWeight: FontWeight.w500)),
            const Spacer(),
            Icon(Icons.chevron_right,
                color: c.withValues(alpha: 0.5), size: 20),
          ],
        ),
      ),
    );
  }
}
