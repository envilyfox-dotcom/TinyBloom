import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/supabase_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/common_widgets.dart';

// Read-only volunteer profile — same shape as SpecialistProfileViewScreen,
// opened by tapping a volunteer's name on a session notification.
class VolunteerProfileViewScreen extends StatefulWidget {
  final String volunteerId;
  const VolunteerProfileViewScreen({super.key, required this.volunteerId});

  @override
  State<VolunteerProfileViewScreen> createState() =>
      _VolunteerProfileViewScreenState();
}

class _VolunteerProfileViewScreenState
    extends State<VolunteerProfileViewScreen> {
  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _volunteerProfile;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final results = await Future.wait([
      SupabaseService.getProfileById(widget.volunteerId),
      SupabaseService.getVolunteerProfileByUserId(widget.volunteerId),
    ]);

    if (mounted) {
      setState(() {
        _profile = results[0];
        _volunteerProfile = results[1];
        _loading = false;
      });
    }
  }

  List<String> _stringList(dynamic value) {
    if (value is List) return value.map((e) => e.toString()).toList();
    return const [];
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

    final fullName = _profile?['full_name'] as String? ?? 'Volunteer';
    final photoUrl = _profile?['profile_picture_url'] as String?;
    final isVerified = _volunteerProfile?['is_verified'] == true;
    final expertise =
        _volunteerProfile?['expertise'] as String? ?? 'Community Volunteer';
    final affiliation = _volunteerProfile?['affiliation'] as String? ?? '';
    final certification = _volunteerProfile?['certification'] as String? ?? '';
    final yearsExperience = _volunteerProfile?['years_experience'] as int?;
    final helpsWith = _stringList(_volunteerProfile?['helps_with']);
    final availableToday = _stringList(_volunteerProfile?['available_today']);
    final displayName = fullName.isNotEmpty ? fullName : 'Volunteer';

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
                            displayName.isNotEmpty
                                ? displayName[0].toUpperCase()
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
                      if (isVerified) ...[
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.check_circle,
                          color: AppColors.teal,
                          size: 20,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    expertise,
                    style: const TextStyle(
                      color: AppColors.textMid,
                      fontSize: 13,
                    ),
                  ),
                  if (yearsExperience != null) ...[
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
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Credentials Section
            if (affiliation.isNotEmpty || certification.isNotEmpty) ...[
              SizedBox(
                width: double.infinity,
                child: TBCard(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Credentials:',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: AppColors.textMid,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (affiliation.isNotEmpty) ...[
                          _credentialRow('Affiliation', affiliation),
                          const SizedBox(height: 10),
                        ],
                        if (certification.isNotEmpty)
                          _credentialRow(
                              'Certification/License', certification),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Helps With
            if (helpsWith.isNotEmpty) ...[
              TBCard(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Helps With:',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: AppColors.textMid,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: helpsWith
                            .map((h) => Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color:
                                        AppColors.sage.withValues(alpha: 0.14),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(h,
                                      style: const TextStyle(
                                          color: AppColors.sage,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700)),
                                ))
                            .toList(),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Available Days
            if (availableToday.isNotEmpty)
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
                            'Available:',
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
                        availableToday.join(', '),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
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
