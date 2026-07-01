import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../services/supabase_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/pregnancy_week_data.dart';
import '../../widgets/common_widgets.dart';

class NextOfKinDashboardScreen extends StatefulWidget {
  const NextOfKinDashboardScreen({super.key});

  @override
  State<NextOfKinDashboardScreen> createState() =>
      _NextOfKinDashboardScreenState();
}

class _NextOfKinDashboardScreenState extends State<NextOfKinDashboardScreen> {
  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _linkedMum;
  List<Map<String, dynamic>> _consultations = [];
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
    try {
      profile = await SupabaseService.getProfile();
    } catch (_) {}
    if (profile == null) {
      final meta = SupabaseService.currentUser?.userMetadata;
      if (meta != null) {
        profile = {'full_name': meta['full_name'], 'role': meta['role']};
      }
    }

    Map<String, dynamic>? linkedMum;
    try {
      linkedMum = await SupabaseService.getLinkedMum();
    } catch (_) {}

    List<Map<String, dynamic>> consultations = [];
    final providerNames = <String, String>{};
    if (linkedMum != null) {
      consultations =
          await SupabaseService.getConsultationsForPatient(linkedMum['id'] as String);

      final activeSpecialistIds = consultations.where((c) {
        final status = (c['status'] as String? ?? '').toLowerCase();
        return status == 'pending' || status == 'confirmed';
      }).take(2).map((c) => c['specialist_id'] as String?).whereType<String>().toSet();
      for (final id in activeSpecialistIds) {
        try {
          final p = await SupabaseService.getProviderProfile(id);
          final name = (p?['profiles'] as Map<String, dynamic>?)?['full_name'] as String?;
          if (name != null) providerNames[id] = name;
        } catch (_) {}
      }
    }

