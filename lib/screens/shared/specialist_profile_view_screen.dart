import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/supabase_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/common_widgets.dart';

// Read-only specialist profile — same layout as SpecialistProfileScreen
// (their own "My Profile" tab) minus the Edit Profile / Sign Out actions,
// opened by tapping a specialist's avatar on an article or its author strip.
class SpecialistProfileViewScreen extends StatefulWidget {
  final String specialistId;
  const SpecialistProfileViewScreen({super.key, required this.specialistId});

  @override
  State<SpecialistProfileViewScreen> createState() =>
      _SpecialistProfileViewScreenState();
}

class _SpecialistProfileViewScreenState
    extends State<SpecialistProfileViewScreen> {
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

  Future<void> _load() async {
    final results = await Future.wait([
      SupabaseService.getProfileById(widget.specialistId),
      SupabaseService.getSpecialistProfileByUserId(widget.specialistId),
      SupabaseService.getPublishedArticlesCountForUser(widget.specialistId),
      SupabaseService.getReviewActionsCountForUser(widget.specialistId),
    ]);

    if (mounted) {
      setState(() {
        _profile = results[0] as Map<String, dynamic>?;
        _specialistProfile = results[1] as Map<String, dynamic>?;
        _articlesPublished = results[2] as int;
        _articlesReviewed = results[3] as int;
        _loading = false;
      });
    }
  }

  String _availableHoursText(Map<String, dynamic>? profile) {
    final value = profile?['available_hours'] ?? profile?['available_today'];
    if (value is String) return value;
    if (value is List) {
      return value.map((e) => e.toString()).join(', ');
    }
    return '';
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

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.textDark),
            onPressed: () =>
                context.canPop() ? context.pop() : context.go('/home'),
          ),
          backgroundColor: AppColors.background,
          elevation: 0,
        ),
        backgroundColor: AppColors.background,
        body: const TBLoading(),
      );
    }

    final fullName = _profile?['full_name'] as String? ?? 'Specialist';
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
    final displayName = fullName.isNotEmpty ? 'Dr $fullName' : 'Specialist';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textDark),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/home'),
        ),
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text(
          "$displayName's Profile",
          style: const TextStyle(
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
                        displayName,
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
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
