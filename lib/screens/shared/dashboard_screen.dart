import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../services/auth_provider.dart';
import '../../services/supabase_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/pregnancy_week_data.dart';
import '../../widgets/common_widgets.dart';
import 'package:intl/intl.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _pregnancyProfile;
  List<Map<String, dynamic>> _consultations = [];
  List<Map<String, dynamic>> _notifications = [];
  Map<String, String> _providerNames = {};
  bool _loading = true;
  DateTime? _lastNavTime;

  bool _canNav() {
    final now = DateTime.now();
    if (_lastNavTime != null &&
        now.difference(_lastNavTime!) < const Duration(milliseconds: 600)) {
      return false;
    }
    _lastNavTime = now;
    return true;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    Map<String, dynamic>? profile;
    Map<String, dynamic>? pp;
    List<Map<String, dynamic>> consultations = [];
    List<Map<String, dynamic>> notifications = [];
    try {
      profile = await SupabaseService.getProfile();
    } catch (_) {}
    // Fall back to JWT metadata for name display.
    if (profile == null) {
      final meta = SupabaseService.currentUser?.userMetadata;
      if (meta != null) {
        profile = {'full_name': meta['full_name'], 'role': meta['role']};
      }
    }
    try {
      pp = await SupabaseService.getPregnancyProfile();
    } catch (_) {}
    try {
      consultations = await SupabaseService.getConsultations();
    } catch (_) {}

    // Load latest notifications for the dashboard preview. AI tips are only
    // shown to premium users; all other notification types are visible to mums.
    try {
      final userId = SupabaseService.currentUser?.id;
      final isPremiumUser =
          (profile?['subscription_plan']?.toString().toLowerCase() ==
                  'premium') ||
              (profile?['role']?.toString().toLowerCase() == 'premium_user');

      if (userId != null) {
        final data = await SupabaseService.client
            .from('notifications')
            .select()
            .eq('user_id', userId)
            .order('created_at', ascending: false)
            .limit(6);

        notifications = List<Map<String, dynamic>>.from(data).where((n) {
          final type = (n['type'] ?? '').toString().toLowerCase();
          if (type == 'ai' && !isPremiumUser) return false;
          return true;
        }).toList();
      }
    } catch (_) {}

    // Look up provider names for whichever consultations the Active Alerts
    // card will actually show, so it can read "2:00 PM - Nur Aisyah".
    final activeSpecialistIds = consultations
        .where((c) {
          final status = (c['status'] as String? ?? '').toLowerCase();
          return status == 'pending' || status == 'confirmed';
        })
        .take(2)
        .map((c) => c['specialist_id'] as String?)
        .whereType<String>()
        .toSet();
    final providerNames = <String, String>{};
    for (final id in activeSpecialistIds) {
      try {
        final p = await SupabaseService.getProviderProfile(id);
        final name =
            (p?['profiles'] as Map<String, dynamic>?)?['full_name'] as String?;
        if (name != null) providerNames[id] = name;
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        _profile = profile;
        _pregnancyProfile = pp;
        _consultations = consultations;
        _notifications = notifications;
        _providerNames = providerNames;
        _loading = false;
      });
    }
  }

  int get _currentWeek {
    if (_pregnancyProfile == null) return 0;
    // Prefer due_date — recalculates week automatically over time.
    final dueDateStr = _pregnancyProfile!['due_date'] as String?;
    if (dueDateStr != null) {
      final dueDate = DateTime.tryParse(dueDateStr);
      if (dueDate != null) {
        final conception = dueDate.subtract(const Duration(days: 280));
        final week = DateTime.now().difference(conception).inDays ~/ 7;
        return week.clamp(1, 42);
      }
    }
    // Fallback: use the stored week snapshot.
    final stored = _pregnancyProfile!['current_week'] ??
        _pregnancyProfile!['pregnancy_week'];
    if (stored != null) return (stored as num).toInt().clamp(1, 42);
    return 0;
  }

  Future<void> _pickAndSaveDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 140)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 300)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
            colorScheme: const ColorScheme.light(primary: AppColors.rose)),
        child: child!,
      ),
    );
    if (picked != null) {
      try {
        await SupabaseService.updateDueDate(picked);
      } catch (_) {}
      _load();
    }
  }

  // Single source of truth lives in pregnancyWeekData (shared with the Baby
  // Development screen) so the two screens never disagree on a given week.
  String _babySize(int week) {
    final data = pregnancyWeekData[week];
    if (data == null) return 'growing strong 🌸';
    return '${data['size']} ${data['emoji']}';
  }

  String? _babyWeight(int week) => pregnancyWeekData[week]?['weight'];

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String get _firstName =>
      (_profile?['full_name'] as String? ?? 'there').split(' ').first;

  String? get _photoUrl => _profile?['profile_picture_url'] as String?;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isPremium = auth.isPremium;
    final isMum = auth.isMum;

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
              expandedHeight: 160,
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
                              Text('$_greeting, $_firstName! 🌸',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineMedium
                                      ?.copyWith(fontSize: 20)),
                              const SizedBox(height: 2),
                              Text(
                                  DateFormat('EEEE, d MMMM')
                                      .format(DateTime.now()),
                                  style: const TextStyle(
                                      color: AppColors.textMid, fontSize: 13)),
                            ],
                          ),
                          GestureDetector(
                            onTap: () => context.push('/profile'),
                            child: CircleAvatar(
                              radius: 20,
                              backgroundColor: AppColors.rose.withValues(alpha: 0.15),
                              backgroundImage: _photoUrl != null
                                  ? NetworkImage(_photoUrl!)
                                  : null,
                              child: _photoUrl != null
                                  ? null
                                  : Text(
                                      _firstName.isNotEmpty
                                          ? _firstName[0].toUpperCase()
                                          : 'U',
                                      style: const TextStyle(
                                          color: AppColors.roseDeep,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 18)),
                            ),
                          ),
                        ],
                      ),
                      if (isPremium) ...[
                        const SizedBox(height: 6),
                        const PremiumBadge(),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Mum-specific: pregnancy week card
                    if (isMum) ...[
                      _buildPregnancyCard(context),
                      const SizedBox(height: 20),
                    ],

                    // Active alerts: milestones + upcoming consultations
                    _buildActiveAlerts(),

                    // Upcoming features
                    const TBSectionTitle(
                      title: 'Explore',
                      action: '',
                    ),
                    const SizedBox(height: 12),
                    _buildExploreGrid(context, isPremium),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Named milestones for a handful of well-known weeks, falling back to the
  // existing per-week development highlight for everything else.
  String _milestoneLabel(int week) {
    const named = {
      4: 'Pregnancy confirmed',
      8: 'Heartbeat detectable',
      12: 'End of first trimester',
      13: 'Second trimester begins',
      20: 'Halfway there!',
      23: 'Viability milestone reached',
      24: 'Viability milestone reached',
      28: 'Third trimester begins',
      37: 'Full term soon',
      40: 'Full term!',
    };
    return named[week] ??
        (pregnancyWeekData[week]?['highlight'] ?? 'Growing strong');
  }

  String get _trimesterLabel {
    if (_currentWeek <= 12) return '1st Trimester';
    if (_currentWeek <= 27) return '2nd Trimester';
    return '3rd Trimester';
  }

  // Progress through the *current* trimester, not the whole pregnancy.
  double get _trimesterProgress {
    final week = _currentWeek;
    if (week <= 12) return week / 12;
    if (week <= 27) return (week - 12) / 15;
    return (week - 27) / 13;
  }

  // "Week X of Y" within the current trimester, for the caption under the bar.
  (int, int) get _trimesterWeekOverview {
    final week = _currentWeek;
    if (week <= 12) return (week, 12);
    if (week <= 27) return (week - 12, 15);
    return (week - 27, 13);
  }

  // Tappable — leads to Baby Development. (The "New Milestone" alert leads
  // to the Milestone Journey screen instead.)
  Widget _buildPregnancyCard(BuildContext context) {
    final week = _currentWeek;
    final hasDate = week > 0;
    return GestureDetector(
      onTap: () {
        if (_canNav()) context.push('/baby-development');
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.rose.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('🌸  Your Pregnancy',
                    style: TextStyle(
                        color: AppColors.roseDeep,
                        fontWeight: FontWeight.w700,
                        fontSize: 13)),
                Icon(Icons.chevron_right, color: AppColors.roseDeep, size: 18),
              ],
            ),
            const SizedBox(height: 12),
            if (hasDate) ...[
              const Text('Current week',
                  style: TextStyle(color: AppColors.textLight, fontSize: 12)),
              Text('Week $week',
                  style: Theme.of(context)
                      .textTheme
                      .headlineMedium
                      ?.copyWith(fontSize: 28, color: AppColors.rose)),
              const SizedBox(height: 2),
              Text('${_milestoneLabel(week)} ✦',
                  style:
                      const TextStyle(color: AppColors.textMid, fontSize: 13)),
              const SizedBox(height: 16),
              const Text('Trimester progress',
                  style: TextStyle(color: AppColors.textLight, fontSize: 12)),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_trimesterLabel,
                      style: const TextStyle(
                          color: AppColors.textDark,
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                  Text('${(_trimesterProgress.clamp(0.0, 1.0) * 100).round()}%',
                      style: const TextStyle(
                          color: AppColors.rose,
                          fontSize: 13,
                          fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 6),
              LinearProgressIndicator(
                value: _trimesterProgress.clamp(0.0, 1.0),
                backgroundColor: AppColors.rose.withValues(alpha: 0.15),
                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.rose),
                minHeight: 6,
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 6),
              Text(
                  'Week ${_trimesterWeekOverview.$1} of ${_trimesterWeekOverview.$2} this trimester',
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textLight)),
            ] else ...[
              const SizedBox(height: 4),
              const Text('When is your baby due?',
                  style: TextStyle(color: AppColors.textMid, fontSize: 13)),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: _pickAndSaveDueDate,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.rose,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.calendar_today_outlined,
                          color: Colors.white, size: 15),
                      SizedBox(width: 6),
                      Text('Set Due Date',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 13)),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActiveAlerts() {
    final week = _currentWeek;
    final auth = context.read<AuthProvider>();

    final activeConsultations = _consultations.where((c) {
      final status = (c['status'] as String? ?? '').toLowerCase();
      return status == 'pending' || status == 'confirmed';
    }).toList();

    final cards = <Widget>[];

    // 1) Show real notifications first.
    for (final n in _notifications.take(3)) {
      final type = (n['type'] ?? 'general').toString().toLowerCase();

      cards.add(
        _notificationPreviewCard(
          title: (n['title'] ?? 'Notification').toString(),
          message: (n['message'] ?? '').toString(),
          type: type,
          isRead: n['is_read'] == true,
          onTap: () => _openNotificationTarget(type),
        ),
      );
    }

    // 2) Add dashboard-generated alerts if there are not enough DB notifications.
    if (cards.length < 3 && auth.isMum && week > 0) {
      cards.add(
        _alertCard(
          icon: Icons.auto_awesome,
          iconBg: AppColors.rose.withValues(alpha: 0.15),
          iconColor: AppColors.roseDeep,
          title: 'New Milestone',
          subtitle:
              'Baby now weighs ~${_babyWeight(week) ?? '—'} — Size of ${_babySize(week)}',
          onTap: () {
            if (_canNav()) context.push('/milestone-journey');
          },
        ),
      );
    }

    if (cards.length < 3) {
      for (final c in activeConsultations.take(3 - cards.length)) {
        cards.add(
          _alertCard(
            icon: Icons.calendar_today_outlined,
            iconBg: AppColors.sage.withValues(alpha: 0.15),
            iconColor: AppColors.sage,
            title: _appointmentDateLabel(
              c['scheduled_date'] as String?,
              c['status'] as String?,
            ),
            subtitle: _appointmentSubtitle(c),
            onTap: () {
              if (_canNav()) context.push('/consultation');
            },
          ),
        );
      }
    }

    if (cards.isEmpty) {
      cards.add(
        _emptyAlertCard(),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Active Alerts & Notifications',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () {
                if (_canNav()) context.push('/notifications');
              },
              child: const Text(
                'View All',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...cards,
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _emptyAlertCard() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TBCard(
        onTap: () {
          if (_canNav()) context.push('/notifications');
        },
        padding: const EdgeInsets.all(14),
        child: const Row(
          children: [
            CircleAvatar(
              backgroundColor: AppColors.blush,
              child: Icon(Icons.notifications_none_outlined,
                  color: AppColors.roseDeep),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'No new alerts today. Tap View All to open the Notifications Centre.',
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

  void _openNotificationTarget(String type) {
    if (!_canNav()) return;

    switch (type) {
      case 'appointment':
        context.push('/consultation');
        break;
      case 'milestone':
        context.push('/milestone-journey');
        break;
      case 'education':
        context.push('/education');
        break;
      case 'reminder':
        context.push('/logs/create');
        break;
      case 'ai':
        context.push('/chatbot');
        break;
      case 'emergency':
      default:
        context.push('/notifications');
    }
  }

  IconData _notificationIcon(String type) {
    switch (type) {
      case 'emergency':
        return Icons.warning_amber_rounded;
      case 'milestone':
        return Icons.auto_awesome;
      case 'appointment':
        return Icons.calendar_today_outlined;
      case 'education':
        return Icons.menu_book_outlined;
      case 'ai':
        return Icons.smart_toy_outlined;
      case 'reminder':
        return Icons.water_drop_outlined;
      default:
        return Icons.notifications_none_outlined;
    }
  }

  Color _notificationColor(String type) {
    switch (type) {
      case 'emergency':
        return Colors.redAccent;
      case 'milestone':
        return AppColors.rose;
      case 'appointment':
        return AppColors.sage;
      case 'education':
        return AppColors.teal;
      case 'ai':
        return Colors.purpleAccent;
      case 'reminder':
        return AppColors.roseDeep;
      default:
        return AppColors.textMid;
    }
  }

  Widget _notificationPreviewCard({
    required String title,
    required String message,
    required String type,
    required bool isRead,
    required VoidCallback onTap,
  }) {
    final color = _notificationColor(type);
    final isEmergency = type == 'emergency';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TBCard(
        onTap: onTap,
        // Smaller padding prevents the alert row from being a few pixels too wide
        // on smaller Android screens.
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
              child: Icon(_notificationIcon(type), color: color, size: 20),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: isRead ? FontWeight.w600 : FontWeight.w800,
                      fontSize: 13,
                      color: AppColors.textDark,
                    ),
                  ),
                  if (isEmergency) ...[
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Urgent',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    message.isEmpty ? 'Tap to view more details.' : message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textLight,
                      fontSize: 11,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 2),
            const SizedBox(
              width: 14,
              child: Icon(
                Icons.chevron_right,
                color: AppColors.textLight,
                size: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _appointmentDateLabel(String? scheduledDate, String? status) {
    final normalisedStatus = (status ?? '').toLowerCase();
    if (normalisedStatus == 'pending') return 'Appointment Pending Approval';

    final date =
        scheduledDate != null ? DateTime.tryParse(scheduledDate) : null;
    if (date == null) return 'Upcoming Appointment';
    final today = DateTime.now();
    final diff = DateTime(date.year, date.month, date.day)
        .difference(DateTime(today.year, today.month, today.day))
        .inDays;
    if (diff == 0) return 'Appointment Today';
    if (diff == 1) return 'Appointment Tomorrow';
    if (diff < 0) return 'Past Appointment';
    return 'Appointment on ${DateFormat('d MMM').format(date)}';
  }

  String _dashboardTimeOnly(String? value) {
    if (value == null || value.trim().isEmpty) return '';
    var time = value.trim();

    if (time.toLowerCase().startsWith('today')) {
      time = time.substring(5).trim();
    }

    if (time.contains('-')) {
      time = time.split('-').first.trim();
    }

    return time;
  }

  String _appointmentSubtitle(Map<String, dynamic> c) {
    final type = (c['consultation_type'] as String? ?? 'specialist');
    final typeLabel =
        '${type[0].toUpperCase()}${type.substring(1)} Consultation 1-1';
    final time = _dashboardTimeOnly(c['scheduled_time'] as String?);
    final providerName = _providerNames[c['specialist_id']];
    if (time.isEmpty && providerName == null) return typeLabel;
    final timeProvider = [if (time.isNotEmpty) time, providerName]
        .whereType<String>()
        .join(' - ');
    return '$typeLabel\n$timeProvider';
  }

  Widget _alertCard({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TBCard(
        onTap: onTap,
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                  color: iconBg, borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: const TextStyle(
                          color: AppColors.textLight, fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
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

  Widget _buildExploreGrid(BuildContext context, bool isPremium) {
    final items = [
      {
        'emoji': '🤖',
        'title': 'AI Assistant',
        'desc': 'Get pregnancy guidance',
        'route': '/chatbot',
        'premium': false,
      },
      {
        'emoji': '👩‍⚕️',
        'title': 'Consultations',
        'desc': 'Book volunteer or specialist support',
        'route': '/consultation',
        'premium': false,
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.25,
      ),
      itemBuilder: (context, index) =>
          _exploreCard(context, items[index], isPremium),
    );
  }

  Widget _exploreCard(
      BuildContext context, Map<String, Object> item, bool isPremium) {
    return GestureDetector(
      onTap: () {
        if (_canNav()) context.push(item['route'] as String);
      },
      child: TBCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item['emoji'] as String, style: const TextStyle(fontSize: 24)),
            const SizedBox(height: 8),
            Text(
              item['title'] as String,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: Text(
                item['desc'] as String,
                style: const TextStyle(
                  color: AppColors.textLight,
                  fontSize: 11,
                  height: 1.25,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
