import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../services/auth_provider.dart';
import '../../services/supabase_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/specialist_availability.dart';
import '../../widgets/common_widgets.dart';

// Specialist's own profile page - credentials, bio, available hours, and
// article activity stats, with links to edit profile and sign out.
class SpecialistProfileScreen extends StatefulWidget {
  const SpecialistProfileScreen({super.key});

  @override
  State<SpecialistProfileScreen> createState() =>
      _SpecialistProfileScreenState();
}

class _SpecialistProfileScreenState extends State<SpecialistProfileScreen> {
  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _specialistProfile;
  int _articlesPublished = 0;
  int _articlesReviewed = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  // Loads the profile, specialist-specific profile, and article counts shown on screen.
  Future<void> _load() async {
    Map<String, dynamic>? profile;
    Map<String, dynamic>? specialistProfile;

    try {
      profile = await SupabaseService.getProfile();
    } catch (_) {}

    if (profile == null) {
      final meta = SupabaseService.currentUser?.userMetadata;
      if (meta != null) {
        profile = {'full_name': meta['full_name'], 'role': meta['role']};
      }
    }

    try {
      specialistProfile = await SupabaseService.getMySpecialistProfile();
    } catch (_) {}

    final counts = await Future.wait([
      SupabaseService.getMyPublishedArticlesCount(),
      SupabaseService.getMyReviewActionsCount(),
    ]);
    final articlesPublished = counts[0];
    final articlesReviewed = counts[1];

    if (mounted) {
      setState(() {
        _profile = profile;
        _specialistProfile = specialistProfile;
        _articlesPublished = articlesPublished;
        _articlesReviewed = articlesReviewed;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: TBLoading());

    final fullName = _profile?['full_name'] as String? ?? 'Dr Specialist';
    final email = _profile?['email'] as String? ?? '';
    final photoUrl = _profile?['profile_picture_url'] as String?;
    final specialization = _specialistProfile?['specialization'] as String? ??
        'Healthcare Specialist';
    final hospital = _specialistProfile?['hospital_affiliation'] as String? ??
        'Medical Institution';
    final bio = _specialistProfile?['bio'] as String? ?? '';
    final yearsExperience =
        _specialistProfile?['years_experience'] as int? ?? 0;
    final availableHours = _availableHoursText(_specialistProfile);
    final licenseNumber =
        _specialistProfile?['license_number'] as String? ?? '';
    final qualification = _specialistProfile?['qualification'] as String? ?? '';
    final certificateExpiryDate =
        _specialistProfile?['practising_certificate_expiry'] as String? ?? '';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'My Profile',
          style: TextStyle(
            color: AppColors.textDark,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: AppColors.rose.withValues(alpha: 0.15),
                    backgroundImage: photoUrl != null
                        ? CachedNetworkImageProvider(photoUrl, maxWidth: 400)
                        : null,
                    child: photoUrl != null
                        ? null
                        : Text(
                            fullName.isNotEmpty
                                ? fullName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              color: AppColors.roseDeep,
                              fontSize: 36,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Dr ${fullName.split(' ').last}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.check_circle,
                        color: AppColors.teal,
                        size: 20,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    specialization,
                    style: const TextStyle(
                      color: AppColors.textMid,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    email,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMid,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$yearsExperience years experience',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMid,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (licenseNumber.isNotEmpty ||
                qualification.isNotEmpty ||
                hospital.isNotEmpty ||
                certificateExpiryDate.isNotEmpty) ...[
              SizedBox(
                width: double.infinity,
                child: TBCard(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Professional Credentials:',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: AppColors.textMid,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (licenseNumber.isNotEmpty) ...[
                          _credentialRow('SMC / MCR Number', licenseNumber),
                          const SizedBox(height: 10),
                        ],
                        if (qualification.isNotEmpty) ...[
                          _credentialRow(
                              'Medical Qualification', qualification),
                          const SizedBox(height: 10),
                        ],
                        if (hospital.isNotEmpty) ...[
                          _credentialRow('Place of Practice', hospital),
                          const SizedBox(height: 10),
                        ],
                        if (certificateExpiryDate.isNotEmpty) ...[
                          _credentialRow('Practising Certificate Expiry',
                              certificateExpiryDate),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (bio.isNotEmpty) ...[
              TBCard(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Description:',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: AppColors.textMid,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        bio,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textDark,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            TBCard(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.schedule_outlined,
                            size: 18, color: AppColors.textMid),
                        SizedBox(width: 8),
                        Text(
                          'Available Hours:',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: AppColors.textMid,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.center,
                      child: Text(
                        availableHours.isNotEmpty
                            ? availableHours
                            : 'Monday - Friday\n9:00 AM to 5:00 PM',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: SizedBox(
                width: 270,
                child: TBCard(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.edit_outlined,
                                size: 18, color: AppColors.textMid),
                            SizedBox(width: 8),
                            Text(
                              'Activity:',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: AppColors.textMid,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Articles published: $_articlesPublished',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Articles reviewed: $_articlesReviewed',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Material(
              color: AppColors.white,
              elevation: 2,
              shadowColor: AppColors.textDark.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  _menuItem(
                    Icons.edit_outlined,
                    'Edit Profile',
                    onTap: () async {
                      await context.push(
                        '/specialist/edit-profile',
                        extra: _specialistProfile,
                      );
                      setState(() => _loading = true);
                      _load();
                    },
                  ),
                  _divider(),
                  _menuItem(
                    Icons.logout,
                    'Sign Out',
                    color: Colors.red,
                    onTap: _showLogoutDialog,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _credentialRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textMid,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textDark,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  String _availableHoursText(Map<String, dynamic>? profile) {
    return formatWeeklySchedule(
      weeklyScheduleFromJson(profile?['available_schedule']),
    );
  }

  Widget _menuItem(
    IconData icon,
    String label, {
    VoidCallback? onTap,
    Color? color,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Icon(
                icon,
                color: color ?? AppColors.textMid,
                size: 22,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: color ?? AppColors.textDark,
                    fontWeight: FontWeight.w500,
                    fontSize: 15,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: AppColors.textLight,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _divider() {
    return const Divider(
      height: 1,
      indent: 56,
      color: AppColors.textLight,
      thickness: 0.3,
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await context.read<AuthProvider>().signOut();
              if (mounted) context.go('/login');
            },
            child: const Text('Sign Out', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
