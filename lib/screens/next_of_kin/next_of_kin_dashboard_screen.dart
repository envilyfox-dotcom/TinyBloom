import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../services/supabase_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/checklist_data.dart';
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
  List<ChecklistPhase> _checklistPhases = [];
  int _checklistPhaseIndex = 0;
  bool _loading = true;
  DateTime? _lastNavTime;
  // Local-only "seen" tracking — resets each session. There's no backend
  // read-receipt store for these derived alerts (unlike the mum's
  // notifications table), so this is a placeholder until that's designed.
  final Set<String> _dismissedAlertKeys = {};

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
    List<ChecklistPhase> checklistPhases = [];
    if (linkedMum != null) {
      consultations = await SupabaseService.getConsultationsForPatient(
          linkedMum['id'] as String);

      final activeSpecialistIds = consultations
          .where((c) {
            final status = (c['status'] as String? ?? '').toLowerCase();
            return status == 'pending' || status == 'confirmed';
          })
          .take(2)
          .map((c) => c['specialist_id'] as String?)
          .whereType<String>()
          .toSet();
      for (final id in activeSpecialistIds) {
        try {
          final p = await SupabaseService.getProviderProfile(id);
          final name = (p?['profiles'] as Map<String, dynamic>?)?['full_name']
              as String?;
          if (name != null) providerNames[id] = name;
        } catch (_) {}
      }

      try {
        final rows = await SupabaseService.getOrCreateChecklistItems();
        checklistPhases = phasesFromRows(rows);
      } catch (_) {}
    }
    final checklistPhaseIndex = await getCurrentChecklistPhaseIndex();

    if (mounted) {
      setState(() {
        _profile = profile;
        _linkedMum = linkedMum;
        _consultations = consultations;
        _providerNames = providerNames;
        _checklistPhases = checklistPhases;
        _checklistPhaseIndex = checklistPhaseIndex.clamp(
            0, checklistPhases.isEmpty ? 0 : checklistPhases.length - 1);
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
  String get _linkedMumFirstName => _linkedMumName.split(' ').first;

  String get _trimesterLabel {
    final week = _linkedMumWeek;
    if (week <= 12) return '1st Trimester';
    if (week <= 27) return '2nd Trimester';
    return '3rd Trimester';
  }

  // Named milestones for a handful of well-known weeks, falling back to the
  // existing per-week development highlight for everything else — mirrors
  // the mum's own dashboard so the two never disagree on a given week.
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

  // Progress through the *current* trimester, not the whole pregnancy.
  double get _trimesterProgress {
    final week = _linkedMumWeek;
    if (week <= 12) return week / 12;
    if (week <= 27) return (week - 12) / 15;
    return (week - 27) / 13;
  }

  // "Week X of Y" within the current trimester, for the caption under the bar.
  (int, int) get _trimesterWeekOverview {
    final week = _linkedMumWeek;
    if (week <= 12) return (week, 12);
    if (week <= 27) return (week - 12, 15);
    return (week - 27, 13);
  }

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
                              ? CachedNetworkImageProvider(_photoUrl!,
                                  maxWidth: 200)
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
                          _buildTrimesterCard(context),
                          const SizedBox(height: 20),
                          _buildQuickActions(),
                          const SizedBox(height: 20),
                          _buildChecklistSection(context),
                          const SizedBox(height: 20),
                          _buildActiveAlerts(),
                          const SizedBox(height: 20),
                          _buildExploreSection(context),
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
      subtitle:
          "Link to a pregnant user's account to see her pregnancy journey here.",
      buttonLabel: 'Link to Pregnant User',
      onButton: () => context.push('/next-of-kin/link'),
    );
  }

  Widget _buildTrimesterCard(BuildContext context) {
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
    return GestureDetector(
      onTap: () {
        if (!_canNav() || _linkedMum == null) return;
        context.push('/baby-development', extra: {
          'userId': _linkedMum!['id'],
          'name': _linkedMumFirstName,
        });
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('🌸  $_linkedMumFirstName\'s Pregnancy',
                    style: const TextStyle(
                        color: AppColors.roseDeep,
                        fontWeight: FontWeight.w700,
                        fontSize: 13)),
                const Icon(Icons.chevron_right,
                    color: AppColors.roseDeep, size: 18),
              ],
            ),
            const SizedBox(height: 12),
            const Text('Current week',
                style: TextStyle(color: AppColors.textLight, fontSize: 12)),
            Text('Week $week',
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(fontSize: 28, color: AppColors.rose)),
            const SizedBox(height: 2),
            Text('${_milestoneLabel(week)} ✦',
                style: const TextStyle(color: AppColors.textMid, fontSize: 13)),
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
                style:
                    const TextStyle(fontSize: 11, color: AppColors.textLight)),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    final actions = [
      (
        emoji: '📋',
        iconBg: AppColors.rose.withValues(alpha: 0.15),
        label: 'Health logs',
        onTap: () {
          // go(), not push() — /logs is a bottom-nav tab inside the same
          // ShellRoute; pushing it leaves the dashboard underneath instead
          // of replacing it, so the tab highlight never updates and the
          // dashboard never reloads when you come back to it.
          if (_canNav()) context.go('/logs');
        },
      ),
      (
        emoji: '🎥',
        iconBg: AppColors.sage.withValues(alpha: 0.15),
        label: 'Join consult',
        onTap: () {
          if (_canNav()) context.push('/consultation');
        },
      ),
      (
        emoji: '🎁',
        iconBg: AppColors.gold.withValues(alpha: 0.15),
        label: 'Gift premium',
        onTap: () {
          if (_canNav()) context.push('/next-of-kin/gift-subscription');
        },
      ),
      (
        emoji: '💬',
        iconBg: AppColors.teal.withValues(alpha: 0.15),
        label: 'Chat volunteer',
        onTap: () {
          if (_canNav()) context.push('/next-of-kin/chat-volunteer');
        },
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
                  color: action.iconBg,
                  borderRadius: BorderRadius.circular(12)),
              alignment: Alignment.center,
              child: Text(action.emoji, style: const TextStyle(fontSize: 20)),
            ),
            const SizedBox(height: 8),
            Text(action.label,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  // "Current trimester" here is whatever the user last picked on the full
  // Checklist screen (getCurrentChecklistPhaseIndex), not derived from the
  // mum's real week — same source of truth both screens read from.
  Widget _buildChecklistSection(BuildContext context) {
    if (_checklistPhases.isEmpty) return const SizedBox.shrink();

    final totalItems =
        _checklistPhases.fold(0, (sum, p) => sum + phaseTotal(p));
    final totalDone =
        _checklistPhases.fold(0, (sum, p) => sum + phaseDone(p));
    final progress = totalItems == 0 ? 0.0 : totalDone / totalItems;
    final currentPhase = _checklistPhases[_checklistPhaseIndex];
    final previewItems = currentPhase.allItems.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TBSectionTitle(
          title: 'Support Checklist',
          action: 'View More',
          onAction: () {
            if (_canNav()) context.go('/next-of-kin/checklist');
          },
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () {
            if (_canNav()) context.go('/next-of-kin/checklist');
          },
          child: TBCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$totalDone of $totalItems tasks completed',
                    style: const TextStyle(
                        color: AppColors.textMid, fontSize: 13)),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: progress,
                  backgroundColor: AppColors.rose.withValues(alpha: 0.15),
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(AppColors.rose),
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(height: 16),
                Text('${currentPhase.emoji} ${currentPhase.label}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 8),
                for (final item in previewItems)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          item.isCompleted
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          color: item.isCompleted
                              ? AppColors.sage
                              : AppColors.textLight,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(item.text,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: item.isCompleted
                                      ? AppColors.textLight
                                      : AppColors.textMid,
                                  decoration: item.isCompleted
                                      ? TextDecoration.lineThrough
                                      : TextDecoration.none)),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Mirrors the mum dashboard's Explore section (same TBSectionTitle +
  // card style) so AI Assistant lives in a consistent spot across roles,
  // now that it's off the bottom nav.
  Widget _buildExploreSection(BuildContext context) {
    final items = [
      {
        'emoji': '🤖',
        'title': 'AI Assistant',
        'desc': 'Get personalised pregnancy guidance',
        'route': '/chatbot',
      },
      {
        'emoji': '👩‍⚕️',
        'title': 'Consultations',
        'desc': 'Book volunteer or specialist support',
        'route': '/consultation',
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const TBSectionTitle(title: 'Explore', action: ''),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (int i = 0; i < items.length; i++) ...[
              if (i > 0) const SizedBox(width: 12),
              Expanded(child: _exploreCard(context, items[i])),
            ],
          ],
        ),
      ],
    );
  }

  Widget _exploreCard(BuildContext context, Map<String, String> item) {
    return GestureDetector(
      onTap: () {
        if (_canNav()) context.push(item['route']!);
      },
      child: TBCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(item['emoji']!, style: const TextStyle(fontSize: 24)),
            const SizedBox(height: 6),
            Text(item['title']!,
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            const SizedBox(height: 2),
            Text(item['desc']!,
                style:
                    const TextStyle(color: AppColors.textLight, fontSize: 11),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveAlerts() {
    final week = _linkedMumWeek;

    final activeConsultations = _consultations.where((c) {
      final status = (c['status'] as String? ?? '').toLowerCase();
      return status == 'pending' || status == 'confirmed';
    }).toList();

    final specs = <(
      String key,
      IconData icon,
      Color iconBg,
      Color iconColor,
      String title,
      String subtitle,
      VoidCallback onTap
    )>[
      if (week > 0)
        (
          'milestone-$week',
          Icons.auto_awesome,
          AppColors.rose.withValues(alpha: 0.15),
          AppColors.roseDeep,
          'New Milestone',
          'Baby now weighs ~${pregnancyWeekData[week]?['weight'] ?? '—'} — Size of ${pregnancyWeekData[week]?['size'] ?? 'growing strong'} ${pregnancyWeekData[week]?['emoji'] ?? ''}',
          () => _comingSoon('Milestone journey'),
        ),
      for (final c in activeConsultations.take(2))
        (
          'consultation-${c['id']}',
          Icons.calendar_today_outlined,
          AppColors.sage.withValues(alpha: 0.15),
          AppColors.sage,
          _appointmentDateLabel(c['scheduled_date'] as String?),
          _appointmentSubtitle(c),
          () {
            if (_canNav()) context.push('/consultation');
          },
        ),
    ];

    final visible =
        specs.where((s) => !_dismissedAlertKeys.contains(s.$1)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TBSectionTitle(
          title: 'Active Alerts & Notifications',
          action: 'View All',
          onAction: () {
            if (_canNav()) context.push('/next-of-kin/alerts');
          },
        ),
        const SizedBox(height: 12),
        if (visible.isEmpty)
          TBCard(
            onTap: () {
              if (_canNav()) context.push('/next-of-kin/alerts');
            },
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                      color: AppColors.rose.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.notifications_none_outlined,
                      color: AppColors.roseDeep, size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                      'No new alerts today. Tap View All to open the Notifications Centre.',
                      style: TextStyle(color: AppColors.textMid, fontSize: 13)),
                ),
                const Icon(Icons.chevron_right,
                    color: AppColors.textLight, size: 18),
              ],
            ),
          )
        else
          for (final s in visible)
            _alertCard(
              icon: s.$2,
              iconBg: s.$3,
              iconColor: s.$4,
              title: s.$5,
              subtitle: s.$6,
              onTap: () {
                setState(() => _dismissedAlertKeys.add(s.$1));
                s.$7();
              },
            ),
      ],
    );
  }

  String _appointmentDateLabel(String? scheduledDate) {
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

  String _appointmentSubtitle(Map<String, dynamic> c) {
    final type = (c['consultation_type'] as String? ?? 'specialist');
    final typeLabel =
        '${type[0].toUpperCase()}${type.substring(1)} Consultation 1-1';
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