    if (mounted) {
      setState(() {
        _profile = profile;
        _linkedMum = linkedMum;
        _consultations = consultations;
        _providerNames = providerNames;
        _loading = false;
      });
    }
  }

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String get _firstName =>
      (_profile?['full_name'] as String? ?? 'there').split(' ').first;

  String? get _photoUrl => _profile?['profile_picture_url'] as String?;

  int get _linkedMumWeek => (_linkedMum?['current_week'] as int?) ?? 0;
  String get _linkedMumName => (_linkedMum?['full_name'] as String?) ?? 'them';

  String get _trimesterLabel {
    final week = _linkedMumWeek;
    if (week <= 12) return '1st Trimester';
    if (week <= 27) return '2nd Trimester';
    return '3rd Trimester';
  }

  double get _pregnancyProgress => (_linkedMumWeek / 40).clamp(0.0, 1.0);

  void _comingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature — coming soon')),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: TBLoading());

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.rose,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 150,
              floating: false,
              pinned: true,
              backgroundColor: AppColors.blush,
              elevation: 0,
              automaticallyImplyLeading: false,
              flexibleSpace: FlexibleSpaceBar(
                background: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 44, 20, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('$_greeting, $_firstName',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium
                                    ?.copyWith(fontSize: 20)),
                            const SizedBox(height: 4),
                            if (_linkedMum != null)
                              Text.rich(
                                TextSpan(
                                  style: const TextStyle(
                                      color: AppColors.textMid, fontSize: 13),
                                  children: [
                                    TextSpan(text: '$_linkedMumName is on '),
                                    TextSpan(
                                      text: 'Week $_linkedMumWeek',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700),
                                    ),
                                    const TextSpan(text: ' of Pregnancy'),
                                  ],
                                ),
                              )
                            else
                              const Text('Not linked to a pregnant user yet',
                                  style: TextStyle(
                                      color: AppColors.textMid, fontSize: 13)),
                          ],
                        ),
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
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: _linkedMum == null
                    ? _buildNotLinkedPrompt(context)
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildTrimesterCard(),
                          const SizedBox(height: 20),
                          _buildQuickActions(),
                          const SizedBox(height: 20),
                          _buildBabyDevelopmentCard(context),
                          const SizedBox(height: 20),
                          _buildActiveAlerts(),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotLinkedPrompt(BuildContext context) {
    return TBEmptyState(
      emoji: '🔗',
      title: 'Not linked yet',
      subtitle: "Link to a pregnant user's account to see her pregnancy journey here.",
      buttonLabel: 'Link to Pregnant User',
      onButton: () => context.push('/next-of-kin/link'),
    );
  }

  Widget _buildTrimesterCard() {
    final week = _linkedMumWeek;
    if (week == 0) {
      return const TBCard(
        child: Row(
          children: [
            Icon(Icons.info_outline, color: AppColors.textLight, size: 20),
            SizedBox(width: 10),
            Expanded(
              child: Text('No pregnancy details available yet.',
                  style: TextStyle(color: AppColors.textMid, fontSize: 13)),
            ),
          ],
        ),
      );
    }
    return TBCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Trimester progress',
                  style: TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 14)),
              Text(_trimesterLabel,
                  style: const TextStyle(
                      color: AppColors.textMid,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: _pregnancyProgress,
            backgroundColor: AppColors.rose.withValues(alpha: 0.15),
            valueColor:
                const AlwaysStoppedAnimation<Color>(AppColors.rose),
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: Text('${(_pregnancyProgress * 100).round()}%',
                style: const TextStyle(
                    color: AppColors.rose,
                    fontSize: 13,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    final actions = [
      (
        emoji: '📋',
        iconBg: AppColors.rose.withValues(alpha: 0.15),
        label: 'Health logs',
        onTap: () { if (_canNav()) context.push('/logs'); },
      ),
      (
        emoji: '🎥',
        iconBg: AppColors.sage.withValues(alpha: 0.15),
        label: 'Join consult',
        onTap: () { if (_canNav()) context.push('/consultation'); },
      ),
      (
        emoji: '🎁',
        iconBg: AppColors.gold.withValues(alpha: 0.15),
        label: 'Gift premium',
        onTap: () { if (_canNav()) context.push('/next-of-kin/gift-subscription'); },
      ),
    ];

    return Row(
      children: [
        for (int i = 0; i < actions.length; i++) ...[
          if (i > 0) const SizedBox(width: 12),
          Expanded(child: _quickActionButton(actions[i])),
        ],
      ],
    );
  }

  Widget _quickActionButton(
      ({String emoji, Color iconBg, String label, VoidCallback onTap}) action) {
    return GestureDetector(
      onTap: action.onTap,
      child: TBCard(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                  color: action.iconBg, borderRadius: BorderRadius.circular(12)),
              alignment: Alignment.center,
              child: Text(action.emoji, style: const TextStyle(fontSize: 20)),
            ),
            const SizedBox(height: 8),
            Text(action.label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildBabyDevelopmentCard(BuildContext context) {
    final week = _linkedMumWeek;
    if (week == 0) return const SizedBox.shrink();

    final data = pregnancyWeekData[week];
    final size = data?['size'] ?? 'growing strong';
    final emoji = data?['emoji'] ?? '🌸';
    final highlight = data?['highlight'] ?? '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.rose.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 10),
              const Text("Baby's Development",
                  style: TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 15)),
            ],
          ),
          const SizedBox(height: 4),
          Text('Week $week',
              style: const TextStyle(
                  color: AppColors.rose,
                  fontWeight: FontWeight.w700,
                  fontSize: 13)),
          const SizedBox(height: 8),
          Text('Now the size of $size. $highlight',
              style: const TextStyle(color: AppColors.textMid, fontSize: 13)),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _comingSoon('Full baby development view'),
              child: const Text('View details'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveAlerts() {
    final week = _linkedMumWeek;

    final activeConsultations = _consultations.where((c) {
      final status = (c['status'] as String? ?? '').toLowerCase();
      return status == 'pending' || status == 'confirmed';
    }).toList();

    final alerts = <Widget>[
      if (week > 0)
        _alertCard(
          icon: Icons.auto_awesome,
          iconBg: AppColors.rose.withValues(alpha: 0.15),
          iconColor: AppColors.roseDeep,
          title: 'New Milestone',
          subtitle:
              'Baby now weighs ~${pregnancyWeekData[week]?['weight'] ?? '—'} — Size of ${pregnancyWeekData[week]?['size'] ?? 'growing strong'} ${pregnancyWeekData[week]?['emoji'] ?? ''}',
          onTap: () => _comingSoon('Milestone journey'),
        ),
      for (final c in activeConsultations.take(2))
        _alertCard(
          icon: Icons.calendar_today_outlined,
          iconBg: AppColors.sage.withValues(alpha: 0.15),
          iconColor: AppColors.sage,
          title: _appointmentDateLabel(c['scheduled_date'] as String?),
          subtitle: _appointmentSubtitle(c),
          onTap: () { if (_canNav()) context.push('/consultation'); },
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TBSectionTitle(
          title: 'Active Alerts',
          action: 'View All',
          onAction: () { if (_canNav()) context.push('/notifications'); },
        ),
        const SizedBox(height: 12),
        if (alerts.isEmpty)
          const TBEmptyState(
              emoji: '🔔',
              title: 'No active alerts',
              subtitle: 'Milestones and upcoming appointments will show up here.')
        else
          ...alerts,
      ],
    );
  }

  String _appointmentDateLabel(String? scheduledDate) {
    final date = scheduledDate != null ? DateTime.tryParse(scheduledDate) : null;
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

  String _appointmentSubtitle(Map<String, dynamic> c) {
    final type = (c['consultation_type'] as String? ?? 'specialist');
    final typeLabel = '${type[0].toUpperCase()}${type.substring(1)} Consultation 1-1';
    final time = c['scheduled_time'] as String?;
    final providerName = _providerNames[c['specialist_id']];
    if (time == null && providerName == null) return typeLabel;
    final timeProvider = [time, providerName].whereType<String>().join(' - ');
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
              width: 44,
              height: 44,
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
}
