import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../services/auth_provider.dart';
import '../../services/supabase_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/common_widgets.dart';
import '../../utils/singapore_time.dart';
import '../../widgets/review_widgets.dart';
import '../mum/consultation/consultation_helpers.dart';
import 'specialist_notifications_helpers.dart';

// Specialist home screen - today's/upcoming consultations, alerts, and review stats.
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
  List<Map<String, dynamic>> _providerRatings = [];
  List<Map<String, dynamic>> _notifications = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  // Pulls together the profile, consultations (with patient names attached),
  // ratings, and notifications needed to render the dashboard.
  Future<void> _load() async {
    Map<String, dynamic>? profile;
    Map<String, dynamic>? specialistProfile;
    List<Map<String, dynamic>> consultations = [];
    List<Map<String, dynamic>> providerRatings = [];

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
      final myId = SupabaseService.currentUser?.id;
      if (myId != null) {
        providerRatings = await SupabaseService.getProviderRatings(myId);
      }
    } catch (_) {}

    List<Map<String, dynamic>> reviewQueue = [];
    try {
      reviewQueue = await SupabaseService.getReviewQueue();
    } catch (_) {}

    final notifications = buildSpecialistNotifications(
      consultations: consultations,
      reviewQueue: reviewQueue,
      userId: SupabaseService.currentUser?.id ?? '',
    );

    if (mounted) {
      setState(() {
        _profile = profile;
        _specialistProfile = specialistProfile;
        _consultations = consultations;
        _providerRatings = providerRatings;
        _notifications = notifications;
        _loading = false;
      });
    }
  }

  // Combines the separate scheduled_date and scheduled_time fields into one
  // Singapore-time DateTime.
  DateTime? _scheduledDateTime(Map<String, dynamic> c) {
    final scheduled = c['scheduled_date'];
    if (scheduled == null) return null;
    try {
      final date = DateTime.parse(scheduled.toString());
      final timeStr = c['scheduled_time'] as String?;
      if (timeStr == null || timeStr.isEmpty) {
        return sgtWallClock(date.year, date.month, date.day);
      }
      return slotDateTime(date, timeStr) ??
          sgtWallClock(date.year, date.month, date.day);
    } catch (_) {
      return null;
    }
  }

  bool _isExpiredPending(Map<String, dynamic> c) {
    final status = (c['status'] as String? ?? '').toLowerCase();
    if (status != 'pending') return false;
    final scheduled = _scheduledDateTime(c);
    return scheduled != null && scheduled.isBefore(sgtNow());
  }

  List<Map<String, dynamic>> _sortedByTime(List<Map<String, dynamic>> list) {
    final sorted = [...list];
    sorted.sort((a, b) {
      final aTime = _scheduledDateTime(a);
      final bTime = _scheduledDateTime(b);
      if (aTime == null && bTime == null) return 0;
      if (aTime == null) return 1;
      if (bTime == null) return -1;
      return aTime.compareTo(bTime);
    });
    return sorted;
  }

  List<Map<String, dynamic>> get _todayConsultations {
    final now = sgtNow();
    final today = sgtWallClock(now.year, now.month, now.day);

    final filtered = _consultations.where((c) {
      final scheduled = c['scheduled_date'];
      if (scheduled == null) return false;
      try {
        final date = DateTime.parse(scheduled);
        final consultationDate = sgtWallClock(date.year, date.month, date.day);
        final status = (c['status'] as String? ?? '').toLowerCase();
        return consultationDate == today &&
            (status == 'pending' || status == 'confirmed') &&
            !_isExpiredPending(c);
      } catch (_) {
        return false;
      }
    }).toList();

    return _sortedByTime(filtered);
  }

  List<Map<String, dynamic>> get _upcomingConsultations {
    final now = sgtNow();
    final today = sgtWallClock(now.year, now.month, now.day);

    final filtered = _consultations.where((c) {
      final scheduled = c['scheduled_date'];
      if (scheduled == null) return false;
      try {
        final date = DateTime.parse(scheduled);
        final consultationDate = sgtWallClock(date.year, date.month, date.day);
        final status = (c['status'] as String? ?? '').toLowerCase();
        return consultationDate.isAfter(today) &&
            (status == 'pending' || status == 'confirmed');
      } catch (_) {
        return false;
      }
    }).toList();

    return _sortedByTime(filtered).take(3).toList(); // Show only the 3 soonest
  }

  String get _firstName =>
      (_profile?['full_name'] as String? ?? 'Doctor').split(' ').first;

  String? get _photoUrl => _profile?['profile_picture_url'] as String?;

  String get _specialization =>
      (_specialistProfile?['specialization'] as String? ??
          'Healthcare Specialist');

  Widget _consultationCard(Map<String, dynamic> consultation,
      {bool showDate = false}) {
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

    String formattedDate = '';
    if (showDate && scheduledDate != null) {
      try {
        formattedDate =
            DateFormat('d MMM').format(DateTime.parse(scheduledDate));
      } catch (_) {
        formattedDate = scheduledDate;
      }
    }

    return TBCard(
      onTap: () => context.push('/consultation/detail', extra: consultation),
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
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.teal.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                      showDate && formattedDate.isNotEmpty
                          ? '$formattedDate at $formattedTime'
                          : formattedTime,
                      style: const TextStyle(
                          color: AppColors.teal,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                )
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                Text('View Details >',
                    style: TextStyle(
                        color: AppColors.teal.withValues(alpha: 0.7),
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _notifColor(String category) {
    switch (category) {
      case 'consultation':
        return AppColors.sage;
      case 'review':
        return AppColors.teal;
      case 'emergency':
        return Colors.redAccent;
      default:
        return AppColors.textMid;
    }
  }

  IconData _notifIcon(String category) {
    switch (category) {
      case 'consultation':
        return Icons.calendar_today_outlined;
      case 'review':
        return Icons.rate_review_outlined;
      case 'emergency':
        return Icons.warning_amber_rounded;
      default:
        return Icons.notifications_none_outlined;
    }
  }

  Future<void> _openNotificationsCentre() async {
    await context.push('/specialist/notifications');
    if (mounted) _load();
  }

  Future<void> _openNotification(Map<String, dynamic> n) async {
    final category = n['category'] as String? ?? 'general';
    if (category == 'consultation') {
      final consultation = n['consultation'] as Map<String, dynamic>?;
      if (consultation != null) {
        await context.push('/consultation/detail', extra: consultation);
        if (mounted) _load();
        return;
      }
    } else if (category == 'review') {
      final article = n['article'] as Map<String, dynamic>?;
      final id = article?['id']?.toString();
      if (id != null) {
        await context.push('/specialist/review/thread', extra: id);
        if (mounted) _load();
        return;
      }
    }
    await _openNotificationsCentre();
  }

  Widget _notificationPreviewCard(Map<String, dynamic> n) {
    final category = n['category'] as String? ?? 'general';
    final color = _notifColor(category);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TBCard(
        onTap: () => _openNotification(n),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(_notifIcon(category), color: color, size: 20),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    n['title'] as String? ?? 'Notification',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: AppColors.textDark),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    n['message'] as String? ?? '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style:
                        const TextStyle(color: AppColors.textMid, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right,
                color: AppColors.textLight, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _emptyAlertCard() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TBCard(
        onTap: _openNotificationsCentre,
        padding: const EdgeInsets.all(14),
        child: const Row(
          children: [
            CircleAvatar(
              backgroundColor: AppColors.blush,
              child: Icon(
                Icons.notifications_none_outlined,
                color: AppColors.roseDeep,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'No new alerts right now. Tap View All to open the Notifications Centre.',
                style: TextStyle(
                  color: AppColors.textMid,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ),
            Icon(Icons.chevron_right, color: AppColors.textLight, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _emptyConsultationCard() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TBCard(
        onTap: () => context.go('/specialist/consultations'),
        padding: const EdgeInsets.all(14),
        child: const Row(
          children: [
            CircleAvatar(
              backgroundColor: AppColors.blush,
              child: Icon(
                Icons.medical_services_outlined,
                color: AppColors.roseDeep,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'No new consultation. Tap view all to open the consultation page.',
                style: TextStyle(
                  color: AppColors.textMid,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ),
            Icon(Icons.chevron_right, color: AppColors.textLight, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertsSection() {
    final cards = <Widget>[
      for (final n in _notifications.take(3)) _notificationPreviewCard(n),
    ];

    if (cards.isEmpty) {
      cards.add(_emptyAlertCard());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text('Alerts & Notifications',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            ),
            TextButton(
              onPressed: _openNotificationsCentre,
              child: const Text('View All >'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...cards,
        const SizedBox(height: 20),
      ],
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
                              const SizedBox(height: 2),
                              Text(
                                  DateFormat('EEEE, d MMMM yyyy')
                                      .format(sgtNow()),
                                  style: const TextStyle(
                                      color: AppColors.textLight,
                                      fontSize: 11)),
                            ],
                          ),
                          Row(
                            children: [
                              TBNotificationBell(
                                count: _notifications.length,
                                onTap: () async {
                                  await context
                                      .push('/specialist/notifications');
                                  if (mounted) _load();
                                },
                              ),
                              const SizedBox(width: 10),
                              GestureDetector(
                                onTap: () => context.go('/profile'),
                                child: CircleAvatar(
                                  radius: 22,
                                  backgroundColor:
                                      AppColors.rose.withValues(alpha: 0.15),
                                  backgroundImage: _photoUrl != null
                                      ? CachedNetworkImageProvider(_photoUrl!,
                                          maxWidth: 200)
                                      : null,
                                  child: _photoUrl != null
                                      ? null
                                      : Text(
                                          _firstName.isNotEmpty
                                              ? _firstName[0]
                                              : '?',
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
                    ],
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.all(20),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  Row(
                    children: [
                      const Expanded(
                        child: Text("Today's Appointment:",
                            style: TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 16)),
                      ),
                      TextButton(
                        onPressed: () =>
                            context.go('/specialist/consultations'),
                        child: const Text('View All >'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_todayConsultations.isEmpty)
                    _emptyConsultationCard()
                  else
                    ..._todayConsultations.map((c) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _consultationCard(c),
                        )),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      const Expanded(
                        child: Text('Upcoming Appointment:',
                            style: TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 16)),
                      ),
                      TextButton(
                        onPressed: () =>
                            context.go('/specialist/consultations'),
                        child: const Text('View All >'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_upcomingConsultations.isEmpty)
                    _emptyConsultationCard()
                  else
                    ..._upcomingConsultations.map((c) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _consultationCard(c, showDate: true),
                        )),
                  const SizedBox(height: 20),
                  _buildAlertsSection(),
                  providerReviewsSection(
                    context,
                    ratings: _providerRatings,
                    providerId: SupabaseService.currentUser?.id ?? '',
                    providerName: _profile?['full_name'] as String? ?? 'You',
                    providerType: 'specialist',
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
