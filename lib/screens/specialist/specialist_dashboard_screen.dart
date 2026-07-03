import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../services/auth_provider.dart';
import '../../services/supabase_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/common_widgets.dart';
import '../mum/consultation/consultation_helpers.dart';

class SpecialistDashboardScreen extends StatefulWidget {
  const SpecialistDashboardScreen({super.key});

  @override
  State<SpecialistDashboardScreen> createState() =>
      _SpecialistDashboardScreenState();
}

class _SpecialistDashboardScreenState extends State<SpecialistDashboardScreen> {
  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _specialistProfile;
  List<Map<String, dynamic>> _consultations = [];
  List<Map<String, dynamic>> _testimonials = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    Map<String, dynamic>? profile;
    Map<String, dynamic>? specialistProfile;
    List<Map<String, dynamic>> consultations = [];
    List<Map<String, dynamic>> testimonials = [];

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

    try {
      consultations = await SupabaseService.getConsultations();
      final patientIds = consultations
          .map((c) => c['patient_id'] as String?)
          .whereType<String>()
          .toSet()
          .toList();
      if (patientIds.isNotEmpty) {
        final patientNameMap = <String, String>{};
        await Future.wait(patientIds.map((id) async {
          final patient = await SupabaseService.getProfileById(id);
          final fullName = patient?['full_name'] as String?;
          if (fullName != null) {
            patientNameMap[id] = fullName;
          }
        }));
        for (final consultation in consultations) {
          final patientId = consultation['patient_id'] as String?;
          if (patientId != null && patientNameMap.containsKey(patientId)) {
            consultation['patient_name'] = patientNameMap[patientId];
          }
        }
      }
    } catch (_) {}

    try {
      testimonials = await SupabaseService.getTestimonials();
    } catch (_) {}

