import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../services/auth_provider.dart';
import '../../services/supabase_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/common_widgets.dart';

class SpecialistProfileScreen extends StatefulWidget {
  const SpecialistProfileScreen({super.key});

  @override
  State<SpecialistProfileScreen> createState() =>
      _SpecialistProfileScreenState();
}

class _SpecialistProfileScreenState extends State<SpecialistProfileScreen> {
  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _specialistProfile;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

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

    if (mounted) {
      setState(() {
        _profile = profile;
        _specialistProfile = specialistProfile;
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
    final videoCallFee = _numValue(_specialistProfile?['video_call_fee']) ?? 0;
    final inPersonFee = _numValue(_specialistProfile?['in_person_fee']) ?? 0;
    final availableHours = _availableHoursText(_specialistProfile);
    final articlesPublished =
        (_specialistProfile?['articles_published'] as num?)?.toInt() ?? 0;
    final articlesReviewed =
        (_specialistProfile?['articles_reviewed'] as num?)?.toInt() ?? 0;
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
            // Profile Header
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: AppColors.rose.withValues(alpha: 0.15),
                    backgroundImage:
                        photoUrl != null ? NetworkImage(photoUrl) : null,
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

            // Credentials Section
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
              _credentialRow('Medical Qualification', qualification),
              const SizedBox(height: 10),
            ],
            if (hospital.isNotEmpty) ...[
              _credentialRow('Place of Practice', hospital),
              const SizedBox(height: 10),
            ],
            if (certificateExpiryDate.isNotEmpty) ...[
              _credentialRow(
                  'Practising Certificate Expiry', certificateExpiryDate),
            ],
          ],
        ),
      ),
    ),
  ),
  const SizedBox(height: 12),
],

            // Description
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

            // Consultation Charges
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
                Icon(Icons.videocam_outlined,
                    size: 18, color: AppColors.textMid),
                SizedBox(width: 8),
                Text(
                  'Consultation Charges:',
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
              'Video call: \$${videoCallFee.toStringAsFixed(2)}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              'In-person: \$${inPersonFee.toStringAsFixed(2)}',
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

            // Available Hours
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

            // Activity
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
              'Articles published: $articlesPublished',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              'Articles reviewed: $articlesReviewed',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    ),
  ),
),
            // Bottom padding, sign out and edit profile buttons
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
  child: GestureDetector(
    onTap: () async {
      await context.push(
        '/specialist/edit-profile',
        extra: _specialistProfile,
      );
      setState(() => _loading = true);
      _load();
    },
    child: const TBCard(
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.edit_outlined,
                    size: 18, color: AppColors.textMid),
                SizedBox(width: 8),
                Text(
                  'Edit Profile',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: AppColors.textDark,
                  ),
                ),
              ],
            ),
            Icon(Icons.chevron_right,
                size: 18, color: AppColors.textMid),
          ],
        ),
      ),
    ),
  ),
),
const SizedBox(width: 12),
Expanded(
  child: GestureDetector(
    onTap: _showLogoutDialog,
    child: const TBCard(
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
  mainAxisAlignment: MainAxisAlignment.center,
  children: [
    Icon(Icons.logout, size: 18, color: Colors.red),
    SizedBox(width: 8),
    Text(
      'Sign Out',
      style: TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 13,
        color: Colors.red,
      ),
    ),
    SizedBox(width: 8),
    Icon(Icons.chevron_right, size: 18, color: Colors.red),
  ],
),
          ],
        ),
      ),
    ),
  ),
),
              ],
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

  num? _numValue(dynamic value) {
    if (value is num) return value;
    if (value is String) return num.tryParse(value.trim());
    return null;
  }

  String _availableHoursText(Map<String, dynamic>? profile) {
    final value = profile?['available_hours'] ?? profile?['available_today'];
    if (value is String) return value;
    if (value is List) {
      return value.map((e) => e.toString()).join(', ');
    }
    return '';
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