    if (mounted) {
      setState(() {
        _profile = profile;
        _specialistProfile = specialistProfile;
        _consultations = consultations;
        _testimonials = testimonials;
        _loading = false;
      });
    }
  }

  // Filter consultations for today
  List<Map<String, dynamic>> get _todayConsultations {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));

    return _consultations.where((c) {
      final scheduled = c['scheduled_date'];
      if (scheduled == null) return false;
      try {
        final date = DateTime.parse(scheduled);
        final consultationDate = DateTime(date.year, date.month, date.day);
        final status = (c['status'] as String? ?? '').toLowerCase();
        return consultationDate == today &&
            (status == 'pending' || status == 'confirmed');
      } catch (_) {
        return false;
      }
    }).toList();
  }

  // Filter consultations for upcoming (after today)
  List<Map<String, dynamic>> get _upcomingConsultations {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return _consultations.where((c) {
      final scheduled = c['scheduled_date'];
      if (scheduled == null) return false;
      try {
        final date = DateTime.parse(scheduled);
        final consultationDate = DateTime(date.year, date.month, date.day);
        final status = (c['status'] as String? ?? '').toLowerCase();
        return consultationDate.isAfter(today) &&
            (status == 'pending' || status == 'confirmed');
      } catch (_) {
        return false;
      }
    }).toList()
        .take(3)
        .toList(); // Show only first 3 upcoming
  }

  String get _firstName =>
      (_profile?['full_name'] as String? ?? 'Doctor').split(' ').first;

  String? get _photoUrl => _profile?['profile_picture_url'] as String?;

  String get _specialization =>
      (_specialistProfile?['specialization'] as String? ?? 'Healthcare Specialist');

  // Build consultation card
  Widget _consultationCard(Map<String, dynamic> consultation) {
    final patientName = consultation['patient_name'] as String? ??
        (consultation['patient'] is Map<String, dynamic>
            ? (consultation['patient']['full_name'] as String?)
            : null) ??
        'Patient';
    final scheduledDate = consultation['scheduled_date'] as String?;
    final scheduledTime = consultation['scheduled_time'] as String?;
    final purpose = consultation['purpose'] as String? ?? 'Consultation';
    final status = (consultation['status'] as String?) ?? 'pending';

    String formattedTime = '';
    if (scheduledTime != null) {
      try {
        final time = DateTime.parse('2024-01-01 $scheduledTime');
        formattedTime = DateFormat('h:mm a').format(time);
      } catch (_) {
        formattedTime = scheduledTime;
      }
    }

    return TBCard(
      onTap: () => context.push('/consultation/detail',
          extra: consultation),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(patientName,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 14)),
                      const SizedBox(height: 2),
                      Text(purpose,
                          style: const TextStyle(
                              color: AppColors.textMid, fontSize: 12)),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor(status).withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(statusLabel(status),
                            style: TextStyle(
                                color: statusColor(status),
                                fontSize: 12,
                                fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.teal.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(formattedTime,
                      style: const TextStyle(
                          color: AppColors.teal,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                )
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.bottomRight,
              child: Text('View Details >',
                  style: TextStyle(
                      color: AppColors.teal.withValues(alpha: 0.7),
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  // Build review card
  Widget _reviewCard(Map<String, dynamic> testimonial) {
    final authorName = testimonial['author_name'] as String? ?? 'User';
    final rating = (testimonial['rating'] as num?)?.toInt() ?? 5;
    final comment = testimonial['comment'] as String? ?? '';
    final profileImage = testimonial['author_image'] as String?;

    return TBCard(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.rose.withValues(alpha: 0.15),
                  child: Text(authorName.isNotEmpty ? authorName[0] : '?',
                      style: const TextStyle(
                          color: AppColors.rose,
                          fontWeight: FontWeight.w700,
                          fontSize: 14)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(authorName,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13)),
                      const SizedBox(height: 2),
                      Row(
                        children: List.generate(
                          5,
                          (i) => Icon(
                            i < rating ? Icons.star : Icons.star_outline,
                            color: AppColors.gold,
                            size: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(comment,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.textMid, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (_loading) return const Scaffold(body: TBLoading());

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.rose,
        child: CustomScrollView(
          slivers: [
            // App bar
            SliverAppBar(
              expandedHeight: 140,
              floating: false,
              pinned: true,
              backgroundColor: AppColors.blush,
              elevation: 0,
              automaticallyImplyLeading: false,
              flexibleSpace: FlexibleSpaceBar(
                background: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 44, 20, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Welcome, Dr $_firstName',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineMedium
                                      ?.copyWith(fontSize: 20)),
                              const SizedBox(height: 2),
                              Text(_specialization,
                                  style: const TextStyle(
                                      color: AppColors.textMid, fontSize: 13)),
                            ],
                          ),
                          GestureDetector(
                            onTap: () => context.push('/profile'),
                            child: CircleAvatar(
                              radius: 22,
                              backgroundColor:
                                  AppColors.rose.withValues(alpha: 0.15),
                              backgroundImage: _photoUrl != null
                                  ? NetworkImage(_photoUrl!)
                                  : null,
                              child: _photoUrl != null
                                  ? null
                                  : Text(
                                      _firstName.isNotEmpty ? _firstName[0] : '?',
                                      style: const TextStyle(
                                          color: AppColors.roseDeep,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w700)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.all(20),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Today's Appointments
                  if (_todayConsultations.isNotEmpty) ...[
                    const Text("Today's Appointment:",
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 16)),
                    const SizedBox(height: 12),
                    ..._todayConsultations
                        .map((c) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _consultationCard(c),
                            ))
                        .toList(),
                    const SizedBox(height: 20),
                  ],

                  // Upcoming Appointments
                  if (_upcomingConsultations.isNotEmpty) ...[
                    const Text('Upcoming Appointment:',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 16)),
                    const SizedBox(height: 12),
                    ..._upcomingConsultations
                        .map((c) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _consultationCard(c),
                            ))
                        .toList(),
                    const SizedBox(height: 20),
                  ],

                  // User Review
                  if (_testimonials.isNotEmpty) ...[
                    const Text('User Review:',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 16)),
                    const SizedBox(height: 12),
                    ..._testimonials
                        .take(1)
                        .map((t) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _reviewCard(t),
                            ))
                        .toList(),
                  ] else
                    Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: TBEmptyState(
                          emoji: '⭐',
                          title: 'No reviews yet',
                          subtitle: 'Your patient reviews will show here.'),
                    ),
                  const SizedBox(height: 20),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
